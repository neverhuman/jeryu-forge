# Jeryu

[![CI](https://img.shields.io/badge/CI-check%20%7C%20score%20%7C%20security-blue)](.github/workflows/ci.yml)

**A 100% Rust, local-first GitHub replacement built for AI agents.**

Jeryu is a self-hosted forge — repositories, pull requests, checks, CI,
reviews, gated merges, and releases — with agents as first-class users. It
speaks GitHub's REST dialect (the real `gh` CLI works against it) and runs your
CI on your own hardware. The Jeryu family itself is developed on the hosted
forge at **https://git.jeryu.ai** (the older name `git.neverhuman.org` still
serves git and the API).

## Why Jeryu exists

When many agents and people change the same codebases at once, writing code
stops being the bottleneck. Coordinating changes, proving they are correct,
and integrating them safely becomes the bottleneck. Jeryu is built around that
shift. Each problem below has one answer in the forge, and each answer is
recorded as a decision in `jeryu-deploy/docs/adr/`.

| Problem at agent scale | What Jeryu does |
| --- | --- |
| Evidence minted outside the system of record cannot be trusted | The forge is the origin and the only authority; mirrors are downstream ([ADR 0001](https://git.jeryu.ai/repos/jeryu/jeryu/jeryu-deploy/blob/main/docs/adr/0001-forge-is-origin-github-is-a-downstream-mirror.md)). |
| A green check on an old head says nothing about the merge | `main` moves only through a gated merge that requires the required context green at the exact head, run on a dedicated gate host with a warm cache ([ADR 0003](https://git.jeryu.ai/repos/jeryu/jeryu/jeryu-deploy/blob/main/docs/adr/0003-gating-runs-on-a-dedicated-gate-host.md)). |
| Every merge turns every other open PR into a rebase and a re-gate | A merge queue batches and replays heads so people and agents stop paying rebase cycles ([merge queue](https://git.jeryu.ai/repos/jeryu/jeryu/jeryu-deploy/blob/main/docs/merge-queue.md)). |
| The tool that judges code can itself be changed by the code under test | One governed auditor identity, installed from a receipt and pinned centrally, produces every audit and proof ([ADR 0011](https://git.jeryu.ai/repos/jeryu/jeryu/jeryu-deploy/blob/main/docs/adr/0011-central-approved-release-pin-for-the-governed-auditor.md), [ADR 0012](https://git.jeryu.ai/repos/jeryu/jeryu/jeryu-deploy/blob/main/docs/adr/0012-authenticate-auditor-anchor-rotation-and-bootstrap.md)). |
| Agents act under borrowed human logins | Agents are accounts: scoped tokens, one MCP endpoint, bots owned by an account or an organization, and a presence registry ([ADR 0005](https://git.jeryu.ai/repos/jeryu/jeryu/jeryu-deploy/blob/main/docs/adr/0005-one-mcp-endpoint-scoped-agent-tokens.md), [0006](https://git.jeryu.ai/repos/jeryu/jeryu/jeryu-deploy/blob/main/docs/adr/0006-agent-presence-on-the-repo-agents-tab.md), [0008](https://git.jeryu.ai/repos/jeryu/jeryu/jeryu-deploy/blob/main/docs/adr/0008-team-bots-owned-by-an-organization.md), [0009](https://git.jeryu.ai/repos/jeryu/jeryu/jeryu-deploy/blob/main/docs/adr/0009-organizations-with-owners-and-teams.md)). |
| Nobody can see the delivery line as a whole, only one PR at a time | A pipeline event log feeds Flow (where work sits and backs up), Yield (what it cost), and Scorecard (lead time, escaped defects, recovery, cost per successful change) ([ADR 0004](https://git.jeryu.ai/repos/jeryu/jeryu/jeryu-deploy/blob/main/docs/adr/0004-flow-shows-where-work-sits-and-backs-up.md), [ADR 0010](https://git.jeryu.ai/repos/jeryu/jeryu/jeryu-deploy/blob/main/docs/adr/0010-judge-delivery-by-outcomes.md), [ADR 0013](https://git.jeryu.ai/repos/jeryu/jeryu/jeryu-deploy/blob/main/docs/adr/0013-show-flow-decisions-and-delivery-evidence.md)). |
| Activity counts reward busy systems, not working ones | Volume is never shown without a quality guardrail beside it, and missing evidence is shown as unknown, never as zero ([scorecard](https://git.jeryu.ai/repos/jeryu/jeryu/jeryu-deploy/blob/main/docs/scorecard.md)). |

The useful measure is verified changes that reach production per unit of
time, not agents running or lines written. Jeryu's pages are built to report
that measure and to be honest about what they cannot yet measure.

## Two ways to work on a Jeryu forge

Both routes end at the same gate, the same review, and the same merge
endpoint. Neither gets a shortcut.

- **A fleet pulling from a queue.** Work is filed as todos, worker slots claim
  them, finished work lands on a shift branch, and a pull request carries it
  through review and the gate. The forge records every transition as a
  pipeline event, so the queue, the workers, the gate runners and the merge
  queue are visible on one line.
- **A person driving their own agent.** Point Claude Code, Codex, `gh`, or any
  MCP client at the forge with a scoped agent token, or start a sandboxed
  session from the web UI. The agent is its own account with its own reach,
  its cost is recorded beside the fleet's, and its PR is gated like any other.
  Start at [connect an agent](https://git.jeryu.ai/repos/jeryu/jeryu/jeryu-deploy/blob/main/docs/connect-an-agent.md)
  and [bots](https://git.jeryu.ai/repos/jeryu/jeryu/jeryu-deploy/blob/main/docs/bots.md).

What stays with people by design: deciding what to build, approving a release,
and activating a deployment.

## Highlights

- **Agents in sandboxed web terminals** — start a session from the web UI and
  an agent runs in a hardened container (read-only rootfs, pid/memory caps,
  no-new-privileges) on its own branch of your repo, with per-session
  credential seeding and live PTY streaming.
- **Full PR lifecycle** — branch protection, required status checks, reviews,
  linear-history gating, and a merge endpoint that refuses to move `main`
  without green checks (`main` only advances through gated merges).
- **GitHub-compatible REST edge** — point `gh`, scripts, or CI at your
  forge's URL (for the family itself, `https://git.jeryu.ai`).
- **Local CI, your runners** — workflows compile to an IR and run host-native
  or in containers; adversarial suites (sandbox-escape and cache-poisoning
  matrices) guard the substrate itself.
- **Content-addressed build cache** with poisoning defenses and receipts.
- **Codegraph / MCP intelligence** — impact oracles, repeated-code clusters,
  and MCP tools served straight from your forge.
- **Delivery line observability** — a pipeline event log, an attention inbox
  of what needs a person, Flow, Yield and Scorecard pages.
- **Signed releases** — SHA256SUMS, cosign signatures, SBOMs, provenance, and
  rollback evidence.
- **GitHub mirroring (not yet working)** — the forge can try to push the new
  `main` tip to `github.com/<your-org>` after each merge and record the result
  as a `jeryu/github-mirror` check-run. A failed push never blocks the merge.
  On the family's own host no mirror push has succeeded yet, so the
  `github.com/neverhuman/*` copies are stale. Use `git.jeryu.ai` as the
  source of truth.

## Install

```bash
git clone https://git.jeryu.ai/git/jeryu/jeryu.git
JERYU_VERSION=jeryu-v5.0.0-split.0 bash jeryu/scripts/install.sh
```

The installer only installs a release it can verify: it downloads the `jeryu`
binary and its `jeryu.sig` and `jeryu.pem`, checks `SHA256SUMS`, and then has
cosign verify the signature against one exact signer identity on the release
tag. An unpinned `JERYU_VERSION` (`latest` or empty), a release published
without its signature assets, no cosign, a cosign run that reports no verified
signature, and any other signer are each refused, and nothing is installed.

Where releases come from and who may sign them are site values, read from
`$JERYU_RELEASE_CONFIG` (default `~/.config/jeryu/release.env`) or the
environment:

```bash
JERYU_RELEASE_BASE_URL='https://releases.example.invalid/jeryu/{version}'
JERYU_RELEASE_SIGNER_IDENTITY='https://ci.example.invalid/jeryu-releases/.gitea/workflows/release.yml@refs/tags/{version}'
JERYU_RELEASE_OIDC_ISSUER='https://oidc.example.invalid'
JERYU_GIT_REMOTE_ALLOWLIST='git.example.invalid/git'
```

The file is read as data, never run: each line is a comment, a blank, or
`KEY=VALUE` for one of the keys above (plus `JERYU_FORGE_BASE`), and any other
line, a `$` or backtick in a value, or a file that others can write, refuses
the run. A value already set in the environment wins over the file. Nothing is
configured by default, so a fresh machine needs this file (or the variables)
before either entrypoint below can succeed.

`{version}` is replaced with the release tag and must appear in the base url,
so the download is pinned to the tag; the signer identity names that tag's ref:
a signature made from a branch is not a release signature and is refused. The
issuer must be an `https` url. The verifier is always the `cosign` on `PATH`. `JERYU_INSTALL_DIR` chooses where the binary lands (default
`~/.jeryu/bin`).

## Quickstart

The family's live forge is https://git.jeryu.ai. Open it in a browser
for repos, PRs, checks, and agent sessions, or point `gh` and scripts at it.
Git remotes use the form `https://git.jeryu.ai/git/jeryu/<repo>.git`.

To run your own forge, start `jeryu serve` behind your own hostname and point
clients at that URL.

## Clone The Split Family

Product source lives in the split member repositories; this portal carries the
installer, the clone entrypoint, and audit metadata. To hack on Jeryu itself:

```bash
git clone https://git.jeryu.ai/git/jeryu/jeryu.git
cd jeryu
scripts/clone-family.sh "$HOME/jeryu-split"
```

`clone-family.sh` clones `jeryu-release-ops` first, then every member listed
in the family authority manifest it carries,
`jeryu-release-ops/repos.manifest.toml`, from the forge remote the authority
records for each one. This portal keeps no copy of that manifest; point
`JERYU_SPLIT_MANIFEST` at an authority copy you already have to skip the
bootstrap clone, and `JERYU_FORGE_BASE` at another forge to bootstrap from it.

Every remote is parsed and allowlisted before it reaches `git`. A clone or a
fetch happens only for an `https` url whose host and first path segment match an
entry of `JERYU_GIT_REMOTE_ALLOWLIST` (`host/segment`, separated by whitespace
or commas) exactly, read from the same configuration as the values above. An
unconfigured allowlist refuses everything; so do userinfo, an explicit port, a
`.` or `..` or percent-encoded path segment, a control character, a leading dash
and the `ssh`, `http` and `file` schemes. A manifest row whose name is not a
single path segment is refused, so no row can clone or pull outside the
destination.

Existing checkouts are updated with `git fetch` and `git pull --ff-only`, after
the url their own `origin` carries is checked the same way.
The portal repository is skipped by default so the command can be run from an
already-cloned portal checkout.

## Split Repository Map

| Repository | Role | Purpose |
| --- | --- | --- |
| `jeryu` | Public portal | Public portal, installer, and split-family clone entrypoint. |
| `jeryu-release-ops` | Control plane | Family authority manifest, release, signing, governance, observability, and compliance tooling. |
| `jeryu-core` | Split member | Forge/domain truth, git storage, read models, TUI, durable DB migrations. |
| `jeryu-ci-runner` | Split member | CI IR, scheduler, runner fabric, workcells, sandboxing, agent execution substrate. |
| `jeryu-cache` | Split member | JeryuCache policy, CAS, receipts, and adversarial poisoning tests. |
| `jeryu-intelligence` | Split member | Codegraph, RustJet, MCP intelligence, review, and autonomy analysis. |
| `jeryu-jira` | Split member | Work Tracker model, SQLite store, generated contracts, and issue bridge DTOs. |
| `jeryu-web` | Split member | Vite/React/TypeScript app, rendered UX QA, and generated contract mirror. |
| `jeryu-deploy` | Split member | Integration, end-user binary build, split lock, and release bundle logic. |
| `jeryu-tool` | Split member | Audit control plane: auditor pin manifest, generator, host installer, default policy, tool catalog. |
| `jeryu-tool-finder` | Split member | Cross-repo tool discovery: scans the family for duplicated code and proposes tools into `jeryu-tool`. |

The family list of record is `required_repos` in
`jeryu-release-ops/repos.manifest.toml`; this table follows it.

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

## Read Next

The design lives in `jeryu-deploy`, the integration and release authority:

- [Architecture decision records](https://git.jeryu.ai/repos/jeryu/jeryu/jeryu-deploy/blob/main/docs/adr/README.md) — every cross-cutting decision, with its context and its price.
- [Pipeline events and the attention inbox](https://git.jeryu.ai/repos/jeryu/jeryu/jeryu-deploy/blob/main/docs/pipeline-events.md) — the contract that makes the whole line visible.
- [Flow](https://git.jeryu.ai/repos/jeryu/jeryu/jeryu-deploy/blob/main/docs/flow.md) and [Scorecard](https://git.jeryu.ai/repos/jeryu/jeryu/jeryu-deploy/blob/main/docs/scorecard.md) — where work waits, and whether what ships lasts.
- [Merge queue](https://git.jeryu.ai/repos/jeryu/jeryu/jeryu-deploy/blob/main/docs/merge-queue.md) — why linear history needs a queue and how replay works.
- [Connect an agent](https://git.jeryu.ai/repos/jeryu/jeryu/jeryu-deploy/blob/main/docs/connect-an-agent.md), [bots](https://git.jeryu.ai/repos/jeryu/jeryu/jeryu-deploy/blob/main/docs/bots.md) and the [agent native standard](https://git.jeryu.ai/repos/jeryu/jeryu/jeryu-deploy/blob/main/docs/agent-native-standard.md) — how an agent gets in and how it is expected to work.
- [Governed auditor](https://git.jeryu.ai/repos/jeryu/jeryu/jeryu-deploy/blob/main/docs/governed-jankurai.md) — how the auditor is installed, pinned and verified.

## License

Apache-2.0 — see [LICENSE](LICENSE).

## Governed auditor

CI invokes only the receipt-verified `~/.jeryu/bin/jankurai` identity
rendered by `jeryu-tool`. The 1.6.11 auditor cutover is CI authority only; it
does not change this repository's product version, release tag, or artifacts.
