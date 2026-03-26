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

- **Read-only by design** — only HTTP GET requests (POST for JQL search), no write operations exist in the codebase
- **Input validation** — issue keys must match `PROJECT-123` format, attachment IDs must be numeric, search limits must be positive integers
- **Credential protection** — `.env` loader only reads an allowlist of known variable names; all other keys are ignored. Values containing control characters (e.g. `\n`, `\r`) are rejected to prevent HTTP header injection
- **File permission checks** — warns if your `.env` file is world-readable and suggests `chmod 600`
- **No shell interpolation in payloads** — all user input (JQL queries, metadata) is passed to `python3` via stdin or `sys.argv`, never interpolated into code strings
- **URL validation** — `JIRA_URL` is validated against a strict pattern before use
- **Token validation** — `JIRA_API_TOKEN` is checked for control characters and whitespace
- **Curl hardening** — all requests enforce `--max-time 30`, `--connect-timeout 10`, `--max-redirs 3`, and `--max-filesize 50MB` to prevent slow-rate attacks, open redirects, and memory exhaustion
- **Attachment host verification** — download URLs are verified to match the configured Jira hostname, preventing SSRF
- **Secure temp files** — attachment downloads use `mktemp` with `chmod 600` and are cleaned up via `trap` on exit
- **Post-download size check** — downloaded files are verified against the 10 MB limit after transfer

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
