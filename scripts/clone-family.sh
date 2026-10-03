#!/usr/bin/env bash
set -euo pipefail

# Clones the split family from the authority manifest in jeryu-release-ops.
# The control plane is cloned first because it carries that manifest: this
# portal ships no copy of it.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
source "${script_dir}/lib/split-manifest.sh"
default_dest="$(cd "${repo_root}/.." && pwd)"
dest="${1:-$default_dest}"
forge="${JERYU_FORGE_BASE:-https://git.neverhuman.org}"
control_plane="jeryu-release-ops"
portal="jeryu"

clone_or_update() {
  local name="$1" remote="$2"
  local target="${dest}/${name}"
  if [[ -d "${target}/.git" ]]; then
    printf 'updating %s\n' "$target"
    git -C "$target" fetch --prune origin
    local branch
    branch="$(git -C "$target" symbolic-ref --quiet --short HEAD || printf 'main')"
    git -C "$target" pull --ff-only origin "$branch"
  elif [[ -e "$target" ]]; then
    printf 'refusing to overwrite non-git path: %s\n' "$target" >&2
    exit 1
  else
    printf 'cloning %s -> %s\n' "$remote" "$target"
    git clone "$remote" "$target"
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
