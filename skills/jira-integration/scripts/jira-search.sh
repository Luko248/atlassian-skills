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

# Validate numeric parameters
if ! [[ "$MAX_RESULTS" =~ ^[0-9]+$ ]]; then
  echo '{"error": "MAX_RESULTS must be a positive integer"}' >&2
  exit 1
fi
if ! [[ "$START_AT" =~ ^[0-9]+$ ]]; then
  echo '{"error": "START_AT must be a non-negative integer"}' >&2
  exit 1
fi

# Clamp max results
if (( MAX_RESULTS < 1 )); then MAX_RESULTS=1; fi
if (( MAX_RESULTS > 1000 )); then MAX_RESULTS=1000; fi

_validate_url "JIRA_URL" "$JIRA_URL"
_validate_token "JIRA_API_TOKEN" "$JIRA_API_TOKEN"
_build_curl_opts

URL="${JIRA_URL}/rest/api/2/search"

# Build JSON payload safely via python3 (prevents injection via JQL string)
PAYLOAD=$(python3 -c "
import json, sys
jql = sys.stdin.read()
print(json.dumps({
    'jql': jql,
    'startAt': int(sys.argv[1]),
    'maxResults': int(sys.argv[2]),
    'fields': ['summary', 'status', 'assignee', 'reporter', 'priority', 'issuetype', 'created', 'updated', 'project']
}))
" "$START_AT" "$MAX_RESULTS" <<< "$JQL")

curl "${CURL_OPTS[@]}" \
  -X POST \
  -H "Authorization: Bearer ${JIRA_API_TOKEN}" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  "$URL"
