#!/usr/bin/env bash
# Proof that scripts/install.sh installs only a signature-verified release.
# Every case runs the real installer; only curl and cosign are stand-ins, and
# every value below is invented.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

version="jeryu-v9.9.9-split.3"
release="${work}/published/${version}"
mkdir -p "$release"
printf '#!/usr/bin/env bash\nprintf %%s\\\\n "jeryu %s"\n' "$version" >"${release}/jeryu"
chmod 0755 "${release}/jeryu"
(cd "$release" && sha256sum jeryu >SHA256SUMS)
printf 'signature over jeryu\n' >"${release}/jeryu.sig"
printf 'certificate for jeryu\n' >"${release}/jeryu.pem"

# The same release published without its signature assets.
unsigned="${work}/unsigned/${version}"
mkdir -p "$unsigned"
cp "${release}/jeryu" "${release}/SHA256SUMS" "$unsigned"

# A stand-in curl that serves the published assets from disk, so an asset that
# was never published fails the way curl fails on a missing one.
stand_in="${work}/bin"
mkdir -p "$stand_in"
cat >"${stand_in}/curl" <<'CURL'
#!/usr/bin/env bash
set -euo pipefail
out=""
url=""
while (($#)); do
  case "$1" in
    -o) out="$2"; shift ;;
    -*) ;;
    *) url="$1" ;;
  esac
  shift
done
src="${JERYU_TEST_PUBLISHED}/${url##*/}"
[[ -f "$src" ]] || exit 22
cp "$src" "$out"
CURL

# A stand-in cosign that answers for one certificate identity only, the way
# verify-blob answers for the identity the certificate actually carries.
cat >"${stand_in}/cosign" <<'COSIGN'
#!/usr/bin/env bash
set -euo pipefail
asked=""
issuer=""
while (($#)); do
  case "$1" in
    --certificate-identity) asked="$2"; shift ;;
    --certificate-oidc-issuer) issuer="$2"; shift ;;
  esac
  shift
done
if [[ "${JERYU_TEST_COSIGN_STATE:-verified}" == "silent" ]]; then
  printf 'tlog entry found\n'
  exit 0
fi
if [[ "$issuer" != "${JERYU_TEST_CERT_ISSUER}" ]]; then
  printf 'no matching signatures: the certificate was issued by another issuer\n' >&2
  exit 1
fi
if [[ "$asked" != "${JERYU_TEST_CERT_IDENTITY}" ]]; then
  printf 'no matching signatures: none of the expected identities matched\n' >&2
  exit 1
fi
printf 'Verified OK\n'
COSIGN
chmod 0755 "${stand_in}/curl" "${stand_in}/cosign"

# The same PATH without cosign on it, for the checksum-only case.
no_cosign="${work}/bin-no-cosign"
mkdir -p "$no_cosign"
cp "${stand_in}/curl" "${no_cosign}/curl"

tag_identity="https://ci.example.invalid/jeryu-releases/.gitea/workflows/release.yml@refs/tags/${version}"
branch_identity="https://ci.example.invalid/jeryu-releases/.gitea/workflows/release.yml@refs/heads/main"

base_env=(
  "JERYU_TEST_PUBLISHED=${release}"
  "JERYU_TEST_CERT_IDENTITY=${tag_identity}"
  "JERYU_TEST_CERT_ISSUER=https://oidc.example.invalid"
  "JERYU_RELEASE_CONFIG=/dev/null"
  "JERYU_RELEASE_BASE_URL=https://releases.example.invalid/jeryu/{version}"
  "JERYU_RELEASE_SIGNER_IDENTITY=https://ci.example.invalid/jeryu-releases/.gitea/workflows/release.yml@refs/tags/{version}"
  "JERYU_RELEASE_OIDC_ISSUER=https://oidc.example.invalid"
  "JERYU_VERSION=${version}"
  "JERYU_TEST_STAND_IN=${stand_in}"
)

fail=0
checked=0
check() {
  local name="$1" expected="$2" actual="$3"
  checked=$((checked + 1))
  if [[ "$expected" == "$actual" ]]; then
    printf 'ok: %s\n' "$name"
  else
    printf 'not ok: %s (expected %s, got %s)\n' "$name" "$expected" "$actual" >&2
    fail=1
  fi
}

install_status=0
run_install() { # NAME [VAR=VALUE ...] — run the real installer into a fresh dir
  local name="$1"; shift
  local -a env_args=("${base_env[@]}" "$@")
  local dir="${work}/installed/${name}" stand
  stand="$stand_in"
  local assignment
  for assignment in "$@"; do
    [[ "$assignment" != JERYU_TEST_STAND_IN=* ]] || stand="${assignment#*=}"
  done
  install_status=0
  env "${env_args[@]}" "JERYU_INSTALL_DIR=${dir}" "PATH=${stand}:${PATH}" \
    bash "${root}/scripts/install.sh" >"${work}/${name}.out" 2>"${work}/${name}.err" \
    || install_status=$?
}

