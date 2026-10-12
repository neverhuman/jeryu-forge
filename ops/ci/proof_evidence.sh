#!/usr/bin/env bash
# Jankurai tool-adoption evidence lane. Every tool listed as `auto` in
# agent/tool-adoption.toml runs here for real and fails the lane on failure;
# no artifact is synthesized, and the ratchet baseline is the committed,
# reviewed report of protected main (agent/baselines/), never this run's output.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"
source ops/ci/lib.sh
require_jankurai

base_ref="${JERYU_PROOF_BASE_REF:-origin/main}"
baseline=agent/baselines/main.repo-score.json
provenance=agent/baselines/main.repo-score.provenance.json

if ! git rev-parse --verify "${base_ref}^{commit}" >/dev/null 2>&1; then
  case "$base_ref" in
    origin/*) git fetch --no-tags origin "${base_ref#origin/}:refs/remotes/${base_ref}" ;;
  esac
fi
git rev-parse --verify "${base_ref}^{commit}" >/dev/null
baseline_commit="$(jq -er '.source.commit' "$provenance")"
if ! git merge-base --is-ancestor "$baseline_commit" HEAD; then
  printf 'ratchet baseline commit %s is not an ancestor of HEAD\n' "$baseline_commit" >&2
  exit 1
fi
[[ "$(jq -er '.git.head' "$baseline")" == "${baseline_commit:0:7}" ]] || {
  printf 'baseline report does not match its provenance commit\n' >&2
  exit 1
}

rm -rf target/jankurai/proofbind target/jankurai/security \
  target/jankurai/accepted-baseline.json target/jankurai/repo-score.json \
  target/jankurai/repo-score.md target/jankurai/repair-queue.jsonl
mkdir -p target/jankurai/proofbind target/jankurai/security
cp "$baseline" target/jankurai/accepted-baseline.json

jankurai proofbind verify . --changed-from origin/main --out target/jankurai/proofbind/surface-witness.json --obligations-out target/jankurai/proofbind/obligations.json
jankurai security run . --out target/jankurai/security/evidence.json --strict --profile ci
jq -e --arg head "$(git rev-parse HEAD)" '
  .git_head == $head and .exit_code == 0 and
  ([.commands[] | select(.status != "ran" or .exit_code != 0)] | length) == 0
' target/jankurai/security/evidence.json >/dev/null

jankurai audit . --mode ratchet --baseline target/jankurai/accepted-baseline.json --json target/jankurai/repo-score.json --md target/jankurai/repo-score.md --policy agent/audit-policy.toml --full --repair-queue-jsonl target/jankurai/repair-queue.jsonl --no-score-history
jq -e '.decision.hard_findings == 0 and (.caps_applied | length) == 0' \
  target/jankurai/repo-score.json >/dev/null

for artifact in target/jankurai/proofbind/surface-witness.json \
  target/jankurai/proofbind/obligations.json \
  target/jankurai/security/evidence.json target/jankurai/repo-score.json; do
  [[ -s "$artifact" ]] || { printf 'missing tool output: %s\n' "$artifact" >&2; exit 1; }
done
printf 'proof evidence ok\n'
