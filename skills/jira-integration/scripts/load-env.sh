#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# load-env.sh — Loads Jira/Confluence credentials from .env
#
# Cross-platform support: Linux, macOS, Windows (Git Bash, WSL, Cygwin)
#
# Search order (first readable file wins):
#   1. $HOME_DIR/.env                      (system / user home — preferred)
#   2. $PROJECT_ROOT/.env                  (project-level — fallback)
#
# Before searching, the loader detects the host OS and prints a short
# notice so the user sees where the credentials are expected to live:
#
#   # Detected OS: macOS — looking for system-level .env at /Users/<user>/.env
#   # Hey — no .env at the system level. Falling back to the project root…
#   # .env loaded from: /path/to/project/.env
#
# Exports: JIRA_URL, JIRA_USERNAME, JIRA_API_TOKEN,
#          CONFLUENCE_URL, CONFLUENCE_USERNAME, CONFLUENCE_API_TOKEN,
#          VALIDATE_SSL, _DETECTED_OS
# ──────────────────────────────────────────────────────────────
set -euo pipefail

# Detect host OS first so every subsequent message can reference it.
# Values: "macOS", "Linux", "Windows", "Unknown"
_detect_os() {
  local uname_s
  uname_s="$(uname -s 2>/dev/null || echo Unknown)"
  case "$uname_s" in
    Darwin)                   echo "macOS"   ;;
    Linux)                    echo "Linux"   ;;
    MINGW*|MSYS*|CYGWIN*)     echo "Windows" ;;
    *)                        echo "Unknown" ;;
  esac
}

# Allowlist of environment variable names this loader will set
readonly _ALLOWED_ENV_KEYS="JIRA_URL JIRA_USERNAME JIRA_API_TOKEN CONFLUENCE_URL CONFLUENCE_USERNAME CONFLUENCE_API_TOKEN VALIDATE_SSL"

_is_allowed_key() {
  local key="$1"
  local allowed
  for allowed in $_ALLOWED_ENV_KEYS; do
    [[ "$key" == "$allowed" ]] && return 0
  done
  return 1
}

