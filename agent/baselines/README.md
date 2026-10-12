# Jankurai ratchet baseline

`main.repo-score.json` is a full jankurai audit of protected `main` at the
commit named in `main.repo-score.provenance.json`, generated in a clean clone
with the command recorded there. `ops/ci/proof_evidence.sh` replays the
candidate against it in ratchet mode: a lower score, a new cap or a new hard
finding fails the lane. The candidate run never writes this file.

Refresh it from a clean clone of the new protected `main` when `main` improves,
and submit the changed bytes for review like any other change.
