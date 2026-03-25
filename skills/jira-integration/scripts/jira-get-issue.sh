#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# jira-get-issue.sh — Fetch a Jira issue (summary + description)
#
# Usage: jira-get-issue.sh <ISSUE_KEY>
# Example: jira-get-issue.sh TEST-123
# ──────────────────────────────────────────────────────────────
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/load-env.sh"

ISSUE_KEY="${1:?Usage: jira-get-issue.sh <ISSUE_KEY>}"

if [[ -z "${JIRA_URL:-}" || -z "${JIRA_API_TOKEN:-}" ]]; then
  echo '{"error": "JIRA_URL and JIRA_API_TOKEN must be set in .env or environment"}' >&2
  exit 1
fi

CURL_OPTS=(-s -S --max-time 60 --connect-timeout 30)
if [[ "${VALIDATE_SSL:-true}" == "false" ]]; then
  CURL_OPTS+=(-k)
fi

URL="${JIRA_URL}/rest/api/2/issue/${ISSUE_KEY}?fields=summary,description"

curl "${CURL_OPTS[@]}" \
  -H "Authorization: Bearer ${JIRA_API_TOKEN}" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  "$URL"
