#!/usr/bin/env bash
# Proof that the release configuration is read as data, never run, and that a
# manifest row cannot name a path outside the clone destination.
# Every host and value below is invented.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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

receipt() {
  mkdir -p "${root}/target/tests"
  cat >"${root}/target/tests/release-config-receipt.json" <<JSON
{"schema_version":"jeryu.release.config-proof/v1","guard":"scripts/lib/release-config.sh","assertions":${checked},"conclusion":"$1","repair_hint":"bash tests/release-config.sh"}
JSON
}

keys=(JERYU_RELEASE_BASE_URL JERYU_RELEASE_SIGNER_IDENTITY JERYU_RELEASE_OIDC_ISSUER
  JERYU_GIT_REMOTE_ALLOWLIST JERYU_FORGE_BASE JERYU_VERSION)

# load <config> [VAR=VALUE ...]: load the file in a clean shell and print the
# keys it leaves set, or exit non-zero when the loader refuses.
load() {
  local config="$1"; shift
  local -a unset_args=()
  local key
  for key in "${keys[@]}"; do unset_args+=(-u "$key"); done
  env "${unset_args[@]}" "JERYU_RELEASE_CONFIG=${config}" "$@" bash -c '
    set -euo pipefail
    source "$1/scripts/lib/release-config.sh"
    jeryu_load_release_config
    printf "%s|%s|%s\n" "${JERYU_RELEASE_BASE_URL-unset}" "${JERYU_GIT_REMOTE_ALLOWLIST-unset}" "${JERYU_VERSION-unset}"
  ' _ "$root" 2>"${work}/load.err"
}

status_of() { local s=0; "$@" >/dev/null || s=$?; printf '%s' "$s"; }

new_config() { # NAME CONTENT — a private config file
  local path="${work}/$1.env"
  printf '%s' "$2" >"$path"
  chmod 0600 "$path"
  printf '%s' "$path"
}

good="$(new_config good $'# site values\nJERYU_RELEASE_BASE_URL=\'https://releases.example.invalid/{version}\'\nexport JERYU_GIT_REMOTE_ALLOWLIST="git.example.invalid/git"\n\n')"
check "a KEY=VALUE file is read" \
  "https://releases.example.invalid/{version}|git.example.invalid/git|unset" "$(load "$good")"
check "the environment wins over the file" \
  "https://env.example.invalid/{version}|git.example.invalid/git|unset" \
  "$(load "$good" "JERYU_RELEASE_BASE_URL=https://env.example.invalid/{version}")"
check "a missing file is no configuration" "unset|unset|unset" "$(load "${work}/absent.env")"
check "/dev/null is no configuration" "unset|unset|unset" "$(load /dev/null)"

marker="${work}/ran"
runs="$(new_config runs "JERYU_RELEASE_BASE_URL=https://x.invalid/{version}
touch ${marker}
")"
check "a command line in the file is refused" 1 "$(status_of load "$runs")"
check "a command line in the file never runs" "no" "$([[ -e "$marker" ]] && echo yes || echo no)"

subst="$(new_config subst "JERYU_RELEASE_BASE_URL=https://x.invalid/\$(touch ${marker})
")"
check "a command substitution in a value is refused" 1 "$(status_of load "$subst")"
check "a command substitution in a value never runs" "no" "$([[ -e "$marker" ]] && echo yes || echo no)"

version="$(new_config version $'JERYU_VERSION=jeryu-v0.0.1\n')"
check "a key outside the release configuration is refused" 1 "$(status_of load "$version")"
path_key="$(new_config path $'PATH=/attacker/bin\n')"
check "PATH cannot be set from the file" 1 "$(status_of load "$path_key")"

shared="$(new_config shared $'JERYU_FORGE_BASE=https://forge.example.invalid\n')"
chmod 0620 "$shared"
check "a group-writable file is refused" 1 "$(status_of load "$shared")"
chmod 0602 "$shared"
check "a world-writable file is refused" 1 "$(status_of load "$shared")"

ln -s "$good" "${work}/link.env"
check "a symlinked file is refused" 1 "$(status_of load "${work}/link.env")"

# A manifest row whose name walks out of the destination never clones there.
manifest="${work}/repos.manifest.toml"
cat >"$manifest" <<'TOML'
[[repo]]
name = "../escape"
remote = "https://git.example.invalid/git/jeryu/escape.git"
TOML
dest="${work}/family"
status=0
env "JERYU_SPLIT_MANIFEST=${manifest}" "JERYU_RELEASE_CONFIG=/dev/null" \
  "JERYU_GIT_REMOTE_ALLOWLIST=git.example.invalid/git" \
  bash "${root}/scripts/clone-family.sh" "$dest" >/dev/null 2>"${work}/clone.err" || status=$?
check "a manifest name outside the destination is refused" 1 "$status"
check "nothing is created outside the destination" "no" "$([[ -e "${work}/escape" ]] && echo yes || echo no)"

if [[ "$fail" != "0" ]]; then
  receipt failure
  printf 'tests/release-config.sh failed\n' >&2
  exit 1
fi
receipt success
printf 'release-config ok\n'
