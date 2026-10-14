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
# Validate the shape before git sees the value: a ref name, an option-like
# string or an abbreviated sha never reaches `git merge-base`.
[[ "$baseline_commit" =~ ^[0-9a-f]{40}$ ]] || {
  printf 'ratchet baseline provenance must name a full commit sha: %s\n' "$baseline_commit" >&2
  exit 1
}
if ! git merge-base --is-ancestor "$baseline_commit" HEAD; then
  printf 'ratchet baseline commit %s is not an ancestor of HEAD\n' "$baseline_commit" >&2
  exit 1
fi
# Jankurai 1.7 records the full 40-char head; an abbreviated head is a stale
# (pre-1.7) baseline and must be regenerated, never matched by prefix.
baseline_head="$(jq -er '.git.head' "$baseline")"
[[ "$baseline_head" == "$baseline_commit" ]] || {
  printf 'baseline report head %s does not match its provenance commit %s\n' \
    "$baseline_head" "$baseline_commit" >&2
  exit 1
}
sha256_of() { sha256sum | cut -d' ' -f1; }
# The provenance names the exact report bytes it describes.
[[ "$(jq -er '.report.sha256' "$provenance")" == "$(sha256_of <"$baseline")" ]] || {
  printf 'baseline report bytes do not match the digest in its provenance\n' >&2
  exit 1
}
# A baseline audited on a dirty tree is accepted only as the declared policy
# overlay, and the overlay is checked here rather than taken on trust: the
# overlaid policy must be this commit's agent/audit-policy.toml byte for byte,
# and the source digest must be the policy at the audited commit. Any other
# dirty baseline is refused.
report_dirty="$(jq -r '(.dirty_worktree // false) or (.git.dirty_worktree // false)' "$baseline")"
provenance_dirty="$(jq -r '.source.dirty_worktree // false' "$provenance")"
[[ "$report_dirty" == "$provenance_dirty" ]] || {
  printf 'baseline report dirty_worktree=%s disagrees with its provenance (%s)\n' \
    "$report_dirty" "$provenance_dirty" >&2
  exit 1
}
if [[ "$report_dirty" == true ]]; then
  jq -e '.policy.overlay == true and .policy.path == "agent/audit-policy.toml"' \
    "$provenance" >/dev/null || {
    printf 'baseline audited a dirty tree without a declared policy overlay\n' >&2
    exit 1
  }
  [[ "$(jq -er '.policy.sha256' "$provenance")" == "$(sha256_of <agent/audit-policy.toml)" ]] || {
    printf 'baseline policy overlay is not this commit'"'"'s agent/audit-policy.toml\n' >&2
    exit 1
  }
  [[ "$(jq -er '.policy.source_commit_policy_sha256' "$provenance")" == \
    "$(git show "${baseline_commit}:agent/audit-policy.toml" | sha256_of)" ]] || {
    printf 'baseline source policy digest is not agent/audit-policy.toml at %s\n' "$baseline_commit" >&2
    exit 1
  }
fi

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
