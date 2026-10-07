#!/usr/bin/env bash
# Deciding which git remotes may be cloned or fetched, fail-closed.
# Sourced by scripts/clone-family.sh; exercised directly by tests/git-remote.sh.
#
# A remote is a command line and a network destination at once, so a prefix
# match on "https://" says too little: git reads a leading dash as an option,
# a host that merely begins with an allowed one is a different host, and a path
# that walks up through ".." names a different repository. Every remote is
# parsed here and then matched, whole, against the host and first path segment
# the site allows.
#
# The allowlist is site configuration (JERYU_GIT_REMOTE_ALLOWLIST, entries
# `host/first-path-segment` separated by whitespace or commas), so this file
# carries no default for it: unset means refuse, never "clone from wherever".

# jeryu_git_remote_allowlist
#
# Prints the configured `host/segment` entries, one per line. Refuses when
# nothing is configured.
jeryu_git_remote_allowlist() {
  local raw="${JERYU_GIT_REMOTE_ALLOWLIST:-}"
  if [[ -z "${raw//[[:space:],]/}" ]]; then
    printf 'JERYU_GIT_REMOTE_ALLOWLIST is not configured; nothing says which remotes may be cloned\n' >&2
    return 1
  fi
  printf '%s\n' "${raw//,/ }" | tr -s '[:space:]' '\n' | sed '/^$/d'
}

_jeryu_git_remote_refuse() {
  printf 'refusing git remote %s: %s\n' "${1:-(empty)}" "$2" >&2
  return 1
}

# jeryu_check_git_remote <url>
#
# Returns zero when <url> may be handed to `git clone` or `git fetch`, and
# otherwise says which rule it broke.
jeryu_check_git_remote() {
  local url="${1-}" rest host path first segment entry allowed
  [[ -n "$url" ]] || { _jeryu_git_remote_refuse "$url" "it is empty"; return 1; }
  if [[ "$url" == -* ]]; then
    _jeryu_git_remote_refuse "$url" "it starts with a dash, which git reads as an option, not a remote"
    return 1
  fi
  if [[ "$url" =~ [[:cntrl:]] ]]; then
    _jeryu_git_remote_refuse "$url" "it holds a control character (newline, carriage return, tab or NUL)"
    return 1
  fi
  if [[ "${url:0:8}" != "https://" ]]; then
    _jeryu_git_remote_refuse "$url" "only https remotes are fetched, so neither ssh nor http nor a local scheme is one"
    return 1
  fi

  rest="${url:8}"
  if [[ "$rest" != */* ]]; then
    _jeryu_git_remote_refuse "$url" "it names no repository path under its host"
    return 1
  fi
  host="${rest%%/*}"
  path="${rest#*/}"

  if [[ "$host" == *@* ]]; then
    _jeryu_git_remote_refuse "$url" "it carries userinfo before the host, which hides which host is reached"
    return 1
  fi
  if [[ "$host" == *:* ]]; then
    _jeryu_git_remote_refuse "$url" "it names an explicit port, and only the default https port is fetched"
    return 1
  fi
  if [[ ! "$host" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]]; then
    _jeryu_git_remote_refuse "$url" "its host is not a plain hostname"
    return 1
  fi
  if [[ "$path" == *%* ]]; then
    _jeryu_git_remote_refuse "$url" "its path is percent-encoded, which can spell a dot segment git would walk"
    return 1
  fi

  first=""
  while IFS= read -r segment; do
    if [[ -z "$segment" ]]; then
      _jeryu_git_remote_refuse "$url" "its path holds an empty segment"
      return 1
    fi
    if [[ "$segment" == "." || "$segment" == ".." ]]; then
      _jeryu_git_remote_refuse "$url" "its path holds a dot segment, so it does not name the repository it reads as"
      return 1
    fi
    if [[ ! "$segment" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
      _jeryu_git_remote_refuse "$url" "its path segment ${segment} is not a repository path component"
      return 1
    fi
    [[ -n "$first" ]] || first="$segment"
  done < <(printf '%s\n' "${path//\//$'\n'}")

  entry="${host}/${first}"
  allowed="$(jeryu_git_remote_allowlist)" || return 1
  if ! grep -Fqx -- "$entry" <<<"$allowed"; then
    _jeryu_git_remote_refuse "$url" "${entry} is not in JERYU_GIT_REMOTE_ALLOWLIST"
    return 1
  fi
}
