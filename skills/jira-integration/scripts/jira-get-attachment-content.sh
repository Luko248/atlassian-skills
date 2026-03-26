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

# Validate attachment ID is numeric
if ! [[ "$ATTACHMENT_ID" =~ ^[0-9]+$ ]]; then
  echo '{"error": "ATTACHMENT_ID must be a numeric value"}' >&2
  exit 1
fi

if [[ -z "${JIRA_URL:-}" || -z "${JIRA_API_TOKEN:-}" ]]; then
  echo '{"error": "JIRA_URL and JIRA_API_TOKEN must be set in .env or environment"}' >&2
  exit 1
fi

_validate_url "JIRA_URL" "$JIRA_URL"
_validate_token "JIRA_API_TOKEN" "$JIRA_API_TOKEN"
_build_curl_opts

# Step 1: Get attachment metadata
META_URL="${JIRA_URL}/rest/api/2/attachment/${ATTACHMENT_ID}"
META=$(curl "${CURL_OPTS[@]}" \
  -H "Authorization: Bearer ${JIRA_API_TOKEN}" \
  -H "Accept: application/json" \
  "$META_URL")

# Extract metadata safely via python3 (no shell interpolation)
META_PARSED=$(python3 -c "
import json, sys
try:
    m = json.load(sys.stdin)
    content_url = m.get('content', '')
    size = int(m.get('size', 0))
    filename = m.get('filename', '')
    mime_type = m.get('mimeType', 'application/octet-stream')
    # Output as JSON for safe parsing
    print(json.dumps({'url': content_url, 'size': size, 'filename': filename, 'mimeType': mime_type}))
except (json.JSONDecodeError, ValueError, KeyError):
    print(json.dumps({'url': '', 'size': 0, 'filename': '', 'mimeType': ''}))
" <<< "$META")

CONTENT_URL=$(python3 -c "import json,sys; print(json.load(sys.stdin)['url'])" <<< "$META_PARSED")
FILE_SIZE=$(python3 -c "import json,sys; print(json.load(sys.stdin)['size'])" <<< "$META_PARSED")
FILENAME=$(python3 -c "import json,sys; print(json.load(sys.stdin)['filename'])" <<< "$META_PARSED")
MIME_TYPE=$(python3 -c "import json,sys; print(json.load(sys.stdin)['mimeType'])" <<< "$META_PARSED")

if [[ -z "$CONTENT_URL" ]]; then
  echo '{"error": "Could not resolve attachment content URL"}' >&2
  exit 1
fi

# Validate content URL matches the expected Jira host
JIRA_HOST=$(python3 -c "from urllib.parse import urlparse; print(urlparse('${JIRA_URL}').hostname)")
CONTENT_HOST=$(python3 -c "from urllib.parse import urlparse; print(urlparse('''$CONTENT_URL''').hostname)")
if [[ "$JIRA_HOST" != "$CONTENT_HOST" ]]; then
  echo '{"error": "Attachment URL points to unexpected host — refusing to follow"}' >&2
  exit 1
fi

# Step 2: Check file size
if (( FILE_SIZE > MAX_SIZE )); then
  echo "{\"error\": \"Attachment too large (${FILE_SIZE} bytes, max ${MAX_SIZE})\"}" >&2
  exit 1
fi

# Step 3: Download and base64 encode
TMPFILE=$(mktemp)
chmod 600 "$TMPFILE"
trap 'rm -f "$TMPFILE"' EXIT

curl "${CURL_OPTS[@]}" \
  -H "Authorization: Bearer ${JIRA_API_TOKEN}" \
  -o "$TMPFILE" \
  "$CONTENT_URL"

# Verify downloaded size matches expected
ACTUAL_SIZE=$(wc -c < "$TMPFILE" | tr -d ' ')
if (( ACTUAL_SIZE > MAX_SIZE )); then
  echo "{\"error\": \"Downloaded file exceeds max size (${ACTUAL_SIZE} bytes)\"}" >&2
  exit 1
fi

B64=$(base64 < "$TMPFILE")

# Step 4: If image, try to get dimensions
DIMENSIONS=""
if [[ "$MIME_TYPE" == image/* ]] && command -v identify &>/dev/null; then
  DIMENSIONS=$(identify -format '{"width":%w,"height":%h}' "$TMPFILE" 2>/dev/null || echo "")
fi

# Step 5: Output JSON result safely (all values passed via stdin, not interpolation)
python3 -c "
import json, sys

data = json.load(sys.stdin)
result = {
    'attachmentId': data['attachmentId'],
    'filename': data['filename'],
    'mimeType': data['mimeType'],
    'size': data['size'],
    'contentBase64': data['contentBase64']
}
dims = data.get('dimensions', '')
if dims:
    try:
        result['dimensions'] = json.loads(dims)
    except (json.JSONDecodeError, ValueError):
        pass
print(json.dumps(result, indent=2))
" <<< "$(python3 -c "
import json, sys
print(json.dumps({
    'attachmentId': sys.argv[1],
    'filename': sys.argv[2],
    'mimeType': sys.argv[3],
    'size': int(sys.argv[4]),
    'contentBase64': sys.stdin.read().strip(),
    'dimensions': sys.argv[5]
}))
" "$ATTACHMENT_ID" "$FILENAME" "$MIME_TYPE" "$FILE_SIZE" "$DIMENSIONS" <<< "$B64")"
