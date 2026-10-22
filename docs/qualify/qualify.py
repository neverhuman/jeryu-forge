#!/usr/bin/env python3
"""Decide a Jeryu qualification report.

The function is pure: one JSON fixture in, one admission or the first denial out.
It does not install, merge, clone, or contact a forge.
"""

import json
import re
import sys
from pathlib import Path

SIGNER_RE = re.compile(
    r"^https://github\.com/neverhuman/jeryu-deploy/"
    r"\.github/workflows/release\.yml@refs/(heads|tags)/[A-Za-z0-9._/-]+$"
)
OID_RE = re.compile(r"^[0-9a-f]{40}$")
REMOTE_PREFIXES = (
    "https://git.neverhuman.org/",
    "https://github.com/neverhuman/",
)
FORBIDDEN_PATH_SEGMENTS = (
    ".agent-home",
    ".git-credentials",
    "id_ed25519",
    "id_rsa",
    "refresh_token",
)
ISOLATION = ("landlock", "seccomp", "no_new_privs", "cgroup")


def deny(rule, reason):
    return f"{rule}: {reason}"


def _bool_is_true(value):
    return value is True


def check_signature_required(report):
    version = report.get("version")
    if not isinstance(version, str) or version == "" or version == "latest":
        return deny("signature_required", "version must be a pinned release, not latest or empty")
    if report.get("checksum_only") is True:
        return deny("signature_required", "checksum-only verification is not a signature")
    if report.get("cosign") != "verified":
        return deny(
            "signature_required",
            f"cosign state {report.get('cosign')!r} is not verified",
        )
    signer = report.get("signer")
    if not isinstance(signer, str) or SIGNER_RE.match(signer) is None:
        return deny(
            "signature_required",
            "signer is not the jeryu-deploy release workflow on a git ref",
        )
    return None


def check_skipped_is_not_pass(report):
    if report.get("required") is not True:
        return deny("skipped_is_not_pass", "a required lane is the only admission")
    if report.get("result") != "pass":
        return deny(
            "skipped_is_not_pass",
            f"result {report.get('result')!r} is not pass",
        )
    collected = report.get("tests_collected")
    if isinstance(collected, bool) or not isinstance(collected, int) or collected < 1:
        return deny("skipped_is_not_pass", "a required pass collected no tests")
    return None


def check_degraded_is_not_enforced(report):
    if report.get("trust") != "untrusted":
        return deny("degraded_is_not_enforced", "this rule admits untrusted launches only")
    if report.get("launch") != "success":
        return deny("degraded_is_not_enforced", "launch status is not success under the full profile")
    missing = [name for name in ISOLATION if not _bool_is_true(report.get(name))]
    if missing:
        return deny(
            "degraded_is_not_enforced",
            "untrusted launch succeeded without " + ", ".join(missing),
        )
    return None


def _oid(report, field):
    value = report.get(field)
    if not isinstance(value, str) or OID_RE.match(value) is None:
        return None
    return value


def check_authorized_head_is_landed_head(report):
    authorized_head = _oid(report, "authorized_head")
    resolved_head = _oid(report, "resolved_head")
    authorized_base = _oid(report, "authorized_base")
    resolved_base = _oid(report, "resolved_base")
    if None in (authorized_head, resolved_head, authorized_base, resolved_base):
        return deny(
            "authorized_head_is_landed_head",
            "authorized and resolved head and base must be 40-hex commit ids",
        )
    if authorized_head != resolved_head:
        return deny(
            "authorized_head_is_landed_head",
            "resolved head is not the authorized head",
        )
    if authorized_base != resolved_base:
        return deny(
            "authorized_head_is_landed_head",
            "resolved base is not the authorized base",
        )
    return None


def check_ack_requires_durable_intent(report):
    if report.get("persist") != "durable":
        return deny("ack_requires_durable_intent", "persist did not durably succeed")
    if report.get("run_id_source") != "durable":
        return deny("ack_requires_durable_intent", "run id is not durable")
    if report.get("accepted_before_persist") is not False:
        return deny("ack_requires_durable_intent", "accept preceded a durable persist")
    return None


def check_repo_scope_required(report):
    if report.get("repo_status") != "known":
        return deny("repo_scope_required", "unknown repository is a denial")
    if report.get("decision") != "allow":
        return deny("repo_scope_required", "authorization must be an explicit allow")
    authorized = report.get("authorized_repo")
    scope = report.get("query_scope")
    if not isinstance(authorized, str) or authorized == "" or authorized != scope:
        return deny("repo_scope_required", "query scope is not the authorized repository")
    return None


def _string_list(value):
    if isinstance(value, list) and all(isinstance(item, str) for item in value):
        return value
    return None


def check_rustflags_order_preserved(report):
    pairs = report.get("pairs")
    if not isinstance(pairs, list) or not pairs:
        return deny("rustflags_order_preserved", "pairs must be a non-empty list")
    for index, pair in enumerate(pairs):
        if not isinstance(pair, dict):
            return deny("rustflags_order_preserved", f"pair {index} is not an object")
        left = pair.get("left")
        right = pair.get("right")
        if not isinstance(left, dict) or not isinstance(right, dict):
            return deny("rustflags_order_preserved", f"pair {index} is missing left and right")
        left_flags = _string_list(left.get("rustflags"))
        right_flags = _string_list(right.get("rustflags"))
        left_features = _string_list(left.get("features"))
        right_features = _string_list(right.get("features"))
        if None in (left_flags, right_flags, left_features, right_features):
            return deny("rustflags_order_preserved", f"pair {index} flags must be strings")
        flags_equal = tuple(left_flags) == tuple(right_flags)
        features_equal = tuple(sorted(set(left_features))) == tuple(sorted(set(right_features)))
        if pair.get("rustflags_key_equal") is not flags_equal:
            return deny(
                "rustflags_order_preserved",
                f"pair {index} rustflags equality does not preserve order and repetition",
            )
        if pair.get("features_key_equal") is not features_equal:
            return deny(
                "rustflags_order_preserved",
                f"pair {index} feature equality is not the sorted set",
            )
    return None


