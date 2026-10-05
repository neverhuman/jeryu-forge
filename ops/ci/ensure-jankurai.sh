#!/usr/bin/env bash
# GENERATED Jankurai verifier. Installation is owned only by jeryu-tool.
set -euo pipefail

# BEGIN GENERATED JANKURAI PIN — DO NOT EDIT
# The governed Jankurai identity is the binary installed on this host and its
# installation receipt: require_jankurai verifies both and exports JERYU_JANKURAI_*
# from the receipt. The one pin of record is jeryu-tool's tool-manifest.toml.
# END GENERATED JANKURAI PIN

require_jankurai() {
  # Verify the governed Jankurai auditor installed on this host. The installed
  # binary and its content-addressed installation receipt are the identity:
  # nothing here is pinned per repository, and no network or credential is
  # needed. Keeping the install current is the host's job: its installer reads
  # the one pin of record (tool-manifest.toml on protected jeryu-tool main) and
  # leaves an authority stamp; a host whose install no longer matches its stamp
  # fails here instead of scoring with a stale auditor.
  local mode=receipt-bound
  local expected_broker="/opt/jain-ci/authority/release-bin/jankurai"
  local expected_governed="/home/ubuntu/.jeryu/bin/jankurai"
  local bin bin_dir governed_root normalized resolved actual actual_sha receipt receipt_digest receipt_sha
  local expected_test=false expected_verification=release-authoritative
  local expected_governance=governed expected_protected=true
  local expected_protection=immutable-main-v1 found_receipt=0
  local authority_sha="" authority_stamp
  local -a receipt_candidates=()
  if [[ "${JAIN_RELEASE_CI:-0}" == "1" ]]; then
    mode=release-broker
    resolved="$(type -P -- jankurai 2>/dev/null || true)"
    if [[ "${resolved}" != "${expected_broker}" ]]; then
      printf 'release broker Jankurai path mismatch: expected %s, resolved %s\n' \
        "${expected_broker}" "${resolved:-missing}" >&2
      exit 1
    fi
    bin="${resolved}"
  else
    bin="${JERYU_GOVERNED_JANKURAI_BIN:-${expected_governed}}"
  fi
  if [[ "${bin}" != /* || ! -f "${bin}" || -L "${bin}" || ! -x "${bin}" ]]; then
    printf 'governed jankurai must be an absolute executable regular file: %s\n' "${bin}" >&2
    exit 1
  fi
  normalized="$(realpath -m "${bin}")"
  if [[ "${normalized}" != "${bin}" ]]; then
    printf 'governed jankurai path traverses a symlink: %s -> %s\n' "${bin}" "${normalized}" >&2
    exit 1
  fi
  if [[ "${mode}" == "release-broker" &&
        "$(stat -c '%a:%h' -- "${bin}" 2>/dev/null || true)" != "555:1" ]]; then
    printf 'release broker Jankurai custody mismatch: expected mode 0555 and one link at %s\n' \
      "${bin}" >&2
    exit 1
  elif [[ "${mode}" != "release-broker" &&
          "$(stat -c '%h' -- "${bin}" 2>/dev/null || true)" != "1" ]]; then
    printf 'governed jankurai custody mismatch: expected one link at %s\n' \
      "${bin}" >&2
    exit 1
  fi
  if [[ "${mode}" != "release-broker" ]]; then
    bin_dir="$(dirname "${bin}")"
    export PATH="${bin_dir}:${PATH}"
    resolved="$(type -P -- jankurai 2>/dev/null || true)"
    if [[ "${resolved}" != "${bin}" ]]; then
      printf 'governed jankurai shadowed: expected %s, resolved %s\n' \
        "${bin}" "${resolved:-missing}" >&2
      exit 1
    fi
  fi
  actual="$("${bin}" --version 2>/dev/null || true)"
  actual_sha="$(sha256sum "${bin}" 2>/dev/null | awk '{print $1}')"
  if [[ ! "${actual}" =~ ^jankurai\ [0-9]+\.[0-9]+\.[0-9]+$ || ! "${actual_sha}" =~ ^[0-9a-f]{64}$ ]]; then
    printf 'governed jankurai identity is unreadable at %s: version=%s sha256=%s\n' \
      "${bin}" "${actual:-missing}" "${actual_sha:-missing}" >&2
    exit 1
  fi

  # Freshness. A release broker's binary carries no receipt, so its digest must
  # equal the `<broker>.sha256` record installed beside it with the same custody
  # (read-only, one link); no environment variable can stand in for it.
  # Ordinary hosts compare with the authority stamp their installer writes
  # (owner-only, beside the receipts); an explicit JERYU_JANKURAI_AUTHORITY_SHA256
  # is an extra assertion, never a way around a stamp. A diagnostic candidate
  # is by design not the pin.
  if [[ "${mode}" == "release-broker" ]]; then
    if [[ ! -f "${bin}.sha256" || -L "${bin}.sha256" ||
          "$(stat -c '%a:%h' -- "${bin}.sha256" 2>/dev/null || true)" != "444:1" ]]; then
      printf 'release broker Jankurai digest record custody mismatch: expected mode 0444 and one link at %s.sha256\n' "${bin}" >&2
      exit 1
    fi
    authority_sha="$(awk 'NR == 1 {print $1}' "${bin}.sha256")"
  elif [[ "${JERYU_JANKURAI_ALLOW_TEST_RECEIPT:-0}" != "1" ]]; then
    authority_stamp="$(dirname "$(dirname "${expected_governed}")")/authority/jankurai.json"
    if [[ "${bin}" == "${expected_governed}" && -f "${authority_stamp}" ]]; then
      authority_sha="$(jq -r '.binary_sha256 // empty' "${authority_stamp}" 2>/dev/null || true)"
      if [[ ! "${authority_sha}" =~ ^[0-9a-f]{64}$ ]]; then
        printf 'jankurai authority stamp is unreadable: %s\n' "${authority_stamp}" >&2
        exit 1
      fi
    fi
    if [[ -n "${JERYU_JANKURAI_AUTHORITY_SHA256:-}" && "${JERYU_JANKURAI_AUTHORITY_SHA256}" != "${actual_sha}" ]]; then
      printf 'governed jankurai at %s is sha256=%s but JERYU_JANKURAI_AUTHORITY_SHA256 names %s\n' \
        "${bin}" "${actual_sha}" "${JERYU_JANKURAI_AUTHORITY_SHA256}" >&2
      exit 1
    fi
  fi
  if [[ -n "${authority_sha}" && "${authority_sha}" != "${actual_sha}" ]]; then
    printf 'governed jankurai at %s is sha256=%s but the jeryu-tool pin names %s: the host has not installed the current pin (ops/install-jankurai.sh from protected jeryu-tool main)\n' \
      "${bin}" "${actual_sha}" "${authority_sha}" >&2
    exit 1
  fi

  export JERYU_GOVERNED_JANKURAI_BIN="${bin}"
  if [[ "${mode}" == "release-broker" ]]; then
    if [[ -n "${JERYU_JANKURAI_RECEIPT:-}" ||
          -n "${JERYU_JANKURAI_RECEIPT_SHA256:-}" ||
          "${JERYU_JANKURAI_ALLOW_TEST_RECEIPT:-0}" != "0" ]]; then
      printf 'release broker Jankurai rejects caller receipt authority\n' >&2
      exit 1
    fi
    found_receipt=1
  elif [[ "${JERYU_JANKURAI_ALLOW_TEST_RECEIPT:-0}" == "1" ]]; then
    expected_test=true
    expected_verification=diagnostic-candidate
    expected_governance=diagnostic-candidate
    expected_protected=false
    expected_protection=not-applicable
  fi
  if [[ "${mode}" == "release-broker" ]]; then
    receipt_candidates=()
  elif [[ -n "${JERYU_JANKURAI_RECEIPT:-}" ]]; then
    receipt_candidates=("${JERYU_JANKURAI_RECEIPT}")
  elif [[ "${bin}" == "${expected_governed}" ]]; then
    governed_root="$(dirname "$(dirname "${expected_governed}")")"
    receipt_candidates=("${governed_root}"/receipts/jankurai/sha256/*.json)
  else
    printf 'non-governed jankurai requires an explicit installation receipt: %s\n' \
      "${bin}" >&2
    exit 1
  fi
  for receipt in "${receipt_candidates[@]}"; do
    [[ -f "${receipt}" ]] || continue
    receipt_digest="$(basename "${receipt}" .json)"
    [[ "${receipt_digest}" =~ ^[0-9a-f]{64}$ ]] || continue
    receipt_sha="$(sha256sum "${receipt}" | awk '{print $1}')"
    [[ "${receipt_sha}" == "${receipt_digest}" ]] || continue
    # The receipt is self-certifying (its name is its own digest) and must bind
    # exactly this binary at exactly this path, built hermetically from a
    # governed, protected-main jeryu-tool manifest.
    if jq -e \
      --arg digest "${actual_sha}" \
      --arg version "${actual}" \
      --arg path "${bin}" \
      --arg verification "${expected_verification}" \
      --arg governance "${expected_governance}" \
      --arg protection "${expected_protection}" \
      --argjson protected_main "${expected_protected}" \
      --argjson test_mode "${expected_test}" \
      '.schema == "jeryu.jankurai-installation/v2" and
       (.source.remote | type == "string" and startswith("https://")) and
       (.source.commit | test("^[0-9a-f]{40}$")) and (.source.tree | test("^[0-9a-f]{40}$")) and
       (.source.tag | type == "string" and length > 0) and
       (.source.archive_sha256 | test("^[0-9a-f]{64}$")) and
       (.source.cargo_lock_sha256 | test("^[0-9a-f]{64}$")) and
       .source.verification == $verification and
       (.build.context_sha256 | test("^[0-9a-f]{64}$")) and
       (.build.builder_image | type == "string" and test("@sha256:[0-9a-f]{64}$")) and
       .build.cargo_net_offline == true and .build.closed_vendor == true and
       .build.network_none == true and .build.read_only_root == true and
       .build.non_root == true and .build.capabilities_dropped == true and
       .build.no_new_privileges == true and
       .build.container_engine_path == "/usr/bin/docker" and
       .build.git_global_config_disabled == true and .build.git_system_config_disabled == true and
       .build.git_http_follow_redirects == false and .build.git_terminal_prompt == false and
       .build.jankurai_update_check == false and
       .build.network_scope ==
         "local-forge-source-plus-closed-vendor-network-none" and
       .governance.status == $governance and
       .governance.manifest_repo ==
         "https://git.neverhuman.org/git/jeryu/jeryu-tool.git" and
       (.governance.manifest_commit | test("^[0-9a-f]{40}$")) and
       (.governance.manifest_tree | test("^[0-9a-f]{40}$")) and
       (.governance.manifest_sha256 | test("^[0-9a-f]{64}$")) and
       .governance.protected_main == $protected_main and
       .governance.protection_policy == $protection and
       .binary.sha256 == $digest and .binary.version_output == $version and
       .installation.path == $path and .installation.atomic == true and
       .test_mode == $test_mode and .conclusion == "success"' "${receipt}" >/dev/null; then
      export JERYU_JANKURAI_RECEIPT="${receipt}"
      export JERYU_JANKURAI_RECEIPT_SHA256="${receipt_digest}"
      found_receipt=1
      break
    fi
  done
  if [[ "${mode}" != "release-broker" && "${found_receipt}" -ne 1 ]]; then
    printf 'governed jankurai receipt mismatch: binary=%s sha256=%s test_mode=%s\n' \
      "${bin}" "${actual_sha}" "${expected_test}" >&2
    exit 1
  fi

  # The identity callers read (`JERYU_JANKURAI_*`) now comes from what is
  # installed: the verified receipt, or for a release broker the pin of record.
  if [[ -n "${JERYU_JANKURAI_RECEIPT:-}" && "${mode}" != "release-broker" ]]; then
    eval "$(jq -r '
      def q: @sh;
      "export JERYU_JANKURAI_SOURCE_REPO=\(.source.remote|q)",
      "export JERYU_JANKURAI_SOURCE_REV=\(.source.commit|q)",
      "export JERYU_JANKURAI_SOURCE_TAG=\(.source.tag|q)",
      "export JERYU_JANKURAI_SOURCE_TREE=\(.source.tree|q)",
      "export JERYU_JANKURAI_SOURCE_ARCHIVE_SHA256=\(.source.archive_sha256|q)",
      "export JERYU_JANKURAI_CARGO_LOCK_SHA256=\(.source.cargo_lock_sha256|q)",
      "export JERYU_JANKURAI_RUSTC_VERSION=\(.build.rustc|q)",
      "export JERYU_JANKURAI_RUST_TOOLCHAIN=\(.build.rustc | capture("^rustc (?<v>[0-9]+\\.[0-9]+\\.[0-9]+)").v | q)",
      "export JERYU_JANKURAI_CARGO_VERSION=\(.build.cargo|q)",
      "export JERYU_JANKURAI_TARGET_TRIPLE=\(.build.target_triple|q)",
      "export JERYU_JANKURAI_BUILD_MODE=\(.build.mode|q)",
      "export JERYU_JANKURAI_PACKAGE_PATH=\(.build.package_path|q)",
      "export JERYU_JANKURAI_BUILDER_IMAGE=\(.build.builder_image|q)",
      "export JERYU_JANKURAI_BUILDER_IMAGE_ID=\(.build.builder_image_id|q)",
      "export JERYU_JANKURAI_LINKER_VERSION=\(.build.linker|q)",
      "export JERYU_JANKURAI_GLIBC_VERSION=\(.build.glibc|q)",
      "export JERYU_JANKURAI_VENDOR_FILES_SHA256=\(.build.vendor_files_sha256|q)",
      "export JERYU_JANKURAI_VENDOR_FILE_COUNT=\(.build.vendor_file_count|q)",
      "export JERYU_JANKURAI_CARGO_CONFIG_SHA256=\(.build.cargo_config_sha256|q)",
      "export JERYU_JANKURAI_BUILD_ENVIRONMENT=\(.build.environment|q)",
      "export JERYU_JANKURAI_RUSTFLAGS=\(.build.rustflags|q)",
      "export JERYU_JANKURAI_BUILD_COMMAND=\(.build.command|q)",
      "export JERYU_JANKURAI_BUILD_CONTEXT_SHA256=\(.build.context_sha256|q)"
    ' "${JERYU_JANKURAI_RECEIPT}")"
  fi
  export JERYU_JANKURAI_VERSION="${actual}" JERYU_JANKURAI_SHA256="${actual_sha}"
  export JERYU_JANKURAI_SEMVER="${actual#jankurai }"
  export JANKURAI_NO_UPDATE_CHECK=1 GIT_TERMINAL_PROMPT=0
}

require_jankurai
printf 'governed jankurai ok: %s sha256=%s at %s\n' \
  "${JERYU_JANKURAI_VERSION}" "${JERYU_JANKURAI_SHA256}" "${JERYU_GOVERNED_JANKURAI_BIN}"
