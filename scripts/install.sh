#!/usr/bin/env bash
set -euo pipefail

lib="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib"
# shellcheck source=lib/install-target.sh
source "${lib}/install-target.sh"
# shellcheck source=lib/release-verify.sh
source "${lib}/release-verify.sh"

# Site values (where releases come from, who may sign them, which issuer
# vouches for that signer) live in configuration, not here.
config="${JERYU_RELEASE_CONFIG:-${HOME}/.config/jeryu/release.env}"
if [[ -r "$config" ]]; then
  # shellcheck disable=SC1090 # a site's own configuration, read at install time
  source "$config"
fi

version="$(jeryu_release_version "${JERYU_VERSION-}")"
base="$(jeryu_release_base_url "$version")"
install_dir="${JERYU_INSTALL_DIR:-${HOME}/.jeryu/bin}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

download() {
  local name="$1"
  curl -fL --retry 3 --retry-delay 2 -o "${tmp}/${name}" "${base}/${name}"
}

download jeryu
download SHA256SUMS
# A release missing its signature assets is refused by the verification below,
# which says why, rather than here by curl's exit status.
download jeryu.sig || :
download jeryu.pem || :

(
  cd "$tmp"
  grep -Eq '([[:space:]]|\*)jeryu$' SHA256SUMS || {
    printf 'SHA256SUMS does not contain a jeryu entry\n' >&2
    exit 1
  }
  sha256sum --check --ignore-missing SHA256SUMS
)

jeryu_verify_release "${tmp}/jeryu" "${tmp}/jeryu.sig" "${tmp}/jeryu.pem" "$version"

chmod 0755 "${tmp}/jeryu"
install_jeryu_binary "${tmp}/jeryu" "$install_dir"
printf 'installed jeryu %s to %s\n' "$version" "${install_dir}/jeryu"
