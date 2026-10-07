#!/usr/bin/env bash
# Proof that a git remote is parsed and allowlisted before any clone or fetch.
# Every host, org and path below is invented.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${root}/scripts/lib/git-remote.sh"

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
  cat >"${root}/target/tests/git-remote-receipt.json" <<JSON
{"schema_version":"jeryu.git.remote-proof/v1","guard":"scripts/lib/git-remote.sh","assertions":${checked},"conclusion":"$1","repair_hint":"bash tests/git-remote.sh"}
JSON
}

export JERYU_GIT_REMOTE_ALLOWLIST="git.example.org/git, forge.example.net/examplecorp"

# accepted <name> <url>: the remote the site configured, and nothing more.
accepted() {
  local status=0
  jeryu_check_git_remote "$2" >/dev/null 2>&1 || status=$?
  check "$1" 0 "$status"
}

# refused <name> <url>: every case below is one rule, each on its own.
refused() {
  local status=0
  jeryu_check_git_remote "$2" >/dev/null 2>&1 || status=$?
  check "$1" 1 "$status"
}

accepted "allowlisted host and first segment" "https://git.example.org/git/jeryu/jeryu-core.git"
accepted "second allowlisted entry" "https://forge.example.net/examplecorp/jeryu.git"

refused "empty remote" ""
refused "leading dash is option injection" "--upload-pack=touch /tmp/pwned"
refused "dash before an allowed url" "-c protocol.ext.allow=always https://git.example.org/git/jeryu.git"
refused "newline in remote" "https://git.example.org/git/jeryu.git
https://evil.example.net/git/jeryu.git"
refused "carriage return in remote" "https://git.example.org/git/jeryu.git"$'\r'
refused "tab in remote" "https://git.example.org/git/jeryu.git"$'\t'
refused "ssh scheme" "ssh://git@git.example.org/git/jeryu/jeryu-core.git"
refused "scp-style ssh remote" "git@git.example.org:git/jeryu/jeryu-core.git"
refused "plain http" "http://git.example.org/git/jeryu/jeryu-core.git"
refused "file scheme" "file:///srv/git/jeryu/jeryu-core.git"
refused "ext transport" "ext::sh -c touch% /tmp/pwned"
refused "userinfo before the host" "https://git.example.org@evil.example.net/git/jeryu.git"
refused "explicit port" "https://git.example.org:8443/git/jeryu/jeryu-core.git"
refused "host that only starts with an allowed one" "https://git.example.org.evil.example.net/git/jeryu.git"
refused "host that only ends with an allowed one" "https://evil-git.example.org/git/jeryu.git"
refused "dot-dot path segment" "https://git.example.org/git/../evil/jeryu.git"
refused "single-dot path segment" "https://git.example.org/git/./jeryu.git"
refused "percent-encoded dot segments" "https://git.example.org/git/%2e%2e/evil/jeryu.git"
refused "percent-encoded NUL" "https://git.example.org/git/jeryu.git%00"
refused "no path under the host" "https://git.example.org"
refused "empty trailing segment" "https://git.example.org/git/"
refused "host alone is not an entry" "https://git.example.org/other/jeryu.git"
refused "unlisted host" "https://evil.example.net/git/jeryu.git"
refused "first segment matched by prefix only" "https://forge.example.net/examplecorp-staging/jeryu.git"

# Nothing configured is a refusal, not a clone from wherever.
status=0
(unset JERYU_GIT_REMOTE_ALLOWLIST; jeryu_check_git_remote "https://git.example.org/git/jeryu.git") >/dev/null 2>&1 || status=$?
check "unconfigured allowlist refuses" 1 "$status"
status=0
(JERYU_GIT_REMOTE_ALLOWLIST="  " jeryu_check_git_remote "https://git.example.org/git/jeryu.git") >/dev/null 2>&1 || status=$?
check "blank allowlist refuses" 1 "$status"

# clone-family runs the guard before it hands a manifest remote to git: a stand-in
# git records every call, and must record none.
bin="${work}/bin"
mkdir -p "$bin"
cat >"${bin}/git" <<'GIT'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${GIT_CALL_LOG}"
GIT
chmod 0755 "${bin}/git"

manifest="${work}/repos.manifest.toml"
cat >"$manifest" <<'TOML'
required_repos = ["jeryu-release-ops"]

[[repo]]
name = "jeryu-release-ops"
remote = "ssh://git@evil.example.net/git/jeryu/jeryu-release-ops.git"
TOML

dest="${work}/family"
log="${work}/git-calls"
: >"$log"
status=0
env PATH="${bin}:${PATH}" GIT_CALL_LOG="$log" JERYU_RELEASE_CONFIG=/dev/null \
  JERYU_SPLIT_MANIFEST="$manifest" JERYU_GIT_REMOTE_ALLOWLIST="git.example.org/git" \
  bash "${root}/scripts/clone-family.sh" "$dest" >/dev/null 2>&1 || status=$?
check "clone-family refuses an ssh manifest remote" 1 "$status"
check "clone-family ran no git" "" "$(cat "$log")"

if [[ "$fail" != "0" ]]; then
  receipt "failure"
  printf 'tests/git-remote.sh failed; rerun with bash tests/git-remote.sh\n' >&2
  exit 1
fi
receipt "success"
printf 'git-remote ok\n'
