#!/usr/bin/env bash
# Hermetic proof for the opt-in qualification kit. No network, install, or clone.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bash "${root}/docs/qualify/self-test.sh"

mkdir -p "${root}/target/tests"
cat >"${root}/target/tests/qualify-contract-receipt.json" <<'JSON'
{"schema_version":"jeryu.qualify.contract/v1","version":"jeryu-qualify-v1.0.0","conclusion":"pass","repair_hint":"bash tests/qualify-contract.sh"}
JSON
