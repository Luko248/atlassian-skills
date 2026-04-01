# Jira Integration Skill — Setup Guide

## READ-ONLY

This skill provides **read-only** access to Jira. It can search issues, read details, comments, and attachments. It **NEVER** writes, creates, updates, or deletes anything in Jira.

## Supported Operating Systems

- **macOS** (Intel & Apple Silicon)
- **Linux** (all distributions)
- **Windows** (via Git Bash, WSL, or Cygwin)

## Prerequisites

- `bash` (v4+ recommended, v3.2+ on macOS works)
- `curl`
- `python3` (for JSON encoding)
- A Jira instance with API access and a Personal Access Token (Bearer token)

### How to create a Jira API token

1. Log in to your Jira instance
2. Navigate to **Profile** → **Personal Access Tokens**
3. Click **Create token**
4. Give it a name (e.g. `ai-skill-readonly`) and set an expiry date
5. Copy the generated token and paste it as `JIRA_API_TOKEN` in your `.env` file

## Setup

### 1. Create a `.env` file

The skill looks for credentials in this order (first found wins):

| Location | Path |
|---|---|
| **Global** (recommended) | `~/.env` |
| **Project-level** (fallback) | `.env` in the git repository root |

`~` is your home directory — `/Users/<username>` on macOS, `/home/<username>` on Linux, `C:\Users\<username>` on Windows.

### 2. `.env` file contents

```dotenv
# Required
JIRA_URL=https://jira.example.com
JIRA_API_TOKEN=your-bearer-token-here

# Optional
JIRA_USERNAME=user@company.com
VALIDATE_SSL=false          # set to false for self-signed certificates
```

### 3. Verify setup

```bash
# Quick test — list all accessible projects
bash skills/jira-integration/scripts/jira-get-projects.sh
```

If credentials are correct, you'll see a JSON array of projects.

## Available Tools

| Script | Description |
|---|---|
| `jira-get-issue.sh <KEY>` | Get issue summary + description |
| `jira-get-fields-max.sh <KEY>` | Get issue with all fields |
| `jira-get-comments.sh <KEY>` | Get all issue comments |
| `jira-get-attachments.sh <KEY>` | Get attachment metadata |
| `jira-get-attachment-content.sh <ID>` | Download attachment (base64, max 10 MB) |
| `jira-search.sh "<JQL>" [limit] [offset]` | Search issues with JQL |
| `jira-get-projects.sh` | List all projects |

All tools are **read-only** — they only use HTTP GET (or POST for search queries).

## Security

All scripts are hardened with multiple layers of protection:

### Network

- **HTTPS-only** — all connections enforce `--proto =https --proto-redir =https`; HTTP is rejected at the curl level
- **Curl hardening** — `--max-time 30`, `--connect-timeout 10`, `--max-redirs 3`, `--max-filesize 50MB` prevent slow-rate attacks, open redirects, and memory exhaustion

### Input validation

- **Issue keys** must match `PROJECT-123` format
- **Attachment IDs** must be numeric
- **Search limits** must be positive integers
- **URLs** are validated against a strict HTTPS pattern
- **Tokens** are rejected if they contain control characters or whitespace

### Credential protection

- `.env` loader uses an **allowlist** — only known variable names (`JIRA_URL`, `JIRA_API_TOKEN`, etc.) are loaded; all other keys are ignored
- Values containing **control characters** (`\n`, `\r`) are rejected to prevent HTTP header injection
- **File permission check** — warns if `.env` is world-readable and suggests `chmod 600`

### Code execution safety

- **No shell interpolation** — all user input (JQL, metadata) is passed to python via `os.environ` or `sys.stdin`, never interpolated into code strings
- **Python hardened** — all python calls use `-S -E` flags to disable `PYTHONSTARTUP`, `PYTHONPATH`, and site-packages (prevents environment poisoning)
- **No external tools** — downloaded attachments are never passed to ImageMagick, ffprobe, or any processing tool; only base64-encoded for safe transport

### Attachment downloads

- **Host verification** — download URLs must match the configured `JIRA_URL` hostname (SSRF protection)
- **HTTPS enforced** — content URLs must use `https://`; plain HTTP is rejected
- **Secure temp files** — `mktemp` with `chmod 600`, cleaned up via `trap` on exit
- **Post-download size check** — actual file size verified against the 10 MB limit after transfer
- **Read-only processing** — files are only base64-encoded, never executed or parsed

### Best practices

- Set `.env` permissions to `600`: `chmod 600 ~/.env`
- Use a dedicated read-only API token with minimal scope
- Set an expiry date on your token and rotate regularly
- Keep `VALIDATE_SSL=true` (default) in production — only disable for local dev with self-signed certs

## Troubleshooting

| Problem | Solution |
|---|---|
| `No .env file found` | Create `.env` at `~/.env` or in your project root |
| `JIRA_URL and JIRA_API_TOKEN must be set` | Add required variables to your `.env` |
| SSL certificate errors | Set `VALIDATE_SSL=false` in `.env` |
| `python3: command not found` | Install Python 3 for your OS |
| Permission denied on scripts | Run `chmod +x skills/jira-integration/scripts/*.sh` |
