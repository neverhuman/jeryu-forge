#!/usr/bin/env bash
# Deciding whether a published jeryu release may be installed, fail-closed.
# Sourced by scripts/install.sh; exercised through it by tests/install-verify.sh.
#
# A checksum says the download arrived intact; it says nothing about who built
# it. Only a cosign signature made by the configured release identity, on this
# version's tag, is accepted here.
#
# Site values — the download base and the signer identity and OIDC issuer the
# signature must carry — are configuration, so this file carries no defaults
# for them: unset means refuse, never "install from wherever".

# jeryu_release_version <raw-version>
#
# Prints the release tag to install. Refuses an empty or whitespace-only
# version, and `latest`: a moving target cannot be tied to a signature on a
# known tag, so whatever is published under it would install unverified.
jeryu_release_version() {
  local raw="${1-}" version
  version="${raw#"${raw%%[![:space:]]*}"}"
  version="${version%"${version##*[![:space:]]}"}"

  if [[ -z "$version" ]]; then
    printf 'JERYU_VERSION is empty; set it to the release tag to install\n' >&2
    return 1
  fi
  if [[ "${version,,}" == "latest" ]]; then
    printf 'JERYU_VERSION=%s does not name a tag; a signature is only accepted on a release tag, so pin the version\n' "$raw" >&2
    return 1
  fi
  if [[ ! "$version" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
    printf 'JERYU_VERSION=%s is not a release tag name\n' "$raw" >&2
    return 1
  fi
  printf '%s\n' "$version"
}

# jeryu_release_base_url <version>
#
# Prints the https base the release assets are downloaded from, from
# JERYU_RELEASE_BASE_URL with {version} substituted. The template has to name
# {version}: a base that does not is a floating location, and the installer
# would report a pinned tag for whatever it served.
jeryu_release_base_url() {
  local version="$1" template="${JERYU_RELEASE_BASE_URL:-}" url
  if [[ -z "$template" ]]; then
    printf 'JERYU_RELEASE_BASE_URL is not configured; nothing says where releases come from\n' >&2
    return 1
  fi
  if [[ "$template" != *"{version}"* ]]; then
    printf 'JERYU_RELEASE_BASE_URL=%s does not contain {version}; a release base has to be pinned to the tag\n' "$template" >&2
    return 1
  fi
  url="${template//\{version\}/$version}"
  if [[ "$url" != https://* ]]; then
    printf 'JERYU_RELEASE_BASE_URL must be an https url, got %s\n' "$url" >&2
    return 1
  fi
  printf '%s\n' "${url%/}"
}

# jeryu_release_signer_identity <version>
#
# Prints the certificate identity a release signature must carry, from
# JERYU_RELEASE_SIGNER_IDENTITY with {version} substituted. The identity has to
# end at this version's tag ref: an identity pointing at a branch describes a
# signature anyone with push access to that branch can produce, which is not a
# release signature.
jeryu_release_signer_identity() {
  local version="$1" template="${JERYU_RELEASE_SIGNER_IDENTITY:-}" identity
  if [[ -z "$template" ]]; then
    printf 'JERYU_RELEASE_SIGNER_IDENTITY is not configured; nothing says who may sign a release\n' >&2
    return 1
  fi
  identity="${template//\{version\}/$version}"
  if [[ "$identity" != *"@refs/tags/${version}" ]]; then
    printf 'signer identity %s is not the release identity for refs/tags/%s; refusing a signature made from another ref\n' "$identity" "$version" >&2
    return 1
  fi
  printf '%s\n' "$identity"
}

# jeryu_verify_release <binary> <signature> <certificate> <version>
#
# Verifies the downloaded binary, or returns non-zero. cosign is asked for one
# exact identity and issuer, and its answer has to be a verified signature:
# a missing cosign, a missing signature asset, a non-zero cosign, and a cosign
# that ran without reporting a verified signature are all refusals.
jeryu_verify_release() {
  local bin="$1" sig="$2" cert="$3" version="$4"
  local cosign=cosign
  local issuer="${JERYU_RELEASE_OIDC_ISSUER:-}"
  local identity asset output

  if [[ -z "$issuer" ]]; then
    printf 'JERYU_RELEASE_OIDC_ISSUER is not configured; nothing says which issuer may vouch for a signer\n' >&2
    return 1
  fi
  if [[ "$issuer" != https://* ]]; then
    printf 'JERYU_RELEASE_OIDC_ISSUER must be an https url, got %s\n' "$issuer" >&2
    return 1
  fi
  identity="$(jeryu_release_signer_identity "$version")" || return 1

  if ! command -v "$cosign" >/dev/null 2>&1; then
    printf '%s is not available, so the signature cannot be checked; SHA256SUMS alone does not say who built %s\n' "$cosign" "$version" >&2
    return 1
  fi
  for asset in "$sig" "$cert"; do
    if [[ ! -s "$asset" ]]; then
      printf 'release asset %s is missing or empty; %s is not signature-verified\n' "$asset" "$version" >&2
      return 1
    fi
  done

  if ! output="$("$cosign" verify-blob \
    --signature "$sig" \
    --certificate "$cert" \
    --certificate-identity "$identity" \
    --certificate-oidc-issuer "$issuer" \
    "$bin" 2>&1)"; then
    [[ -z "$output" ]] || printf '%s\n' "$output" >&2
    printf 'cosign did not verify %s as signed by %s; refusing\n' "$bin" "$identity" >&2
    return 1
  fi
  if ! grep -Fqx 'Verified OK' <<<"$output"; then
    [[ -z "$output" ]] || printf '%s\n' "$output" >&2
    printf 'cosign reported no verified signature for %s; refusing\n' "$bin" >&2
    return 1
  fi
  printf 'verified %s as signed by %s\n' "$bin" "$identity"
}
