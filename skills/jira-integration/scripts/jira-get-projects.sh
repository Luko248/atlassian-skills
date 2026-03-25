#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# jira-get-projects.sh — List all accessible Jira projects
#
# Usage: jira-get-projects.sh
# ──────────────────────────────────────────────────────────────
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/load-env.sh"

if [[ -z "${JIRA_URL:-}" || -z "${JIRA_API_TOKEN:-}" ]]; then
  echo '{"error": "JIRA_URL and JIRA_API_TOKEN must be set in .env or environment"}' >&2
  exit 1
fi

CURL_OPTS=(-s -S --max-time 60 --connect-timeout 30)
if [[ "${VALIDATE_SSL:-true}" == "false" ]]; then
  CURL_OPTS+=(-k)
fi

URL="${JIRA_URL}/rest/api/2/project"

curl "${CURL_OPTS[@]}" \
  -H "Authorization: Bearer ${JIRA_API_TOKEN}" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  "$URL"
