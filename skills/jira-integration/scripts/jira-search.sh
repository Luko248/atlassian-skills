#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# jira-search.sh — Search Jira issues using JQL
#
# Usage: jira-search.sh <JQL> [MAX_RESULTS] [START_AT]
# Example: jira-search.sh "project = TEST AND status = Open" 50 0
#
# MAX_RESULTS: 1-1000, default 50
# START_AT: pagination offset, default 0
# ──────────────────────────────────────────────────────────────
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/load-env.sh"

JQL="${1:?Usage: jira-search.sh <JQL> [MAX_RESULTS] [START_AT]}"
MAX_RESULTS="${2:-50}"
START_AT="${3:-0}"

if [[ -z "${JIRA_URL:-}" || -z "${JIRA_API_TOKEN:-}" ]]; then
  echo '{"error": "JIRA_URL and JIRA_API_TOKEN must be set in .env or environment"}' >&2
  exit 1
fi

# Clamp max results
if (( MAX_RESULTS < 1 )); then MAX_RESULTS=1; fi
if (( MAX_RESULTS > 1000 )); then MAX_RESULTS=1000; fi

CURL_OPTS=(-s -S --max-time 60 --connect-timeout 30)
if [[ "${VALIDATE_SSL:-true}" == "false" ]]; then
  CURL_OPTS+=(-k)
fi

URL="${JIRA_URL}/rest/api/2/search"

# Use POST to avoid URL length limits with complex JQL
PAYLOAD=$(cat <<EOF
{
  "jql": $(printf '%s' "$JQL" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'),
  "startAt": ${START_AT},
  "maxResults": ${MAX_RESULTS},
  "fields": ["summary", "status", "assignee", "reporter", "priority", "issuetype", "created", "updated", "project"]
}
EOF
)

curl "${CURL_OPTS[@]}" \
  -X POST \
  -H "Authorization: Bearer ${JIRA_API_TOKEN}" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  "$URL"