_load_env_file() {
  local file="$1"
  if [[ ! -r "$file" ]]; then
    return 1
  fi

  # Warn if .env is world-readable (skip on Windows where stat behaves differently)
  if command -v stat &>/dev/null && [[ "${_DETECTED_OS:-}" != "Windows" ]]; then
    local perms
    if [[ "${_DETECTED_OS:-}" == "macOS" ]]; then
      perms=$(stat -f '%Lp' "$file" 2>/dev/null || echo "")
    else
      perms=$(stat -c '%a' "$file" 2>/dev/null || echo "")
    fi
    if [[ -n "$perms" ]]; then
      local other_read=$(( perms % 10 ))
      if (( other_read >= 4 )); then
        echo "# WARNING: $file is world-readable (mode $perms). Run: chmod 600 $file" >&2
      fi
    fi
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip comments and empty lines
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

    # Match KEY=VALUE (with optional quotes)
    if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
      local key="${BASH_REMATCH[1]}"
      local val="${BASH_REMATCH[2]}"

      # Only load allowlisted keys
      if ! _is_allowed_key "$key"; then
        continue
      fi

      # Strip surrounding quotes
      if [[ "$val" =~ ^\"(.*)\"$ ]]; then
        val="${BASH_REMATCH[1]}"
      elif [[ "$val" =~ ^\'(.*)\'$ ]]; then
        val="${BASH_REMATCH[1]}"
      fi

      # Reject values containing control characters (prevent header injection)
      if [[ "$val" =~ [[:cntrl:]] ]]; then
        echo "# WARNING: Skipping $key — value contains control characters" >&2
        continue
      fi

      # Only set if not already in environment (real env wins)
      if [[ -z "${!key:-}" ]]; then
        export "$key=$val"
      fi
    fi
  done < "$file"

  return 0
}

# Determine project root (git root or cwd)
_project_root() {
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

# Resolve home directory cross-platform
_resolve_home() {
  if [[ -n "${HOME:-}" ]]; then
    echo "$HOME"
  elif [[ -n "${USERPROFILE:-}" ]]; then
    echo "${USERPROFILE//\\//}"
  else
    echo ""
  fi
}

_ENV_LOADED="${_ENV_LOADED:-false}"
if [[ "$_ENV_LOADED" != "true" ]]; then
  _DETECTED_OS="$(_detect_os)"
  export _DETECTED_OS

  HOME_DIR="$(_resolve_home)"
  PROJECT_ROOT="$(_project_root)"

  # Announce detected OS + where the system-level .env is expected.
  if [[ -n "$HOME_DIR" ]]; then
    echo "# Detected OS: ${_DETECTED_OS} — looking for system-level .env at ${HOME_DIR}/.env" >&2
  else
    echo "# Detected OS: ${_DETECTED_OS} — could not resolve home directory (set \$HOME or \$USERPROFILE)" >&2
  fi

  # Try system-level first, then project-level. This keeps a single source
  # of truth on a developer's machine (the home dir) while still allowing a
  # per-project override when the user hasn't set a global credential file.
  DOTENV_USED=""
  SYSTEM_ENV=""
  PROJECT_ENV="$PROJECT_ROOT/.env"

  if [[ -n "$HOME_DIR" ]]; then
    SYSTEM_ENV="$HOME_DIR/.env"
    if _load_env_file "$SYSTEM_ENV"; then
      DOTENV_USED="$SYSTEM_ENV"
    else
      echo "# Hey — no .env at the system level (${SYSTEM_ENV}). Let's look in your project instead…" >&2
    fi
  fi

  if [[ -z "$DOTENV_USED" ]] && _load_env_file "$PROJECT_ENV"; then
    DOTENV_USED="$PROJECT_ENV"
  fi

  if [[ -n "$DOTENV_USED" ]]; then
    echo "# .env loaded from: $DOTENV_USED" >&2
  else
    echo "# ──────────────────────────────────────────────────────────────" >&2
    echo "# ERROR: No .env file found!" >&2
    echo "#" >&2
    echo "# Detected OS: ${_DETECTED_OS}" >&2
    echo "#" >&2
    echo "# Create a .env file in one of these locations (checked in order):" >&2
    echo "#" >&2
    if [[ -n "$SYSTEM_ENV" ]]; then
      echo "#   1. System / user home:  $SYSTEM_ENV" >&2
    else
      echo "#   1. System / user home:  ~/.env (home directory could not be resolved)" >&2
    fi
    echo "#   2. Project root:        $PROJECT_ENV" >&2
    echo "#" >&2
    echo "# Or set credentials directly via environment variables." >&2
    echo "# ──────────────────────────────────────────────────────────────" >&2
  fi

  export _ENV_LOADED="true"
fi

# Validate that URL values look like URLs (no shell metacharacters)
_validate_url() {
  local name="$1" val="$2"
  local url_pattern='^https?://[a-zA-Z0-9._:@/%?&=+-]+$'
  if [[ ! "$val" =~ $url_pattern ]]; then
    echo "{\"error\": \"$name contains invalid characters — must be a valid HTTP(S) URL\"}" >&2
    exit 1
  fi
}

# Validate that token values contain no control characters or whitespace
_validate_token() {
  local name="$1" val="$2"
  if [[ "$val" =~ [[:cntrl:]] || "$val" =~ [[:space:]] ]]; then
    echo "{\"error\": \"$name contains invalid characters (control chars or whitespace)\"}" >&2
    exit 1
  fi
}

# Build common curl options with security defaults
_build_curl_opts() {
  CURL_OPTS=(-s -S --max-time 30 --connect-timeout 10 --max-redirs 3 --max-filesize 52428800 --proto =https --proto-redir =https)
  if [[ "${VALIDATE_SSL:-true}" == "false" ]]; then
    CURL_OPTS+=(-k)
  fi
}

# Detect a usable Python 3 interpreter. Sets the PYTHON_BIN array so callers
# can invoke Python consistently via "${PYTHON_BIN[@]}" -S -E -c '...'.
#
# On Windows `python` / `python3` commonly resolve to the Microsoft Store
# "App Execution Alias" stub — a shim that exits with "Python was not found"
# even when a real interpreter is installed and on PATH. The shim wins because
# `C:\Users\<user>\AppData\Local\Microsoft\WindowsApps` is typically ahead of
# `C:\Program Files\Python3xx\` in PATH. To dodge it we prefer the Python
# Launcher `py -3`, which is installed by the official Python MSI and is not
# affected by the alias.
_require_python() {
  if [[ -n "${PYTHON_BIN+x}" ]] && (( ${#PYTHON_BIN[@]} > 0 )); then
    return 0
  fi

  if [[ "${_DETECTED_OS:-}" == "Windows" ]] \
     && command -v py >/dev/null 2>&1 \
     && py -3 --version >/dev/null 2>&1; then
    PYTHON_BIN=(py -3)
    return 0
  fi

  if command -v python3 >/dev/null 2>&1 && python3 --version >/dev/null 2>&1; then
    PYTHON_BIN=(python3)
    return 0
  fi

  if command -v python >/dev/null 2>&1 \
     && python -c 'import sys; sys.exit(0 if sys.version_info[0] >= 3 else 1)' >/dev/null 2>&1; then
    PYTHON_BIN=(python)
    return 0
  fi

  echo '{"error": "Python 3 not found. Install Python 3 and make sure `py -3` (Windows), `python3`, or `python` is on PATH. On Windows, disable the Microsoft Store App Execution Alias for python.exe/python3.exe if the shim is shadowing your install."}' >&2
  exit 1
}
