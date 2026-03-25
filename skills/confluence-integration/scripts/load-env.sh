#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# load-env.sh — Loads Jira/Confluence credentials from .env
#
# Cross-platform support: Linux, macOS, Windows (Git Bash, WSL, Cygwin)
#
# Search order (first readable file wins):
#   1. $HOME_DIR/.env                      (global)
#   2. $PROJECT_ROOT/.env                  (project-level)
#
# Exports: JIRA_URL, JIRA_USERNAME, JIRA_API_TOKEN,
#          CONFLUENCE_URL, CONFLUENCE_USERNAME, CONFLUENCE_API_TOKEN,
#          VALIDATE_SSL
# ──────────────────────────────────────────────────────────────
set -euo pipefail

_load_env_file() {
  local file="$1"
  if [[ ! -r "$file" ]]; then
    return 1
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip comments and empty lines
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

    # Match KEY=VALUE (with optional quotes)
    if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_.]*)=(.*)$ ]]; then
      local key="${BASH_REMATCH[1]}"
      local val="${BASH_REMATCH[2]}"

      # Strip surrounding quotes
      if [[ "$val" =~ ^\"(.*)\"$ ]]; then
        val="${BASH_REMATCH[1]}"
      elif [[ "$val" =~ ^\'(.*)\'$ ]]; then
        val="${BASH_REMATCH[1]}"
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
  HOME_DIR="$(_resolve_home)"
  PROJECT_ROOT="$(_project_root)"

  if [[ -z "$HOME_DIR" ]]; then
    echo "# ERROR: Cannot determine home directory. Set \$HOME or \$USERPROFILE." >&2
    echo "# Falling back to project-level .env only." >&2
    ENV_CANDIDATES=("$PROJECT_ROOT/.env")
  else
    ENV_CANDIDATES=(
      "$HOME_DIR/.env"
      "$PROJECT_ROOT/.env"
    )
  fi

  DOTENV_USED=""
  for candidate in "${ENV_CANDIDATES[@]}"; do
    if _load_env_file "$candidate"; then
      DOTENV_USED="$candidate"
      break
    fi
  done

  if [[ -n "$DOTENV_USED" ]]; then
    echo "# .env loaded from: $DOTENV_USED" >&2
  else
    echo "# ──────────────────────────────────────────────────────────────" >&2
    echo "# ERROR: No .env file found!" >&2
    echo "#" >&2
    echo "# Create a .env file in one of these locations:" >&2
    echo "#" >&2
    echo "#   Global:  ~/.env" >&2
    echo "#   Project: <project-root>/.env" >&2
    echo "#" >&2
    echo "# Or set credentials directly via environment variables." >&2
    echo "# ──────────────────────────────────────────────────────────────" >&2
  fi

  export _ENV_LOADED="true"
fi
