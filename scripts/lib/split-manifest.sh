#!/usr/bin/env bash
# Reading the family manifest. The single authority is
# jeryu-release-ops/repos.manifest.toml; this portal carries no copy.
# Sourced by scripts/clone-family.sh; exercised directly by
# tests/split-manifest.sh.

# split_manifest_path <dest>
#
# Where the authority manifest lives for a family checked out under <dest>.
# JERYU_SPLIT_MANIFEST names an already-available copy instead.
split_manifest_path() {
  local dest="$1"
  printf '%s\n' "${JERYU_SPLIT_MANIFEST:-${dest}/jeryu-release-ops/repos.manifest.toml}"
}

# split_manifest_rows <manifest>
#
# Prints `name|remote` for every active repository the authority lists. A row
# without a name or a remote, or one the authority no longer keeps in its
# inventory, is not a clone target.
split_manifest_rows() {
  local manifest="$1"
  if [[ ! -r "$manifest" ]]; then
    printf 'manifest not readable: %s\n' "$manifest" >&2
    return 1
  fi
  python3 - "$manifest" <<'PY'
import sys
try:
    import tomllib
except ModuleNotFoundError:
    import tomli as tomllib

with open(sys.argv[1], "rb") as fh:
    data = tomllib.load(fh)

repos = data.get("repo", [])
if not repos:
    raise SystemExit("manifest has no [[repo]] entries")

names = set()
for repo in repos:
    name = str(repo.get("name", ""))
    remote = str(repo.get("remote", ""))
    names.add(name)
    if not name or not remote:
        continue
    if str(repo.get("inventory_status", "active")) != "active":
        continue
    print(f"{name}|{remote}")

missing = [n for n in data.get("required_repos", []) if n not in names]
if missing:
    raise SystemExit("manifest missing required repos: " + " ".join(missing))
PY
}
