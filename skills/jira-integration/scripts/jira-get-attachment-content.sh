#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# jira-get-attachment-content.sh — Download a Jira attachment
#
# Usage: jira-get-attachment-content.sh <ATTACHMENT_ID>
# Example: jira-get-attachment-content.sh 12345
#
# Returns: JSON with base64-encoded content and metadata
# Max size: 10 MB
# ──────────────────────────────────────────────────────────────
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/load-env.sh"

ATTACHMENT_ID="${1:?Usage: jira-get-attachment-content.sh <ATTACHMENT_ID>}"
MAX_SIZE=$((10 * 1024 * 1024))  # 10 MB

if [[ -z "${JIRA_URL:-}" || -z "${JIRA_API_TOKEN:-}" ]]; then
  echo '{"error": "JIRA_URL and JIRA_API_TOKEN must be set in .env or environment"}' >&2
  exit 1
fi

CURL_OPTS=(-s -S --max-time 60 --connect-timeout 30)
if [[ "${VALIDATE_SSL:-true}" == "false" ]]; then
  CURL_OPTS+=(-k)
fi

AUTH_HEADER="Authorization: Bearer ${JIRA_API_TOKEN}"

# Step 1: Get attachment metadata
META_URL="${JIRA_URL}/rest/api/2/attachment/${ATTACHMENT_ID}"
META=$(curl "${CURL_OPTS[@]}" \
  -H "$AUTH_HEADER" \
  -H "Accept: application/json" \
  "$META_URL")

# Extract content URL and size using python3
read -r CONTENT_URL FILE_SIZE FILENAME MIME_TYPE < <(
  echo "$META" | python3 -c "
import json, sys
m = json.load(sys.stdin)
print(m.get('content',''), m.get('size',0), m.get('filename',''), m.get('mimeType','application/octet-stream'))
" 2>/dev/null || echo "")

if [[ -z "$CONTENT_URL" ]]; then
  echo '{"error": "Could not resolve attachment content URL"}' >&2
  exit 1
fi

# Step 2: Check file size
if (( FILE_SIZE > MAX_SIZE )); then
  echo "{\"error\": \"Attachment too large (${FILE_SIZE} bytes, max ${MAX_SIZE})\"}" >&2
  exit 1
fi

# Step 3: Download and base64 encode
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

curl "${CURL_OPTS[@]}" \
  -H "$AUTH_HEADER" \
  -o "$TMPFILE" \
  "$CONTENT_URL"

B64=$(base64 < "$TMPFILE")

# Step 4: If image, try to get dimensions
DIMENSIONS=""
if [[ "$MIME_TYPE" == image/* ]] && command -v identify &>/dev/null; then
  DIMENSIONS=$(identify -format '{"width":%w,"height":%h}' "$TMPFILE" 2>/dev/null || echo "")
fi

# Step 5: Output JSON result
python3 -c "
import json, sys
result = {
    'attachmentId': '${ATTACHMENT_ID}',
    'filename': '${FILENAME}',
    'mimeType': '${MIME_TYPE}',
    'size': ${FILE_SIZE:-0},
    'contentBase64': sys.stdin.read().strip()
}
dims = '${DIMENSIONS}'
if dims:
    result['dimensions'] = json.loads(dims)
print(json.dumps(result, indent=2))
" <<< "$B64"
