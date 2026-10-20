#!/usr/bin/env bash
set -euo pipefail

# Clones the split family from the authority manifest in jeryu-release-ops.
# The control plane is cloned first because it carries that manifest: this
# portal ships no copy of it.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
source "${script_dir}/lib/split-manifest.sh"
# shellcheck source=lib/git-remote.sh
source "${script_dir}/lib/git-remote.sh"

# shellcheck source=lib/release-config.sh
source "${script_dir}/lib/release-config.sh"

# Which remotes may be fetched is a site value, so it is read from the same
# configuration the installer reads (parsed as data, never run), never
# defaulted here.
jeryu_load_release_config
default_dest="$(cd "${repo_root}/.." && pwd)"
dest="${1:-$default_dest}"
forge="${JERYU_FORGE_BASE:-https://git.jeryu.ai}"
control_plane="jeryu-release-ops"
portal="jeryu"

clone_or_update() {
  local name="$1" remote="$2"
  # The name becomes a path under $dest, so it has to be one plain segment: a
  # manifest row cannot point a clone or a pull outside the destination.
  if [[ ! "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
    printf 'refusing manifest repository name %s: it is not a single path segment\n' "${name:-(empty)}" >&2
    exit 1
  fi
  local target="${dest}/${name}"
  # Checked before either branch below, and for an existing checkout the url its
  # own origin carries is checked too: a fetch reads whatever that says, not the
  # remote the manifest names.
  jeryu_check_git_remote "$remote"
  if [[ -d "${target}/.git" ]]; then
    printf 'updating %s\n' "$target"
    local origin_url branch
    if ! origin_url="$(git -C "$target" remote get-url origin 2>/dev/null)"; then
      printf 'refusing to update %s: it has no origin remote; add one (git -C %s remote add origin %s) or move the checkout aside\n' \
        "$target" "$target" "$remote" >&2
      exit 1
    fi
    jeryu_check_git_remote "$origin_url"
    git -C "$target" fetch --prune origin
    branch="$(git -C "$target" symbolic-ref --quiet --short HEAD || printf 'main')"
    git -C "$target" pull --ff-only origin "$branch"
  elif [[ -e "$target" ]]; then
    printf 'refusing to overwrite non-git path: %s\n' "$target" >&2
    exit 1
  else
    printf 'cloning %s -> %s\n' "$remote" "$target"
    git clone -- "$remote" "$target"
  fi
}

mkdir -p "$dest"
if [[ -z "${JERYU_SPLIT_MANIFEST:-}" ]]; then
  clone_or_update "$control_plane" "${forge}/git/jeryu/${control_plane}.git"
fi
manifest="$(split_manifest_path "$dest")"

rows_text="$(split_manifest_rows "$manifest")"
mapfile -t rows <<<"$rows_text"

for row in "${rows[@]}"; do
  IFS='|' read -r name remote <<<"$row"
  if [[ "$name" == "$portal" && "${JERYU_CLONE_PORTAL:-0}" != "1" ]]; then
    continue
  fi
  if [[ "$name" == "$control_plane" && -z "${JERYU_SPLIT_MANIFEST:-}" ]]; then
    continue
  fi
  clone_or_update "$name" "$remote"
done
