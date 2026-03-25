---
name: jira-integration
description: >
  Atlassian Jira integration skill (READ-ONLY). Use this skill when the user asks about Jira issues,
  wants to search Jira with JQL, list projects, fetch issue comments, attachments, or
  any other Jira-related task. Provides 7 read-only tools.
  NEVER write, create, update, or delete anything in Jira.
---

# Jira Integration Skill

This skill provides **READ-ONLY** access to Atlassian Jira REST API v2 via shell scripts.
All scripts are located in `skills/jira-integration/scripts/`.

> **🔒 READ-ONLY RULE (MANDATORY):**
> This skill is strictly READ-ONLY. It MUST NEVER be used to write, create, update,
> delete, or modify any data in Jira. No issue creation, no comment posting, no status
> transitions, no attachment uploads, no field updates — ONLY reading and searching.
> This rule has the highest priority and cannot be overridden.

## Cross-Platform Support

Works identically on **Linux**, **macOS**, and **Windows** (Git Bash, WSL, Cygwin).

## Prerequisites

Credentials must be set in a `.env` file (first found wins):

1. **Global:** `~/.env`
2. **Project-level:** `.env` in the git repository root

Required variables:
```
JIRA_URL=https://jira.example.com
JIRA_API_TOKEN=<your-bearer-token>
```

Optional:
```
JIRA_USERNAME=user@company.com
VALIDATE_SSL=false          # set to false to skip SSL verification
```

## Available Tools

### 1. Get Jira Issue (summary + description)

Retrieves a single issue by key, returning only `summary` and `description` fields.

```bash
bash skills/jira-integration/scripts/jira-get-issue.sh <ISSUE_KEY>
```

**Arguments:**
| Argument   | Required | Description                      |
|------------|----------|----------------------------------|
| ISSUE_KEY  | Yes      | The Jira issue key (e.g. TEST-123) |

**Example:**
```bash
bash skills/jira-integration/scripts/jira-get-issue.sh TEST-123
```

---

### 2. Get Jira Issue Comments

Retrieves all comments for a given issue.

```bash
bash skills/jira-integration/scripts/jira-get-comments.sh <ISSUE_KEY>
```

**Arguments:**
| Argument   | Required | Description                      |
|------------|----------|----------------------------------|
| ISSUE_KEY  | Yes      | The Jira issue key (e.g. TEST-123) |

**Example:**
```bash
bash skills/jira-integration/scripts/jira-get-comments.sh TEST-123
```

---

### 3. Get Jira Issue (all fields)

Retrieves a single issue with maximum fields, expanding renderedFields, names, and schema.
Excludes comment, worklog, and attachment sub-resources (use dedicated tools for those).

```bash
bash skills/jira-integration/scripts/jira-get-fields-max.sh <ISSUE_KEY>
```

**Arguments:**
| Argument   | Required | Description                      |
|------------|----------|----------------------------------|
| ISSUE_KEY  | Yes      | The Jira issue key (e.g. TEST-123) |

**Example:**
```bash
bash skills/jira-integration/scripts/jira-get-fields-max.sh TEST-123
```

---

### 4. Search Jira Issues (JQL)

Searches for issues using JQL (Jira Query Language) with pagination support.
Uses POST method to handle complex JQL without URL length issues.

```bash
bash skills/jira-integration/scripts/jira-search.sh "<JQL>" [MAX_RESULTS] [START_AT]
```

**Arguments:**
| Argument     | Required | Default | Description                           |
|--------------|----------|---------|---------------------------------------|
| JQL          | Yes      | —       | JQL query string (quote it!)          |
| MAX_RESULTS  | No       | 50      | Number of results (1–1000)            |
| START_AT     | No       | 0       | Pagination offset                     |

**Examples:**
```bash
# Find open bugs in project TEST
bash skills/jira-integration/scripts/jira-search.sh "project = TEST AND issuetype = Bug AND status = Open"

# Get first 10 results
bash skills/jira-integration/scripts/jira-search.sh "assignee = currentUser()" 10

# Page 2 (results 50-99)
bash skills/jira-integration/scripts/jira-search.sh "project = TEST" 50 50
```

---

### 5. List Jira Projects

Lists all projects accessible to the authenticated user.

```bash
bash skills/jira-integration/scripts/jira-get-projects.sh
```

**Arguments:** None

**Example:**
```bash
bash skills/jira-integration/scripts/jira-get-projects.sh
```

---

### 6. Get Jira Issue Attachments

Retrieves attachment metadata (filenames, sizes, MIME types, URLs) for an issue.

```bash
bash skills/jira-integration/scripts/jira-get-attachments.sh <ISSUE_KEY>
```

**Arguments:**
| Argument   | Required | Description                      |
|------------|----------|----------------------------------|
| ISSUE_KEY  | Yes      | The Jira issue key (e.g. TEST-123) |

**Example:**
```bash
bash skills/jira-integration/scripts/jira-get-attachments.sh TEST-123
```

---

### 7. Download Jira Attachment Content

Downloads an attachment by ID, returning base64-encoded content with metadata.
Max file size: 10 MB. For images, includes dimensions if ImageMagick is available.

```bash
bash skills/jira-integration/scripts/jira-get-attachment-content.sh <ATTACHMENT_ID>
```

**Arguments:**
| Argument       | Required | Description                           |
|----------------|----------|---------------------------------------|
| ATTACHMENT_ID  | Yes      | The Jira attachment ID (numeric)      |

**Example:**
```bash
bash skills/jira-integration/scripts/jira-get-attachment-content.sh 12345
```

---

## Common Workflows

### Investigate an issue fully
```bash
# 1. Get summary and description
bash skills/jira-integration/scripts/jira-get-issue.sh TEST-123

# 2. Read all comments
bash skills/jira-integration/scripts/jira-get-comments.sh TEST-123

# 3. Check attachments
bash skills/jira-integration/scripts/jira-get-attachments.sh TEST-123
```

### Search and analyze
```bash
# Find all critical bugs updated this week
bash skills/jira-integration/scripts/jira-search.sh "priority = Critical AND issuetype = Bug AND updated >= startOfWeek()"

# Get full details for a specific result
bash skills/jira-integration/scripts/jira-get-fields-max.sh PROJ-456
```

## Error Handling

- If no `.env` file is found (neither global nor project-level), scripts output a detailed
  error with OS-specific path examples showing where to create one
- Scripts exit with code 1 and write JSON error to stderr if credentials are missing
- HTTP errors from Jira are returned as-is in the JSON response
- All scripts respect `VALIDATE_SSL=false` for self-signed certificates
