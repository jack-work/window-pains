---
name: azdo
description: Interact with Azure DevOps Pull Requests - create PRs, fetch comments, reply to threads, resolve comments. Also create and manage work items.
---

# Azure DevOps Pull Request & Work Item Interactions

## Claude Code Attribution

**IMPORTANT:** All comments posted through this tool are automatically signed with a Claude Code attribution footer. This ensures reviewers know the response was AI-assisted. The signature reads:

> *This comment was posted by [Claude Code](https://claude.ai/claude-code) on behalf of the PR author.*

When composing replies, write naturally - the attribution is appended automatically by `ado_pr.py`.

## PR Creation Workflow (MANDATORY)

**Every time you create or push a PR, you MUST also create a linked work item.** This is not optional. The work item link is how ADO tracks work — without it, the PR is invisible to boards, queries, and sprint tracking.

### Steps (in order):
1. **Create the PR** (via `az repos pr create` or equivalent)
2. **Extract the PR ID** from the creation response
3. **Create a Task work item linked to the PR** using `create-task --pr <ID>`
4. **Report both the PR URL and work item URL** to the user

### Why `create-task` and not `az repos pr work-item add`:
- `create-task` creates the link **on the work item** pointing to the PR (artifact link). This is the correct direction — ADO boards, completion policies, and queries use this link.
- `az repos pr work-item add` creates the link **on the PR** pointing to the work item. This is the **wrong direction** — the work item won't show the PR in its Development section. **Do not use this command.**

## Self-Updating Skill

If you discover these instructions are incomplete or incorrect, **update this file immediately** at `~/.claude/skills/azdo/SKILL.md`.

## Prerequisites

- Azure CLI with DevOps extension: `az extension add --name azure-devops`
- Logged in: `az login`
- Python 3.x

## Usage

All operations use the Python helper script:

```bash
python ~/.claude/skills/azdo/ado_pr.py <command> [options]
```

### PR Commands

| Command | Description | Options |
|---------|-------------|---------|
| `list-comments` | List active PR comments | `--pr <ID>` (required) |
| `show-thread` | Show all comments in a thread | `--pr <ID>` `--thread <ID>` |
| `reply` | Reply to a thread | `--pr <ID>` `--thread <ID>` `--comment "text"` |
| `resolve` | Mark thread as resolved | `--pr <ID>` `--thread <ID>` |
| `reply-and-resolve` | Reply and resolve in one step | `--pr <ID>` `--thread <ID>` `--comment "text"` |
| `create-task` | Create linked Task work item | `--pr <ID>` |

### Work Item Commands

| Command | Description | Options |
|---------|-------------|---------|
| `create-work-item` | Create a work item | `--type` `--title` `--description` `--area-path` `--assigned-to` `--parent` |
| `get-work-item` | Get work item details | `--id <ID>` |
| `list-children` | List child work items | `--id <ID>` |

### Common Options

- `--org` - ADO organization (default: msazure)
- `--project` - ADO project (default: OneAgile)
- `--repo` - Repository name (default: PowerApps-Orchard)
- `--pr` - PR ID (required for PR commands)

### Examples

```bash
# List active comments
python ~/.claude/skills/azdo/ado_pr.py --pr 14555088 list-comments

# View full thread conversation
python ~/.claude/skills/azdo/ado_pr.py --pr 14555088 show-thread --thread 226874052

# Reply to a comment
python ~/.claude/skills/azdo/ado_pr.py --pr 14555088 reply --thread 226874052 --comment "Fixed in latest commit"

# Reply and resolve
python ~/.claude/skills/azdo/ado_pr.py --pr 14555088 reply-and-resolve --thread 226874052 --comment "Done"

# Different org/project/repo
python ~/.claude/skills/azdo/ado_pr.py --org msazure --project One --repo PowerPlatform-BusinessAppPlatform-RP --pr 14563530 list-comments

# Create a work item
python ~/.claude/skills/azdo/ado_pr.py create-work-item --type "Task" --title "My Task" --description "Description" --area-path "OneAgile\PowerApps\Developer Agents\Orchard"

# Create a User Story with parent
python ~/.claude/skills/azdo/ado_pr.py create-work-item --type "User Story" --title "My Story" --description "Description" --parent 12345

# Get work item details
python ~/.claude/skills/azdo/ado_pr.py get-work-item --id 12345

# List children of a work item
python ~/.claude/skills/azdo/ado_pr.py list-children --id 12345
```

## Work Item Creation Guidelines for Orchard

### Default Area Path
For Orchard-related work, use this area path unless told otherwise:
```
OneAgile\PowerApps\Developer Agents\Orchard
```

### Jack's Backlog (Feature ID: 36649440)
**URL:** https://dev.azure.com/msazure/OneAgile/_workitems/edit/36649440

This Feature is a placeholder designed for tracking follow-up tasks that lack immediately obvious places in the ADO hierarchy. When creating work items for Orchard and you don't have a clear parent:

1. **First**, try to find an appropriate existing Feature or User Story in the Orchard hierarchy
2. **If no clear parent exists**, use Jack's Backlog as the parent:
   - Create a User Story under Jack's Backlog (parent ID: 36649440) describing the feature/capability
   - Create Tasks under that User Story for the actual implementation work
3. Items in Jack's Backlog should eventually be repathed to more appropriate locations in the hierarchy

### Work Item Type Guidance

Use your best judgment when creating work items:

| Type | When to Use |
|------|-------------|
| **Feature** | Large capabilities spanning multiple User Stories (rarely created) |
| **User Story** | Discrete pieces of user-facing functionality or technical capabilities |
| **Task** | Implementation work items - specific coding, testing, or documentation tasks |
| **Bug** | Defects in existing functionality that need to be fixed |

### Work Item Hierarchy
```
Feature
└── User Story
    └── Task
    └── Bug
```

### Finding the Right Parent
When asked to create a work item and the parent is unclear:

1. Use `list-children --id 36649440` to see existing User Stories under Jack's Backlog
2. Check if an existing User Story fits the new work
3. If not, create a new User Story with appropriate context
4. Create Tasks/Bugs under the User Story

### Always Announce Created Work Items
When creating work items, ALWAYS output the work item ID and URL so the user can access them:
```
Created Task 12345
URL: https://dev.azure.com/msazure/OneAgile/_workitems/edit/12345
```

## Linking Work Items to PRs

**Always use `create-task`** to create and link a work item to a PR. This creates the artifact link in the correct direction (work item → PR).

```bash
python ~/.claude/skills/azdo/ado_pr.py --pr <ID> create-task
```

> **WARNING:** Do NOT use `az repos pr work-item add` — it creates the link in the wrong direction (PR → work item). The work item won't show the PR in its Development section, and ADO tracking/queries won't see it.

## Technical Notes

### Artifact Link Format

When creating work item links to PRs via API, use URL-encoded slashes:
```
vstfs:///Git/PullRequestId/{projectId}%2F{repoId}%2F{prId}
```

Regular slashes will NOT work - the PR won't recognize the link.

### Work Item Types with Spaces
Work item types containing spaces (e.g., "User Story") are automatically URL-encoded by the script.

## API Reference

- [Pull Requests API](https://learn.microsoft.com/en-us/rest/api/azure/devops/git/pull-requests)
- [Pull Request Threads API](https://learn.microsoft.com/en-us/rest/api/azure/devops/git/pull-request-threads)
- [Work Items API](https://learn.microsoft.com/en-us/rest/api/azure/devops/wit/work-items/create)
