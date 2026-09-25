#!/usr/bin/env bash
# Proof that install_jeryu_binary refuses a target it cannot replace.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${root}/scripts/lib/install-target.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

fake_jeryu() {
  local path="$1" version="$2"
  printf '#!/usr/bin/env bash\nprintf %%s\\\\n "%s"\n' "$version" >"$path"
  chmod 0755 "$path"
}

fail=0
check() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    printf 'ok: %s\n' "$name"
  else
    printf 'not ok: %s (expected %s, got %s)\n' "$name" "$expected" "$actual" >&2
    fail=1
  fi
}

src="${work}/jeryu-new"
fake_jeryu "$src" "jeryu 2.0.0"

# A fresh install writes the new binary and it answers --version.
bin="${work}/fresh"
status=0
install_jeryu_binary "$src" "$bin" || status=$?
check "fresh install succeeds" 0 "$status"
check "fresh install is the new build" "jeryu 2.0.0" "$("${bin}/jeryu" --version)"

# Replacing an older binary in place keeps the path a regular file.
fake_jeryu "${bin}/jeryu" "jeryu 1.0.0"
status=0
install_jeryu_binary "$src" "$bin" || status=$?
check "replacing an older binary succeeds" 0 "$status"
check "replaced binary is the new build" "jeryu 2.0.0" "$("${bin}/jeryu" --version)"

# A directory at the target path must fail instead of installing inside it.
bin="${work}/dir"
mkdir -p "${bin}/jeryu"
status=0
install_jeryu_binary "$src" "$bin" 2>/dev/null || status=$?
check "directory target fails" 1 "$status"
check "directory target stays empty" "" "$(ls -A "${bin}/jeryu")"

# A symlink to a directory must fail too: install would write through it.
bin="${work}/link"
mkdir -p "${bin}" "${work}/elsewhere"
ln -s "${work}/elsewhere" "${bin}/jeryu"
status=0
install_jeryu_binary "$src" "$bin" 2>/dev/null || status=$?
check "directory-symlink target fails" 1 "$status"
check "symlink target is untouched" "" "$(ls -A "${work}/elsewhere")"

# A symlink to a file must fail as well: the old binary would stay on PATH.
bin="${work}/filelink"
mkdir -p "$bin"
fake_jeryu "${work}/other-jeryu" "jeryu 1.0.0"
ln -s "${work}/other-jeryu" "${bin}/jeryu"
status=0
install_jeryu_binary "$src" "$bin" 2>/dev/null || status=$?
check "file-symlink target fails" 1 "$status"
check "file-symlink still points at the old build" "jeryu 1.0.0" "$("${work}/other-jeryu" --version)"

if [[ "$fail" != "0" ]]; then
  printf 'tests/install-target.sh failed\n' >&2
  exit 1
fi
printf 'install-target ok\n'
