# Confluence Integration Skill — Setup Guide

## 🔒 READ-ONLY

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
   - Direct URL: `<your-confluence-url>/plugins/personalaccesstokens/manage`
   - Example: `https://confluence.example.com/plugins/personalaccesstokens/manage`
3. Click **Create token**
4. Give it a name (e.g. `ai-skill-readonly`) and set an expiry date
5. Copy the generated token and paste it as `CONFLUENCE_API_TOKEN` in your `.env` file

## Setup

### 1. Create a `.env` file

The skill looks for credentials in this order (first found wins):

#### Global locations (OS-level, recommended)

| OS | Path |
|---|---|
| **macOS** | `/Users/<username>/.ais-support-mcp/.env` |
| **macOS** (alt) | `/Users/<username>/.env.ais-support-mcp` |
| **macOS** (fallback) | `/Users/<username>/.env` |
| **Linux** | `/home/<username>/.ais-support-mcp/.env` |
| **Linux** (alt) | `/home/<username>/.env.ais-support-mcp` |
| **Linux** (fallback) | `/home/<username>/.env` |
| **Windows (Git Bash)** | `/c/Users/<username>/.ais-support-mcp/.env` |
| **Windows (Git Bash)** (alt) | `/c/Users/<username>/.env.ais-support-mcp` |
| **Windows (Git Bash)** (fallback) | `/c/Users/<username>/.env` |
| **Windows (WSL)** | `/home/<username>/.ais-support-mcp/.env` |
| **Windows (WSL)** (alt) | `/home/<username>/.env.ais-support-mcp` |
| **Windows (WSL)** (fallback) | `/home/<username>/.env` |
| **Windows (native path)** | `C:\Users\<username>\.ais-support-mcp\.env` |
| **Windows (native path)** (alt) | `C:\Users\<username>\.env.ais-support-mcp` |
| **Windows (native path)** (fallback) | `C:\Users\<username>\.env` |

> **Tip:** On all platforms you can use `~/.ais-support-mcp/.env` in the terminal — the shell expands `~` to the correct home directory.

#### Project-level location (fallback)

If no global `.env` is found, the skill looks for `.env` in the **git repository root** (or current working directory if not in a git repo).

#### If no `.env` file exists

The skill will output a clear error message with OS-specific path examples telling you exactly where to create the file.

### 2. `.env` file contents

```dotenv
# Required
CONFLUENCE_URL=https://confluence.example.com
CONFLUENCE_API_TOKEN=your-bearer-token-here

# Optional
CONFLUENCE_USERNAME=user@company.com
MCP_VALIDATE_SSL=false          # set to false for self-signed certificates
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

## Troubleshooting

| Problem | Solution |
|---|---|
| `No .env file found` | Create `.env` at one of the locations listed above |
| `CONFLUENCE_URL and CONFLUENCE_API_TOKEN must be set` | Add required variables to your `.env` |
| SSL certificate errors | Set `MCP_VALIDATE_SSL=false` in `.env` |
| `python3: command not found` | Install Python 3 for your OS |
| Permission denied on scripts | Run `chmod +x skills/confluence-integration/scripts/*.sh` |
