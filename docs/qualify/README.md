# jeryu-qualify v1.0.0

This directory is an opt-in decision procedure. It reads a JSON report and accepts or denies it. It does not install Jeryu, merge a branch, clone the family, or certify a live forge.

The product split stays `jeryu-v5.0.0-split.0`. `scripts/install.sh` and `scripts/clone-family.sh` are unchanged. Nothing in this directory is called by the Justfile, the GitHub workflow, or the pre-push hook. `tests/qualify-contract.sh` only runs the fixtures below, because an unwired checker would be another scaffold.

The twelve rules are the gaps the portal audit and the four engineering reviews all treat as blocking for the path that owns them. The fixes still belong in those owners (`jeryu-core`, `jeryu-deploy`, `jeryu-ci-runner`, `jeryu-cache`, `jeryu-intelligence`, `jeryu-release-ops`). This kit is the contract a later change has to satisfy. A passing fixture is not evidence that the product implements the rule.

## Run

```bash
bash docs/qualify/self-test.sh
bash tests/qualify-contract.sh
python3 docs/qualify/qualify.py check docs/qualify/fixtures/signature_required/accept.json
```

`check` exits 0 when the report is admitted, 1 when it is denied, and 2 when the file is not a fixture. A denial is one line on stderr: `rule: reason`.

## Rules

| Rule | Admit only when |
| --- | --- |
| `signature_required` | Version is pinned, cosign state is `verified`, and the signer is the `jeryu-deploy` release workflow on a git ref. |
| `skipped_is_not_pass` | A required lane result is `pass` and at least one test was collected. |
| `degraded_is_not_enforced` | An untrusted successful launch has Landlock, seccomp, `no_new_privs`, and a cgroup. |
| `authorized_head_is_landed_head` | Resolved head and base are the authorized commit ids. |
| `ack_requires_durable_intent` | Persist succeeded, the run id is durable, and accept did not precede persist. |
| `repo_scope_required` | The repository is known, the decision is an explicit allow, and the query scope is that repository. |
| `rustflags_order_preserved` | Claimed key equality matches order-preserving rustflags and set-wise features. |
| `simulation_is_not_evidence` | Required evidence is `verified` and produced by someone other than the author. |
| `credential_not_in_workspace` | Export paths and flags carry no host credential material. |
| `claim_requires_ready` | The cell was Ready, queued, unclaimed, and the epoch matches. |
| `family_lock_pins_oids` | Every member is pinned to a 40-hex commit id. |
| `remote_allowlist` | The remote is https on `git.neverhuman.org` or `github.com/neverhuman/`. |

A fixture is `{"rule": "<name>", "report": { ... }}`. Names beginning with `accept` must pass. Names beginning with `reject` must fail.
