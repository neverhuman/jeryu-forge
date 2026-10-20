#!/usr/bin/env bash
# Exercise the clone entrypoint with a recorded transport and authority manifest.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "${root}/target/tests"
work="$(mktemp -d "${root}/target/tests/forge-default.XXXXXX")"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin"
cat >"$work/manifest" <<'TOML'
required_repos = ["jeryu-release-ops", "jeryu-core"]
[control_plane]
name = "jeryu-release-ops"
remote = "https://git.neverhuman.org/git/jeryu/jeryu-release-ops.git"
[[repo]]
name = "jeryu-core"
remote = "https://git.neverhuman.org/git/jeryu/jeryu-core.git"
TOML
cat >"$work/bin/git" <<'GIT'
#!/usr/bin/env bash
set -euo pipefail
[[ "$1" == clone && "$2" == -- ]]
printf '%s\n' "$3" >>"$GIT_CALL_LOG"
mkdir -p "$4/.git"
if [[ "$4" == */jeryu-release-ops ]]; then
  cp "$AUTHORITY_FIXTURE" "$4/repos.manifest.toml"
fi
GIT
chmod +x "$work/bin/git"
export PATH="$work/bin:$PATH" AUTHORITY_FIXTURE="$work/manifest"
export JERYU_RELEASE_CONFIG=/dev/null JERYU_SPLIT_MANIFEST= JERYU_CLONE_PORTAL=0
run_case() {
  local name="$1" forge="$2" allowlist="$3" expected_status="$4" expected_calls="$5"
  export GIT_CALL_LOG="$work/$name.log"
  : >"$GIT_CALL_LOG"
  local status=0
  JERYU_FORGE_BASE="$forge" JERYU_GIT_REMOTE_ALLOWLIST="$allowlist" \
    bash "$root/scripts/clone-family.sh" "$work/$name" >"$work/$name.out" 2>&1 || status=$?
  [[ "$status" == "$expected_status" && "$(cat "$GIT_CALL_LOG")" == "$expected_calls" ]] || {
    cat "$work/$name.out" >&2
    printf 'failed: %s (status %s)\n' "$name" "$status" >&2
    exit 1
  }
  printf 'ok: %s\n' "$name"
}
bootstrap='https://git.jeryu.ai/git/jeryu/jeryu-release-ops.git'
previous='https://git.neverhuman.org/git/jeryu/jeryu-release-ops.git'
member='https://git.neverhuman.org/git/jeryu/jeryu-core.git'
run_case default '' 'git.jeryu.ai/git git.neverhuman.org/git' 0 "$bootstrap"$'\n'"$member"
run_case explicit https://git.neverhuman.org git.neverhuman.org/git 0 "$previous"$'\n'"$member"
run_case bootstrap_refused '' git.neverhuman.org/git 1 ''
run_case member_refused '' git.jeryu.ai/git 1 "$bootstrap"
run_case unconfigured '' '' 1 ''
# An explicit authority copy includes the separately listed control plane.
export JERYU_SPLIT_MANIFEST="$work/manifest"
run_case authority_copy '' git.neverhuman.org/git 0 "$previous"$'\n'"$member"
