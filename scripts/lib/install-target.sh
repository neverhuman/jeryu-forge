#!/usr/bin/env bash
# Placing the downloaded jeryu binary at its final path, fail-closed.
# Sourced by scripts/install.sh; exercised directly by tests/install-target.sh.

# install_jeryu_binary <source-binary> <install-dir>
#
# Refuses to install when the target path is already a directory or a symlink:
# `install` would then write the binary inside the directory (or through the
# link) and leave the previously installed jeryu first on PATH, while still
# reporting success.
install_jeryu_binary() {
  local src="$1"
  local install_dir="$2"
  local target="${install_dir}/jeryu"

  if [[ -d "$target" || -L "$target" ]]; then
    printf '%s exists and is a directory or a symlink; remove it and re-run\n' "$target" >&2
    return 1
  fi

  mkdir -p "$install_dir"
  install -m 0755 -T "$src" "$target"

  local want got
  want="$("$src" --version)" || {
    printf 'downloaded jeryu does not report a version\n' >&2
    return 1
  }
  got="$("$target" --version)" || {
    printf '%s does not report a version after installing\n' "$target" >&2
    return 1
  }
  if [[ "$got" != "$want" ]]; then
    printf '%s reports %s, expected %s\n' "$target" "$got" "$want" >&2
    return 1
  fi
}
