# Jeryu

**A 100% Rust, local-first GitHub replacement built for AI agents.**

Jeryu is a self-hosted forge — repositories, pull requests, checks, CI,
reviews, gated merges, and releases — with agents as first-class users. It
speaks GitHub's REST dialect (the real `gh` CLI works against it) and runs your
CI on your own hardware. The Jeryu family itself is developed on the hosted
forge at **https://git.neverhuman.org**.

## Highlights

- **Agents in sandboxed web terminals** — start a session from the web UI and
  an agent runs in a hardened container (read-only rootfs, pid/memory caps,
  no-new-privileges) on its own branch of your repo, with per-session
  credential seeding and live PTY streaming.
- **Full PR lifecycle** — branch protection, required status checks, reviews,
  linear-history gating, and a merge endpoint that refuses to move `main`
  without green checks (`main` only advances through gated merges).
- **GitHub-compatible REST edge** — point `gh`, scripts, or CI at your
  forge's URL (for the family itself, `https://git.neverhuman.org`).
- **Local CI, your runners** — workflows compile to an IR and run host-native
  or in containers; adversarial suites (sandbox-escape and cache-poisoning
  matrices) guard the substrate itself.
- **Content-addressed build cache** with poisoning defenses and receipts.
- **Codegraph / MCP intelligence** — impact oracles, repeated-code clusters,
  and MCP tools served straight from your forge.
- **Signed releases** — SHA256SUMS, cosign signatures, SBOMs, provenance, and
  rollback evidence.
- **GitHub mirroring (not yet working)** — the forge can try to push the new
  `main` tip to `github.com/<your-org>` after each merge and record the result
  as a `jeryu/github-mirror` check-run. A failed push never blocks the merge.
  On the family's own host no mirror push has succeeded yet, so the
  `github.com/neverhuman/*` copies are stale. Use `git.neverhuman.org` as the
  source of truth.

## Install

```bash
git clone https://git.neverhuman.org/git/jeryu/jeryu.git
bash jeryu/scripts/install.sh
```

Pin a release or install somewhere else:

```bash
JERYU_VERSION=jeryu-v5.0.0-split.0 JERYU_INSTALL_DIR="$HOME/.local/bin" \
  bash scripts/install.sh
```

The installer downloads the `jeryu` binary from `neverhuman/jeryu-deploy`
releases, verifies `SHA256SUMS`, and runs cosign verification when
`jeryu.sig`, `jeryu.pem`, and `cosign` are available.

## Quickstart

The family's live forge is https://git.neverhuman.org. Open it in a browser
for repos, PRs, checks, and agent sessions, or point `gh` and scripts at it.
Git remotes use the form `https://git.neverhuman.org/git/jeryu/<repo>.git`.

To run your own forge, start `jeryu serve` behind your own hostname and point
clients at that URL.

## Clone The Split Family

Product source lives in the split member repositories; this portal carries the
installer, the clone entrypoint, and audit metadata. To hack on Jeryu itself:

```bash
git clone https://git.neverhuman.org/git/jeryu/jeryu.git
cd jeryu
scripts/clone-family.sh "$HOME/jeryu-split"
```

`clone-family.sh` still clones the members from the `github_slug` remotes
listed in the manifest. Those GitHub copies are stale (see GitHub mirroring
above). Until the script is switched over, re-point each member with
`git remote set-url origin https://git.neverhuman.org/git/jeryu/<repo>.git`.

Existing checkouts are updated with `git fetch` and `git pull --ff-only`.
The portal repository is skipped by default so the command can be run from an
already-cloned portal checkout.

## Split Repository Map

| Repository | Role | GitHub slug (stale mirror) | Purpose |
| --- | --- | --- | --- |
| `jeryu` | Public portal | `neverhuman/jeryu` | Public portal, installer, and split-family clone entrypoint. |
| `jeryu-core` | Split member | `neverhuman/jeryu-core` | Forge/domain truth, git storage, read models, TUI, durable DB migrations. |
| `jeryu-ci-runner` | Split member | `neverhuman/jeryu-ci-runner` | CI IR, scheduler, runner fabric, workcells, sandboxing, agent execution substrate. |
| `jeryu-cache` | Split member | `neverhuman/jeryu-cache` | JeryuCache policy, CAS, receipts, and adversarial poisoning tests. |
| `jeryu-intelligence` | Split member | `neverhuman/jeryu-intelligence` | Codegraph, RustJet, MCP intelligence, review, and autonomy analysis. |
| `jeryu-jira` | Split member | `neverhuman/jeryu-jira` | Work Tracker model, SQLite store, generated contracts, and issue bridge DTOs. |
| `jeryu-web` | Split member | `neverhuman/jeryu-web` | Vite/React/TypeScript app, rendered UX QA, and generated contract mirror. |
| `jeryu-release-ops` | Split member | `neverhuman/jeryu-release-ops` | Release, signing, governance, observability, and compliance tooling. |
| `jeryu-deploy` | Split member | `neverhuman/jeryu-deploy` | Integration, end-user binary build, split lock, and release bundle logic. |

The release authority is `neverhuman/jeryu-deploy`. Cross-repo Rust
dependencies are pinned `*-v5.0.0-split.0` git tags; see `docs/architecture.md`
for how the family fits together.

## Release Evidence

Release receipts, binary checksums, SBOMs, provenance, witness artifacts, and
rollback evidence are published by `neverhuman/jeryu-deploy`:

- https://github.com/neverhuman/jeryu-deploy/releases
- `SHA256SUMS`
- `release-receipt.json`
- `artifact-support-evidence.tar.gz`

## Local Commands

- `just fast`
- `just check`
- `just score`
- `just security`
- `just artifact-support`
- `bash ops/ci/pr-ci.sh` — the canonical PR gate (host CI and the hosted
  workflow both run exactly this)

## License

Apache-2.0 — see [LICENSE](LICENSE).

## Governed auditor

CI invokes only the receipt-verified `/home/ubuntu/.jeryu/bin/jankurai` identity
rendered by `jeryu-tool`. The 1.6.11 auditor cutover is CI authority only; it
does not change this repository's product version, release tag, or artifacts.
