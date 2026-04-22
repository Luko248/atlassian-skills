#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# jira-get-attachment-content.sh — Download a Jira attachment
#
# Usage: jira-get-attachment-content.sh <ATTACHMENT_ID>
# Example: jira-get-attachment-content.sh 12345
#
# Saves the attachment to ./tmp/<ATTACHMENT_ID>_<filename> relative
# to the current working directory and prints JSON with the saved
# path and metadata. Max size: 10 MB.
#
# Security: validates host match, enforces HTTPS-only downloads,
#           filename sanitized to prevent path traversal,
#           partial downloads written to a .partial staging file
#           and only promoted on successful size check,
#           no external tool execution on downloaded content,
#           all python via heredoc (no -c)
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

# Step 2: Validate metadata, sanitize filename, and derive target path
# Checks: valid JSON, content URL exists, HTTPS-only, host matches JIRA_URL,
#         size limit, filename stripped of path components / hidden-file prefix.
#
# NOTE: metadata is passed via env var, NOT stdin. The construct
#   echo "$META" | python3 << 'PYEOF' ... PYEOF
# has two stdin redirections and bash resolves the heredoc last, so the
# heredoc body wins and the piped data is silently discarded. Always
# pass JSON into heredoc python blocks through the environment.
export META JIRA_URL MAX_SIZE ATTACHMENT_ID
VALIDATED=$(python3 -S -E << 'PYEOF'
import json, sys, os
from urllib.parse import urlparse

jira_url = os.environ["JIRA_URL"]
max_size = int(os.environ["MAX_SIZE"])
attachment_id = os.environ["ATTACHMENT_ID"]

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

# Sanitize filename — prevent path traversal, hidden files, control chars.
safe = filename.replace("\\", "/").split("/")[-1]
safe = "".join(c for c in safe if c.isprintable() and c != "\x00")
safe = safe.lstrip(".").strip()
if safe in ("", ".", ".."):
    safe = f"attachment-{attachment_id}"

target = os.path.join("tmp", f"{attachment_id}_{safe}")

json.dump({
    "url": content_url,
    "size": file_size,
    "filename": filename,
    "safeFilename": safe,
    "mimeType": mime_type,
    "target": target
}, sys.stdout)
PYEOF
)

# Abort on validation error
if echo "$VALIDATED" | grep -q '"error"'; then
  echo "$VALIDATED" >&2
  exit 1
fi

# Extract validated content URL and target path
CONTENT_URL=$(echo "$VALIDATED" | python3 -S -E -c "import json,sys;print(json.load(sys.stdin)['url'])")
TARGET_PATH=$(echo "$VALIDATED" | python3 -S -E -c "import json,sys;print(json.load(sys.stdin)['target'])")

if [[ -z "$CONTENT_URL" || -z "$TARGET_PATH" ]]; then
  echo '{"error": "Could not resolve attachment content URL or target path"}' >&2
  exit 1
fi

# Step 3: Download to ./tmp/<id>_<filename>.partial, promote to final name
# only after size check passes. Staging file is removed on any failure.
mkdir -p tmp

STAGING="${TARGET_PATH}.partial"
trap 'rm -f "$STAGING"' EXIT

curl "${CURL_OPTS[@]}" \
  --proto =https \
  -H "Authorization: Bearer ${JIRA_API_TOKEN}" \
  -o "$STAGING" \
  "$CONTENT_URL"

# Verify actual downloaded size against limit
ACTUAL_SIZE=$(wc -c < "$STAGING" | tr -d ' ')
if (( ACTUAL_SIZE > MAX_SIZE )); then
  echo "{\"error\": \"Downloaded file exceeds max size (${ACTUAL_SIZE} bytes)\"}" >&2
  exit 1
fi

mv -f "$STAGING" "$TARGET_PATH"
trap - EXIT

# Step 4: Build JSON response with the saved path (no base64 in output)
export ATTACHMENT_ID VALIDATED TARGET_PATH
python3 -S -E << 'PYEOF'
import json, os, sys

meta = json.loads(os.environ["VALIDATED"])
target = os.environ["TARGET_PATH"]

result = {
    "attachmentId": os.environ["ATTACHMENT_ID"],
    "filename": meta["filename"],
    "savedAs": meta["safeFilename"],
    "mimeType": meta["mimeType"],
    "size": meta["size"],
    "path": target,
    "absolutePath": os.path.abspath(target)
}
json.dump(result, sys.stdout, indent=2)
print()
PYEOF
