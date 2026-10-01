#!/usr/bin/env bash
# Canonical local PR gate for jeryu. host-ci prefers this script and posts the
# `jeryu/required` check-run from its exit status; .github/workflows/ci.yml runs
# the same lanes on the GitHub mirror so the two surfaces cannot diverge.
set -euo pipefail

# BEGIN GENERATED JANKURAI PIN — DO NOT EDIT
# The governed Jankurai identity is the binary installed on this host and its
# installation receipt: require_jankurai verifies both and exports JERYU_JANKURAI_*
# from the receipt. The one pin of record is jeryu-tool's tool-manifest.toml.
# END GENERATED JANKURAI PIN


repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

# jeryu governs the worker count from live load; never default high.
if [ -n "${JERYU_CI_JOBS:-}" ]; then
  JOBS="${JERYU_CI_JOBS}"
elif command -v jeryu-ci-governor >/dev/null 2>&1; then
  JOBS="$(jeryu-ci-governor 2>/dev/null || echo 8)"
else
  JOBS=8
fi
export JERYU_CI_JOBS="$JOBS"
export CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-$JOBS}"

# Resolve and verify the absolute governed auditor before any lane runs.
source ops/ci/lib.sh
require_jankurai

# jankurai pin: jeryu-tool/tool-manifest.toml is the family-wide source of truth.
# When the control-plane repo is reachable (on-host family layout), fail fast if
# this repo's pinned consumers drifted from it. In an isolated single-repo CI
# checkout it is absent — skip rather than fail.
JERYU_TOOL_RENDER="${JERYU_TOOL_RENDER:-$repo_root/../jeryu-tool/ops/render-tool-manifest.sh}"
if [ -x "$JERYU_TOOL_RENDER" ]; then
  echo "[pr-ci] jankurai pin drift check" >&2
  consumer_repo="$(awk -F'\"' '/^workspace =/ {print $2; exit}' agent/audit-policy.toml)"
  bash "$JERYU_TOOL_RENDER" --check --repo "$consumer_repo" \
    --repo-root "$consumer_repo=$repo_root"
fi

echo "[pr-ci] (jobs=$JOBS) standard lanes" >&2
bash ops/ci/fast.sh
JERYU_SPLIT_FULL_CHECK=1 bash ops/ci/check.sh
bash ops/ci/score.sh
bash tools/security-lane.sh
bash ops/ci/artifact_support.sh

echo "[pr-ci] portal script syntax checks" >&2
for s in scripts/*.sh ops/ci/*.sh; do bash -n "$s"; done
echo "[pr-ci] jeryu OK" >&2
