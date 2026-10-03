#!/usr/bin/env bash
# Proof that the portal reads the family from the jeryu-release-ops authority
# and carries no manifest of its own.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${root}/scripts/lib/split-manifest.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

fail=0
checked=0
check() {
  local name="$1" expected="$2" actual="$3"
  checked=$((checked + 1))
  if [[ "$expected" == "$actual" ]]; then
    printf 'ok: %s\n' "$name"
  else
    printf 'not ok: %s (expected %s, got %s)\n' "$name" "$expected" "$actual" >&2
    fail=1
  fi
}

# Every run leaves a receipt next to the other raw lane artifacts, so the next
# agent can see what this proof covered and rerun it with
# `bash tests/split-manifest.sh`.
receipt() {
  mkdir -p "${root}/target/tests"
  cat >"${root}/target/tests/split-manifest-receipt.json" <<JSON
{"schema_version":"jeryu.split.manifest-proof/v1","authority":"jeryu-release-ops/repos.manifest.toml","assertions":${checked},"conclusion":"$1","repair_hint":"bash tests/split-manifest.sh"}
JSON
}

# The portal must not ship a second copy of the family manifest.
check "portal ships no manifest" "absent" \
  "$([[ -e "${root}/repos.manifest.toml" ]] && printf 'present' || printf 'absent')"

# The authority path is the control plane's manifest, under the clone destination.
check "authority path" "${work}/jeryu-release-ops/repos.manifest.toml" \
  "$(JERYU_SPLIT_MANIFEST= split_manifest_path "$work")"
check "explicit manifest wins" "/elsewhere/repos.manifest.toml" \
  "$(JERYU_SPLIT_MANIFEST=/elsewhere/repos.manifest.toml split_manifest_path "$work")"

# Rows come from the authority's `remote`, and skip repositories it no longer
# keeps in its inventory.
manifest="${work}/repos.manifest.toml"
cat >"$manifest" <<'TOML'
schema_version = "1"
required_repos = ["jeryu", "jeryu-release-ops"]

[[repo]]
name = "jeryu"
remote = "https://git.example.org/git/jeryu/jeryu.git"
inventory_status = "active"

[[repo]]
name = "jeryu-release-ops"
remote = "https://git.example.org/git/jeryu/jeryu-release-ops.git"
inventory_status = "active"

[[repo]]
name = "jeryu-retired"
remote = "https://git.example.org/git/jeryu/jeryu-retired.git"
inventory_status = "retired"
TOML
check "active rows" \
  "jeryu|https://git.example.org/git/jeryu/jeryu.git jeryu-release-ops|https://git.example.org/git/jeryu/jeryu-release-ops.git" \
  "$(split_manifest_rows "$manifest" | tr '\n' ' ' | sed 's/ $//')"

# A manifest that does not list every required repository is not usable.
cat >"$manifest" <<'TOML'
required_repos = ["jeryu", "jeryu-core"]

[[repo]]
name = "jeryu"
remote = "https://git.example.org/git/jeryu/jeryu.git"
TOML
status=0
split_manifest_rows "$manifest" >/dev/null 2>&1 || status=$?
check "missing required repo fails" 1 "$status"

# An empty manifest, or one that is not there at all, fails instead of
# cloning nothing.
printf 'required_repos = []\n' >"$manifest"
status=0
split_manifest_rows "$manifest" >/dev/null 2>&1 || status=$?
check "manifest without repos fails" 1 "$status"
status=0
split_manifest_rows "${work}/missing.toml" >/dev/null 2>&1 || status=$?
check "unreadable manifest fails" 1 "$status"

if [[ "$fail" != "0" ]]; then
  receipt "failure"
  printf 'tests/split-manifest.sh failed; rerun with bash tests/split-manifest.sh\n' >&2
  exit 1
fi
receipt "success"
printf 'split-manifest ok\n'
