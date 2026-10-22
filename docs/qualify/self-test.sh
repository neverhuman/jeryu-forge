#!/usr/bin/env bash
# Run every committed fixture. Accept names must pass. Reject names must fail.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
qualify="${root}/qualify.py"
fixture_root="${root}/fixtures"
fail=0

if [[ ! -f "$qualify" ]]; then
  printf 'not ok: missing %s\n' "$qualify" >&2
  exit 1
fi

mapfile -t rules < <(python3 "$qualify" rules)
if [[ "${#rules[@]}" -ne 12 ]]; then
  printf 'not ok: expected 12 rules, got %s\n' "${#rules[@]}" >&2
  exit 1
fi

for rule in "${rules[@]}"; do
  dir="${fixture_root}/${rule}"
  if [[ ! -d "$dir" ]]; then
    printf 'not ok: missing fixture dir %s\n' "$rule" >&2
    fail=1
    continue
  fi
  shopt -s nullglob
  accepts=("${dir}"/accept*.json)
  rejects=("${dir}"/reject*.json)
  shopt -u nullglob
  if [[ "${#accepts[@]}" -lt 1 || "${#rejects[@]}" -lt 1 ]]; then
    printf 'not ok: %s needs at least one accept and one reject\n' "$rule" >&2
    fail=1
    continue
  fi
  for fixture in "${accepts[@]}"; do
    if python3 "$qualify" check "$fixture" >/dev/null; then
      printf 'ok: accept %s\n' "${fixture#"${root}/"}"
    else
      printf 'not ok: accept was denied: %s\n' "$fixture" >&2
      fail=1
    fi
  done
  for fixture in "${rejects[@]}"; do
    status=0
    err="$(python3 "$qualify" check "$fixture" 2>&1 >/dev/null)" || status=$?
    if [[ "$status" -eq 1 && "$err" == "${rule}: "* ]]; then
      printf 'ok: reject %s\n' "${fixture#"${root}/"}"
    elif [[ "$status" -eq 0 ]]; then
      printf 'not ok: reject was admitted: %s\n' "$fixture" >&2
      fail=1
    else
      printf 'not ok: reject was not a denial (exit %s): %s\n' "$status" "$fixture" >&2
      printf '%s\n' "$err" >&2
      fail=1
    fi
  done
done

if [[ "$fail" -ne 0 ]]; then
  printf 'qualify self-test failed\n' >&2
  exit 1
fi
printf 'qualify self-test ok\n'
