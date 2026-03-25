# Jira Integration Skill — Setup Guide

## 🔒 READ-ONLY

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
   - Direct URL: `<your-jira-url>/plugins/personalaccesstokens/manage`
   - Example: `https://jira.example.com/plugins/personalaccesstokens/manage`
3. Click **Create token**
4. Give it a name (e.g. `ai-skill-readonly`) and set an expiry date
5. Copy the generated token and paste it as `JIRA_API_TOKEN` in your `.env` file

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
JIRA_URL=https://jira.example.com
JIRA_API_TOKEN=your-bearer-token-here

# Optional
JIRA_USERNAME=user@company.com
MCP_VALIDATE_SSL=false          # set to false for self-signed certificates
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

## Troubleshooting

| Problem | Solution |
|---|---|
| `No .env file found` | Create `.env` at one of the locations listed above |
| `JIRA_URL and JIRA_API_TOKEN must be set` | Add required variables to your `.env` |
| SSL certificate errors | Set `MCP_VALIDATE_SSL=false` in `.env` |
| `python3: command not found` | Install Python 3 for your OS |
| Permission denied on scripts | Run `chmod +x skills/jira-integration/scripts/*.sh` |
