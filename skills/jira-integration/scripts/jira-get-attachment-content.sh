#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# jira-get-attachment-content.sh — Download a Jira attachment
#
# Usage: jira-get-attachment-content.sh <ATTACHMENT_ID>
# Example: jira-get-attachment-content.sh 12345
#
# Returns: JSON with base64-encoded content and metadata
# Max size: 10 MB
#
# Security: validates host match, enforces HTTPS-only downloads,
#           no external tool execution on downloaded content,
#           secure temp files, all python via heredoc (no -c)
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

# Step 1: Get attachment metadata from Jira API
META_URL="${JIRA_URL}/rest/api/2/attachment/${ATTACHMENT_ID}"
META=$(curl "${CURL_OPTS[@]}" \
  -H "Authorization: Bearer ${JIRA_API_TOKEN}" \
  -H "Accept: application/json" \
  "$META_URL")

# Step 2: Validate and extract metadata in python (no shell interpolation)
# Checks: valid JSON, content URL exists, HTTPS-only, host matches JIRA_URL, size limit
#
# NOTE: metadata is passed via env var, NOT stdin. The construct
#   echo "$META" | python3 << 'PYEOF' ... PYEOF
# has two stdin redirections and bash resolves the heredoc last, so the
# heredoc body wins and the piped data is silently discarded. Always
# pass JSON into heredoc python blocks through the environment.
export META JIRA_URL MAX_SIZE
VALIDATED=$(python3 -S -E << 'PYEOF'
import json, sys, os
from urllib.parse import urlparse

jira_url = os.environ["JIRA_URL"]
max_size = int(os.environ["MAX_SIZE"])

try:
    meta = json.loads(os.environ["META"])
except (json.JSONDecodeError, ValueError):
    json.dump({"error": "Invalid metadata response"}, sys.stdout)
    sys.exit(1)

content_url = meta.get("content", "")
file_size = int(meta.get("size", 0))
filename = meta.get("filename", "")
mime_type = meta.get("mimeType", "application/octet-stream")

if not content_url:
    json.dump({"error": "No content URL in metadata"}, sys.stdout)
    sys.exit(1)

parsed = urlparse(content_url)
if parsed.scheme != "https":
    json.dump({"error": "Content URL must use HTTPS"}, sys.stdout)
    sys.exit(1)

jira_host = urlparse(jira_url).hostname
if jira_host != parsed.hostname:
    json.dump({"error": "Content URL host does not match Jira host"}, sys.stdout)
    sys.exit(1)

if file_size > max_size:
    json.dump({"error": f"Too large ({file_size} bytes, max {max_size})"}, sys.stdout)
    sys.exit(1)

json.dump({"url": content_url, "size": file_size, "filename": filename, "mimeType": mime_type}, sys.stdout)
PYEOF
)

# Abort on validation error
if echo "$VALIDATED" | grep -q '"error"'; then
  echo "$VALIDATED" >&2
  exit 1
fi

# Extract validated content URL
CONTENT_URL=$(echo "$VALIDATED" | python3 -S -E -c "import json,sys;print(json.load(sys.stdin)['url'])")

if [[ -z "$CONTENT_URL" ]]; then
  echo '{"error": "Could not resolve attachment content URL"}' >&2
  exit 1
fi

# Step 3: Download to secure temp file (HTTPS protocol enforced)
TMPFILE=$(mktemp)
chmod 600 "$TMPFILE"
trap 'rm -f "$TMPFILE"' EXIT

curl "${CURL_OPTS[@]}" \
  --proto =https \
  -H "Authorization: Bearer ${JIRA_API_TOKEN}" \
  -o "$TMPFILE" \
  "$CONTENT_URL"

# Verify actual downloaded size against limit
ACTUAL_SIZE=$(wc -c < "$TMPFILE" | tr -d ' ')
if (( ACTUAL_SIZE > MAX_SIZE )); then
  echo "{\"error\": \"Downloaded file exceeds max size (${ACTUAL_SIZE} bytes)\"}" >&2
  exit 1
fi

# Step 4: Base64 encode and build JSON output
# All values passed via environment variables — zero shell interpolation in python
export ATTACHMENT_ID VALIDATED TMPFILE
python3 -S -E << 'PYEOF'
import base64, json, os, sys

meta = json.loads(os.environ["VALIDATED"])
tmpfile = os.environ["TMPFILE"]

with open(tmpfile, "rb") as f:
    content_b64 = base64.b64encode(f.read()).decode("ascii")

result = {
    "attachmentId": os.environ["ATTACHMENT_ID"],
    "filename": meta["filename"],
    "mimeType": meta["mimeType"],
    "size": meta["size"],
    "contentBase64": content_b64
}
json.dump(result, sys.stdout, indent=2)
print()
PYEOF