refuses() { # NAME DESCRIPTION [VAR=VALUE ...] — refuse, and install nothing
  local name="$1" what="$2"; shift 2
  run_install "$name" "$@"
  check "$what fails" 1 "$install_status"
  check "$what installs nothing" "" "$(ls -A "${work}/installed/${name}" 2>/dev/null)"
}

# A signature-verified release on its tag installs: every case below differs
# from this one in exactly one way.
run_install verified
check "verified release installs" 0 "$install_status"
check "installed binary is the release" "jeryu $version" "$("${work}/installed/verified/jeryu" --version)"

# 1. An unpinned version cannot be tied to a signature on a known tag.
refuses latest "version latest" "JERYU_VERSION=latest"
refuses padded-latest "version ' latest'" "JERYU_VERSION= latest"
refuses empty "an empty version" "JERYU_VERSION="
refuses blank "a whitespace-only version" "JERYU_VERSION=   "

# 2. Checksums say the download arrived intact, not who built it.
refuses no-cosign "an install with no cosign available" "JERYU_TEST_STAND_IN=${no_cosign}"
refuses unsigned "a release published without jeryu.sig" "JERYU_TEST_PUBLISHED=${unsigned}"

# 3. cosign ran, but reported no verified signature.
refuses unverified-state "a cosign state other than verified" "JERYU_TEST_COSIGN_STATE=silent"

# 4. The signer has to be the configured release identity, on this tag.
refuses other-signer "a signature from another signer" \
  "JERYU_TEST_CERT_IDENTITY=https://ci.example.invalid/someone-else/.gitea/workflows/release.yml@refs/tags/${version}"
refuses branch-signer "a signature made from a branch ref" \
  "JERYU_TEST_CERT_IDENTITY=${branch_identity}" \
  "JERYU_RELEASE_SIGNER_IDENTITY=${branch_identity}"

# The site values are configuration: with none of them set, nothing installs.
refuses unconfigured "an installer with no release configuration" \
  "JERYU_RELEASE_BASE_URL=" "JERYU_RELEASE_SIGNER_IDENTITY=" "JERYU_RELEASE_OIDC_ISSUER="

# 5. The download base has to be pinned to the tag, and the issuer has to be
# the configured https issuer the certificate carries.
refuses floating-base "a release base without {version}" \
  "JERYU_RELEASE_BASE_URL=https://releases.example.invalid/jeryu/latest/download"
refuses plain-issuer "a non-https OIDC issuer" "JERYU_RELEASE_OIDC_ISSUER=oidc.example.invalid"
refuses other-issuer "a certificate from another issuer" \
  "JERYU_TEST_CERT_ISSUER=https://other-oidc.example.invalid"

# 6. The verifier is cosign on PATH: no variable swaps in another program.
fake="${work}/fake-cosign"
printf '#!/usr/bin/env bash\nprintf "Verified OK\\n"\n' >"$fake"
chmod 0755 "$fake"
refuses swapped-cosign "a verifier named by JERYU_COSIGN" \
  "JERYU_TEST_STAND_IN=${no_cosign}" "JERYU_COSIGN=${fake}"

# 7. The site values can come from the configuration file, which is read as
# data: a line that is not KEY=VALUE refuses the install and never runs.
config="${work}/release.env"
printf 'JERYU_RELEASE_BASE_URL=https://releases.example.invalid/jeryu/{version}\n' >"$config"
chmod 0600 "$config"
run_install from-config "JERYU_RELEASE_CONFIG=${config}" "JERYU_RELEASE_BASE_URL="
check "an empty environment value wins over the file" 1 "$install_status"
install_status=0
env -u JERYU_RELEASE_BASE_URL "${base_env[@]/#JERYU_RELEASE_BASE_URL=*/JERYU_UNUSED=1}" \
  "JERYU_RELEASE_CONFIG=${config}" "JERYU_INSTALL_DIR=${work}/installed/from-config" \
  "PATH=${stand_in}:${PATH}" bash "${root}/scripts/install.sh" \
  >"${work}/from-config.out" 2>"${work}/from-config.err" || install_status=$?
check "a base url from the configuration file installs" 0 "$install_status"
marker="${work}/config-ran"
printf 'touch %s\n' "$marker" >"$config"
refuses executable-config "a configuration line that is a command" "JERYU_RELEASE_CONFIG=${config}"
check "a configuration line is never run" "no" "$([[ -e "$marker" ]] && echo yes || echo no)"

mkdir -p "${root}/target/tests"
conclusion=success
[[ "$fail" == "0" ]] || conclusion=failure
cat >"${root}/target/tests/install-verify-receipt.json" <<JSON
{"schema_version":"jeryu.install.verify-proof/v1","guard":"scripts/install.sh","assertions":${checked},"conclusion":"${conclusion}","repair_hint":"bash tests/install-verify.sh"}
JSON

if [[ "$fail" != "0" ]]; then
  printf 'tests/install-verify.sh failed\n' >&2
  exit 1
fi
printf 'install-verify ok\n'
