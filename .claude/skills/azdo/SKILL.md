---
name: azdo
description: "Clippy for Azure DevOps — config-driven PR management, work item tracking, and self-healing skill."
---

# Clippy ADO

> "It looks like you're trying to ship code without a work item. Would you like help with that?" — Clippy

**Topic guides** (read these for detailed policy):
- [PR Creation & Review](pr-review.md) — mandatory workflow, link direction, attribution
- [Work Item Management](work-items.md) — hierarchy, area paths, finding parents

## Self-Healing Skill

This skill is designed to be updated when problems are found. If you discover bugs, missing instructions, or incorrect behavior:

1. **Ask the user for permission** before modifying any skill files.
2. Make the fix in the local Clippy repo clone.
3. Commit, push a branch, and create a PR to the upstream repo.
4. Report the PR URL to the user.

Never silently modify skill files. See `CONTRIBUTING.md` in the repo root for the full policy.

## Configuration

This skill reads from `config.json` in the skill directory. **Do NOT read `config.template.json`** — that file is for humans to copy. Always read `config.json`.

If `config.json` is missing, tell the user to create it:
```bash
cp config.template.json config.json
# Then edit config.json with their values
```

If `organization` or `project` are missing or set to placeholder values, **stop and tell the user**. Do not guess.

## CLI Usage

The CLI requires [uv](https://docs.astral.sh/uv/). Dependencies are declared inline via PEP 723 metadata — no manual install step.

```bash
uv run ado_pr.py <command> [options]
```

The CLI reads `config.json` automatically. Options like `--repo` override config values.

### PR Commands

| Command | Options | Description |
|---------|---------|-------------|
| `list-comments` | `--repo --pr` | List active PR comments |
| `show-thread` | `--repo --pr --thread` | Show all comments in a thread |
| `reply` | `--repo --pr --thread --comment` | Reply to a thread |
| `resolve` | `--repo --pr --thread` | Mark thread as resolved |
| `reply-and-resolve` | `--repo --pr --thread --comment` | Reply and resolve in one step |
| `create-task` | `--repo --pr [--parent] [--description]` | Create Task work item linked to PR |

### Work Item Commands

| Command | Options | Description |
|---------|---------|-------------|
| `create-work-item` | `--type --title --description [--area-path] [--parent]` | Create a work item |
| `get-work-item` | `--id` | Get work item details |
| `list-children` | `--id` | List child work items of a parent |
| `update-work-item` | `--id [--title] [--description]` | Update a work item |

### Feature Registry Commands

| Command | Options | Description |
|---------|---------|-------------|
| `registry list` | | List all registered features |
| `registry add` | `--name --id [--description]` | Add a feature to the registry |
| `registry remove` | `--name` | Remove a feature (can't be default) |
| `registry set-default` | `--name` | Set the default feature |
| `registry status` | | Fetch live ADO data for each feature |

### Marshal & Duckrow Commands

| Command | Options | Description |
|---------|---------|-------------|
| `marshal-feature` | `--feature` | Recursively fetch feature tree → YAML IR |
| `duckrow` | `[-f]` | List all work items under registered features. `-f` picks features via fzf |

### Common Options

- `--config <path>` — Override config.json location
- `--repo <name>` — Repository name (overrides config)

## API Reference

- [Pull Requests API](https://learn.microsoft.com/en-us/rest/api/azure/devops/git/pull-requests)
- [Pull Request Threads API](https://learn.microsoft.com/en-us/rest/api/azure/devops/git/pull-request-threads)
- [Work Items API](https://learn.microsoft.com/en-us/rest/api/azure/devops/wit/work-items/create)
