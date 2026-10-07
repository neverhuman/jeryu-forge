#!/usr/bin/env bash
# Reading the site's release configuration as data, fail-closed.
# Sourced by scripts/install.sh and scripts/clone-family.sh; exercised through
# them by tests/install-verify.sh and directly by tests/release-config.sh.
#
# The file names the trust anchors verification depends on, so it is parsed,
# never executed: each line is a comment, a blank, or KEY=VALUE for one of the
# keys below. Anything else refuses the run rather than being skipped. A value
# already set in the environment wins over the file, so a caller's own
# command line is never silently overridden by a dotfile.

JERYU_RELEASE_CONFIG_KEYS=(
  JERYU_RELEASE_BASE_URL
  JERYU_RELEASE_SIGNER_IDENTITY
  JERYU_RELEASE_OIDC_ISSUER
  JERYU_GIT_REMOTE_ALLOWLIST
  JERYU_FORGE_BASE
)

_jeryu_release_config_refuse() {
  printf 'refusing release configuration %s: %s\n' "$1" "$2" >&2
  return 1
}

# jeryu_release_config_path
#
# Prints the configuration path: JERYU_RELEASE_CONFIG when set, else
# ~/.config/jeryu/release.env, else nothing when HOME is unset or empty.
jeryu_release_config_path() {
  if [[ -n "${JERYU_RELEASE_CONFIG:-}" ]]; then
    printf '%s\n' "$JERYU_RELEASE_CONFIG"
  elif [[ -n "${HOME:-}" ]]; then
    printf '%s\n' "${HOME}/.config/jeryu/release.env"
  fi
}

# jeryu_load_release_config
#
# Exports the allowed keys the configuration file sets and the environment
# does not. A missing file is no configuration. A file that is not a regular
# file, is writable by group or others, is owned by another user, or holds a
# line that is not an allowed KEY=VALUE is refused.
jeryu_load_release_config() {
  local config line key value lineno=0 allowed known
  config="$(jeryu_release_config_path)"
  [[ -n "$config" && "$config" != /dev/null ]] || return 0
  [[ -e "$config" ]] || return 0
  if [[ ! -f "$config" || -L "$config" ]]; then
    _jeryu_release_config_refuse "$config" 'it is not a regular file'
    return 1
  fi
  if [[ ! -r "$config" ]]; then
    _jeryu_release_config_refuse "$config" 'it is not readable'
    return 1
  fi
  local owner mode
  owner="$(stat -c '%u' -- "$config")"
  mode="$(stat -c '%a' -- "$config")"
  if [[ "$owner" != "$(id -u)" && "$owner" != 0 ]]; then
    _jeryu_release_config_refuse "$config" "it is owned by uid ${owner}, not by you or root"
    return 1
  fi
  if (( (8#$mode & 8#022) != 0 )); then
    _jeryu_release_config_refuse "$config" "mode ${mode} lets others write it; chmod go-w it"
    return 1
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    lineno=$((lineno + 1))
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" || "$line" == \#* ]] && continue
    line="${line#export }"
    if [[ ! "$line" =~ ^([A-Z_][A-Z0-9_]*)=(.*)$ ]]; then
      _jeryu_release_config_refuse "$config" "line ${lineno} is not KEY=VALUE"
      return 1
    fi
    key="${BASH_REMATCH[1]}"
    value="${BASH_REMATCH[2]}"
    known=0
    for allowed in "${JERYU_RELEASE_CONFIG_KEYS[@]}"; do
      [[ "$key" == "$allowed" ]] && known=1
    done
    if [[ "$known" != 1 ]]; then
      _jeryu_release_config_refuse "$config" "line ${lineno} sets ${key}, which is not a release configuration key"
      return 1
    fi
    if [[ "$value" =~ ^\'(.*)\'$ || "$value" =~ ^\"(.*)\"$ ]]; then
      value="${BASH_REMATCH[1]}"
    fi
    if [[ "$value" == *[\$\`\'\"]* ]]; then
      _jeryu_release_config_refuse "$config" "line ${lineno} has quoting or expansion in ${key}; values are taken literally"
      return 1
    fi
    # The environment wins: only a key the caller left unset is taken from the file.
    if [[ -z "${!key+set}" ]]; then
      printf -v "$key" '%s' "$value"
      export "${key?}"
    fi
  done <"$config"
}