def check_simulation_is_not_evidence(report):
    author = report.get("author")
    if not isinstance(author, str) or author == "":
        return deny("simulation_is_not_evidence", "author is missing")
    evidence = report.get("evidence")
    if not isinstance(evidence, list) or not evidence:
        return deny("simulation_is_not_evidence", "evidence list is empty")
    required = []
    for item in evidence:
        if not isinstance(item, dict):
            return deny("simulation_is_not_evidence", "evidence item is not an object")
        if item.get("required") is True:
            required.append(item)
    if not required:
        return deny("simulation_is_not_evidence", "no required evidence item")
    for item in required:
        if item.get("state") != "verified":
            return deny(
                "simulation_is_not_evidence",
                f"state {item.get('state')!r} is not verified",
            )
        producer = item.get("producer")
        if not isinstance(producer, str) or producer == "" or producer == author:
            return deny(
                "simulation_is_not_evidence",
                "producer must be a different principal than the author",
            )
    return None


def check_credential_not_in_workspace(report):
    if report.get("symlink_follows_destination") is True:
        return deny("credential_not_in_workspace", "write follows a destination symlink")
    if report.get("token_in_log") is True:
        return deny("credential_not_in_workspace", "a token is present in a log")
    if report.get("token_in_capsule") is True:
        return deny("credential_not_in_workspace", "a token is present in a capsule")
    paths = report.get("paths")
    if not isinstance(paths, list):
        return deny("credential_not_in_workspace", "paths must be a list")
    for path in paths:
        if not isinstance(path, str):
            return deny("credential_not_in_workspace", "path is not a string")
        segments = path.replace("\\", "/").split("/")
        for segment in segments:
            if segment in FORBIDDEN_PATH_SEGMENTS:
                return deny(
                    "credential_not_in_workspace",
                    f"path contains credential segment {segment}",
                )
    return None


def check_claim_requires_ready(report):
    if report.get("prior_state") != "Ready":
        return deny("claim_requires_ready", "prior state is not Ready")
    if report.get("in_ready_queue") is not True:
        return deny("claim_requires_ready", "cell is not in the ready queue")
    if report.get("epoch_matches") is not True:
        return deny("claim_requires_ready", "epoch does not match")
    if report.get("already_claimed") is not False:
        return deny("claim_requires_ready", "cell is already claimed")
    return None


def check_family_lock_pins_oids(report):
    members = report.get("members")
    if not isinstance(members, dict) or not members:
        return deny("family_lock_pins_oids", "members must be a non-empty object")
    for name, oid in members.items():
        if not isinstance(name, str) or name == "":
            return deny("family_lock_pins_oids", "member name is empty")
        if not isinstance(oid, str) or OID_RE.match(oid) is None:
            return deny("family_lock_pins_oids", f"{name} is not a 40-hex commit id")
    return None


def check_remote_allowlist(report):
    remote = report.get("remote")
    if not isinstance(remote, str) or remote == "":
        return deny("remote_allowlist", "remote is missing")
    if remote[0] == "-" or "\n" in remote or "\r" in remote:
        return deny("remote_allowlist", "remote contains a dash-option or a newline")
    if not remote.startswith("https://"):
        return deny("remote_allowlist", "remote scheme is not https")
    if not remote.startswith(REMOTE_PREFIXES):
        return deny("remote_allowlist", "remote host is not an allowed neverhuman forge")
    return None


RULES = {
    "ack_requires_durable_intent": check_ack_requires_durable_intent,
    "authorized_head_is_landed_head": check_authorized_head_is_landed_head,
    "claim_requires_ready": check_claim_requires_ready,
    "credential_not_in_workspace": check_credential_not_in_workspace,
    "degraded_is_not_enforced": check_degraded_is_not_enforced,
    "family_lock_pins_oids": check_family_lock_pins_oids,
    "remote_allowlist": check_remote_allowlist,
    "repo_scope_required": check_repo_scope_required,
    "rustflags_order_preserved": check_rustflags_order_preserved,
    "signature_required": check_signature_required,
    "simulation_is_not_evidence": check_simulation_is_not_evidence,
    "skipped_is_not_pass": check_skipped_is_not_pass,
}


def evaluate(document):
    if not isinstance(document, dict):
        raise ValueError("fixture must be an object")
    rule = document.get("rule")
    if rule not in RULES:
        raise ValueError(f"unknown rule {rule!r}")
    report = document.get("report")
    if not isinstance(report, dict):
        raise ValueError("report must be an object")
    return RULES[rule](report)


def main(argv):
    if len(argv) == 2 and argv[1] == "rules":
        for name in RULES:
            print(name)
        return 0
    if len(argv) != 3 or argv[1] != "check":
        print("usage: qualify.py check <fixture.json> | qualify.py rules", file=sys.stderr)
        return 2
    path = Path(argv[2])
    try:
        document = json.loads(path.read_text(encoding="utf-8"))
        reason = evaluate(document)
    except (OSError, UnicodeError, json.JSONDecodeError, ValueError) as exc:
        print(f"qualify error: {exc}", file=sys.stderr)
        return 2
    if reason:
        print(reason, file=sys.stderr)
        return 1
    print(f"pass {document['rule']}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
