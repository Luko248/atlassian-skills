# Confluence Integration Skill — Setup Guide

## READ-ONLY

This skill provides **read-only** access to Confluence. It can search pages and read page content. It **NEVER** writes, creates, updates, or deletes anything in Confluence.

## Supported Operating Systems

- **macOS** (Intel & Apple Silicon)
- **Linux** (all distributions)
- **Windows** (via Git Bash, WSL, or Cygwin)

## Prerequisites

- `bash` (v4+ recommended, v3.2+ on macOS works)
- `curl`
- `python3` (for URL encoding)
- A Confluence instance with API access and a Personal Access Token (Bearer token)

### How to create a Confluence API token

1. Log in to your Confluence instance
2. Navigate to **Profile** → **Personal Access Tokens**
3. Click **Create token**
4. Give it a name (e.g. `ai-skill-readonly`) and set an expiry date
5. Copy the generated token and paste it as `CONFLUENCE_API_TOKEN` in your `.env` file

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
CONFLUENCE_URL=https://confluence.example.com
CONFLUENCE_API_TOKEN=your-bearer-token-here

# Optional
CONFLUENCE_USERNAME=user@company.com
VALIDATE_SSL=false          # set to false for self-signed certificates
```

### 3. Verify setup

```bash
# Quick test — search for any page
bash skills/confluence-integration/scripts/confluence-search.sh "type=page" 1
```

If credentials are correct, you'll see a JSON response with search results.

## Available Tools

| Script | Description |
|---|---|
| `confluence-search.sh "<CQL>" [limit]` | Search pages with CQL |
| `confluence-get-page.sh <ID> [expand]` | Get page content by ID |

All tools are **read-only** — they only use HTTP GET requests.

## Security

All scripts are hardened with multiple layers of protection:

### Network

- **HTTPS-only** — all connections enforce `--proto =https --proto-redir =https`; HTTP is rejected at the curl level
- **Curl hardening** — `--max-time 30`, `--connect-timeout 10`, `--max-redirs 3`, `--max-filesize 50MB` prevent slow-rate attacks, open redirects, and memory exhaustion

### Input validation

- **Page IDs** must be numeric
- **CQL limits** must be positive integers
- **Expand parameters** are restricted to safe characters (`a-z`, `.`, `,`, `-`)
- **URLs** are validated against a strict HTTPS pattern
- **Tokens** are rejected if they contain control characters or whitespace

### Credential protection

- `.env` loader uses an **allowlist** — only known variable names (`CONFLUENCE_URL`, `CONFLUENCE_API_TOKEN`, etc.) are loaded; all other keys are ignored
- Values containing **control characters** (`\n`, `\r`) are rejected to prevent HTTP header injection
- **File permission check** — warns if `.env` is world-readable and suggests `chmod 600`

### Code execution safety

- **No shell interpolation** — all user input (CQL queries, expand params) is passed to python via `sys.stdin`, never interpolated into code strings
- **Python hardened** — all python calls use `-S -E` flags to disable `PYTHONSTARTUP`, `PYTHONPATH`, and site-packages (prevents environment poisoning)
- **URL encoding** — CQL queries and expand parameters are safely encoded via `python3 urllib.parse.quote`

### Best practices

- Set `.env` permissions to `600`: `chmod 600 ~/.env`
- Use a dedicated read-only API token with minimal scope
- Set an expiry date on your token and rotate regularly
- Keep `VALIDATE_SSL=true` (default) in production — only disable for local dev with self-signed certs

## Troubleshooting

| Problem | Solution |
|---|---|
| `No .env file found` | Create `.env` at `~/.env` or in your project root |
| `CONFLUENCE_URL and CONFLUENCE_API_TOKEN must be set` | Add required variables to your `.env` |
| SSL certificate errors | Set `VALIDATE_SSL=false` in `.env` |
| `python3: command not found` | Install Python 3 for your OS |
| Permission denied on scripts | Run `chmod +x skills/confluence-integration/scripts/*.sh` |
