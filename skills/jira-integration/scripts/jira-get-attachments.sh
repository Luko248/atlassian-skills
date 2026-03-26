#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# jira-get-attachments.sh — Get attachment metadata for a Jira issue
#
# Usage: jira-get-attachments.sh <ISSUE_KEY>
# Example: jira-get-attachments.sh TEST-123
# ──────────────────────────────────────────────────────────────
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/load-env.sh"

ISSUE_KEY="${1:?Usage: jira-get-attachments.sh <ISSUE_KEY>}"

if [[ ! "$ISSUE_KEY" =~ ^[A-Za-z][A-Za-z0-9_]*-[0-9]+$ ]]; then
  echo '{"error": "Invalid issue key format. Expected: PROJECT-123"}' >&2
  exit 1
fi

if [[ -z "${JIRA_URL:-}" || -z "${JIRA_API_TOKEN:-}" ]]; then
  echo '{"error": "JIRA_URL and JIRA_API_TOKEN must be set in .env or environment"}' >&2
  exit 1
fi

_validate_url "JIRA_URL" "$JIRA_URL"
_validate_token "JIRA_API_TOKEN" "$JIRA_API_TOKEN"
_build_curl_opts

# Fetch only the attachment field
URL="${JIRA_URL}/rest/api/2/issue/${ISSUE_KEY}?fields=attachment"

curl "${CURL_OPTS[@]}" \
  -H "Authorization: Bearer ${JIRA_API_TOKEN}" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  "$URL"
