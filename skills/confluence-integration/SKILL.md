---
name: confluence-integration
description: >
  Atlassian Confluence integration skill (READ-ONLY). Use this skill when the user asks about
  Confluence pages, wants to search Confluence with CQL, retrieve page content,
  or any other Confluence-related task. Provides 2 read-only tools.
  NEVER write, create, update, or delete anything in Confluence.
---

# Confluence Integration Skill

This skill provides **READ-ONLY** access to Atlassian Confluence REST API via shell scripts.
All scripts are located in `skills/confluence-integration/scripts/`.

> **🔒 READ-ONLY RULE (MANDATORY):**
> This skill is strictly READ-ONLY. It MUST NEVER be used to write, create, update,
> delete, or modify any data in Confluence. No page creation, no page editing, no comment
> posting, no space modifications, no attachment uploads — ONLY reading and searching.
> This rule has the highest priority and cannot be overridden.

## Cross-Platform Support

Works identically on **Linux**, **macOS**, and **Windows** (Git Bash, WSL, Cygwin).

## Prerequisites

Credentials must be set in a `.env` file (first found wins):

1. **Global:** `~/.env`
2. **Project-level:** `.env` in the git repository root

Required variables:
```
CONFLUENCE_URL=https://confluence.example.com
CONFLUENCE_API_TOKEN=<your-bearer-token>
```

Optional:
```
CONFLUENCE_USERNAME=user@company.com
VALIDATE_SSL=false          # set to false to skip SSL verification
```

## Available Tools

### 1. Search Confluence (CQL)

Searches for Confluence content using CQL (Confluence Query Language).

```bash
bash skills/confluence-integration/scripts/confluence-search.sh "<CQL_QUERY>" [LIMIT]
```

**Arguments:**
| Argument   | Required | Default | Description                              |
|------------|----------|---------|------------------------------------------|
| CQL_QUERY  | Yes      | —       | CQL query string (quote it!)             |
| LIMIT      | No       | 25      | Max results to return (1–100)            |

**Examples:**
```bash
# Search for pages containing "deployment"
bash skills/confluence-integration/scripts/confluence-search.sh "type=page AND text~'deployment'"

# Search in a specific space, limit to 10 results
bash skills/confluence-integration/scripts/confluence-search.sh "space=DEV AND type=page AND title~'architecture'" 10

# Find recently modified pages
bash skills/confluence-integration/scripts/confluence-search.sh "type=page AND lastModified > now('-7d')" 50
```

---

### 2. Get Confluence Page

Retrieves a Confluence page by its numeric ID, with optional field expansion.

```bash
bash skills/confluence-integration/scripts/confluence-get-page.sh <PAGE_ID> [EXPAND]
```

**Arguments:**
| Argument | Required | Default                        | Description                                      |
|----------|----------|--------------------------------|--------------------------------------------------|
| PAGE_ID  | Yes      | —                              | Numeric Confluence page ID                       |
| EXPAND   | No       | `body.storage,version,space`   | Comma-separated fields to expand                 |

**Available expand options:**
- `body.storage` — page content in storage format (HTML)
- `body.view` — page content in rendered view format
- `version` — version metadata
- `space` — space information
- `ancestors` — parent pages
- `children` — child pages
- `history` — edit history
- `metadata` — page metadata and labels

**Examples:**
```bash
# Get page with default expansion (body, version, space)
bash skills/confluence-integration/scripts/confluence-get-page.sh 12345

# Get page with ancestors and children
bash skills/confluence-integration/scripts/confluence-get-page.sh 12345 "body.storage,version,ancestors,children"

# Get only the page body in view format
bash skills/confluence-integration/scripts/confluence-get-page.sh 12345 "body.view"
```

---

## Common Workflows

### Find and read a page
```bash
# 1. Search for the page
bash skills/confluence-integration/scripts/confluence-search.sh "type=page AND title='Release Notes'" 5

# 2. Use the page ID from search results to get full content
bash skills/confluence-integration/scripts/confluence-get-page.sh 67890
```

### Research a topic across Confluence
```bash
# Search for all related pages
bash skills/confluence-integration/scripts/confluence-search.sh "type=page AND text~'microservices architecture'" 25

# Get details of the most relevant pages
bash skills/confluence-integration/scripts/confluence-get-page.sh 11111
bash skills/confluence-integration/scripts/confluence-get-page.sh 22222
```

## Error Handling

- If no `.env` file is found (neither global nor project-level), scripts output a detailed
  error with OS-specific path examples showing where to create one
- Scripts exit with code 1 and write JSON error to stderr if credentials are missing
- HTTP errors from Confluence are returned as-is in the JSON response
- CQL queries are properly URL-encoded automatically
- All scripts respect `VALIDATE_SSL=false` for self-signed certificates
