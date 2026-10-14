# Jankurai ratchet baseline

`main.repo-score.json` is a full jankurai audit of protected `main` at the
commit named in `main.repo-score.provenance.json`, generated in a clean clone
with the command recorded there. `ops/ci/proof_evidence.sh` replays the
candidate against it in ratchet mode: a lower score, a new cap or a new hard
finding fails the lane. The candidate run never writes this file.

Refresh it from a clean clone of the new protected `main` when `main` improves,
and submit the changed bytes for review like any other change.

The active baseline is a Jankurai 1.7.4 report of the protected `main` commit
named in its provenance, generated from a no-local clone. Jankurai 1.7 records
the full 40-character `git.head`, and `ops/ci/proof_evidence.sh` requires it to
equal the provenance commit exactly. The superseded 1.6.11 baseline (7-character
head) stays byte-for-byte under `historical/jankurai-1.6.11/` as
non-authoritative history; never relabel it as 1.7 evidence.
The ratchet refuses a baseline audited under a different policy
(`policy_changed`), so when a change edits `agent/audit-policy.toml` the
baseline audits protected `main` with that change's policy overlaid on the
clean clone; the provenance records the overlay (`policy.overlay`, both policy
digests) and the report shows `dirty_worktree: true`.
