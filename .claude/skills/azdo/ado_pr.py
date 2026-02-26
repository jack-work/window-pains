# /// script
# requires-python = ">=3.10"
# dependencies = [
#   "httpx>=0.27",
#   "click>=8.1",
#   "pyyaml>=6.0",
# ]
# ///
"""Azure DevOps PR helper CLI for Claude Code.

Usage:
    uv run ado_pr.py [--config config.json] <command> [options]

Dependencies are managed via PEP 723 inline metadata.
Run with `uv run` — no manual install needed.
"""

import json
import os
import shutil
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import quote

import click
import httpx
import yaml

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

ADO_RESOURCE = "499b84ac-1321-427f-aa17-267ca6975798"
API_VERSION = "7.1"

CLAUDE_CODE_SIGNATURE = (
    "\n\n---\n"
    "*This comment was posted by [Claude Code](https://claude.ai/claude-code) "
    "on behalf of the PR author.*"
)

# ---------------------------------------------------------------------------
# Token management
# ---------------------------------------------------------------------------

_cached_token: str | None = None


def _find_az_cli() -> str:
    """Locate the az CLI executable."""
    candidates = [
        shutil.which("az"),
        r"C:\Program Files (x86)\Microsoft SDKs\Azure\CLI2\wbin\az.cmd",
        r"C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd",
        os.path.expanduser("~\\scoop\\apps\\azure-cli\\current\\bin\\az.cmd"),
    ]
    for c in candidates:
        if c and os.path.exists(c):
            return c
    raise click.ClickException("az CLI not found. Please install Azure CLI.")


def get_token() -> str:
    """Get an Azure access token (cached for the process lifetime)."""
    global _cached_token
    if _cached_token is not None:
        return _cached_token

    az = _find_az_cli()
    result = subprocess.run(
        [az, "account", "get-access-token", "--resource", ADO_RESOURCE,
         "--query", "accessToken", "-o", "tsv"],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        raise click.ClickException(f"Failed to get token: {result.stderr.strip()}")
    _cached_token = result.stdout.strip()
    return _cached_token


# ---------------------------------------------------------------------------
# HTTP client
# ---------------------------------------------------------------------------

def _client() -> httpx.Client:
    """Build an authenticated httpx client."""
    return httpx.Client(
        headers={
            "Authorization": f"Bearer {get_token()}",
        },
        timeout=30.0,
    )


def _retry(fn, *, retries: int = 3, backoff: float = 1.0):
    """Retry a callable on transient connection errors."""
    for attempt in range(retries):
        try:
            return fn()
        except (httpx.ConnectError, httpx.ReadError) as e:
            if attempt == retries - 1:
                raise
            time.sleep(backoff * (attempt + 1))


def api_get(url: str) -> dict:
    """Authenticated GET returning JSON."""
    def _do():
        with _client() as c:
            r = c.get(url)
            r.raise_for_status()
            return r.json()
    return _retry(_do)


def api_post(url: str, payload: dict | list, *, content_type: str = "application/json") -> dict:
    """Authenticated POST returning JSON."""
    def _do():
        with _client() as c:
            r = c.post(url, json=payload, headers={"Content-Type": content_type})
            r.raise_for_status()
            return r.json()
    return _retry(_do)


def api_patch(url: str, payload: dict | list, *, content_type: str = "application/json") -> dict:
    """Authenticated PATCH returning JSON."""
    with _client() as c:
        r = c.patch(url, json=payload, headers={"Content-Type": content_type})
        r.raise_for_status()
        return r.json()


# ---------------------------------------------------------------------------
# URL helpers
# ---------------------------------------------------------------------------

def ado_url(org: str, project: str, *parts: str, **params: str) -> str:
    """Build an ADO REST API URL."""
    params.setdefault("api-version", API_VERSION)
    base = f"https://dev.azure.com/{org}/{project}/_apis/" + "/".join(parts)
    qs = "&".join(f"{k}={v}" for k, v in params.items())
    return f"{base}?{qs}"


def org_url(org: str, *parts: str, **params: str) -> str:
    """Build an ADO REST API URL at the org level (no project)."""
    params.setdefault("api-version", API_VERSION)
    base = f"https://dev.azure.com/{org}/_apis/" + "/".join(parts)
    qs = "&".join(f"{k}={v}" for k, v in params.items())
    return f"{base}?{qs}"


# ---------------------------------------------------------------------------
# Config loading
# ---------------------------------------------------------------------------

def load_config(config_path: str | None) -> dict:
    """Load config.json from the given path, or from the script's directory."""
    if config_path:
        p = Path(config_path)
    else:
        p = Path(__file__).parent / "config.json"

    if not p.exists():
        raise click.ClickException(
            f"Config not found at {p}. Copy config.template.json to config.json and fill in your values."
        )

    with open(p, encoding="utf-8") as f:
        cfg = json.load(f)

    # Stash the resolved path so write operations can save back
    cfg["_config_path"] = str(p)

    for key in ("organization", "project"):
        val = cfg.get(key, "")
        if not val or val.startswith("<"):
            raise click.ClickException(
                f"config.json: '{key}' is missing or set to a placeholder. Please set it."
            )
    return cfg


# ---------------------------------------------------------------------------
# Feature registry helpers
# ---------------------------------------------------------------------------

def _get_registry(cfg: dict) -> dict:
    """Return the features map from config (handles backcompat with backlogFeatureId)."""
    if "features" in cfg:
        return dict(cfg["features"])
    # Backward compat: synthesize from old flat field
    old_id = cfg.get("backlogFeatureId")
    if old_id:
        return {
            "backlog": {
                "id": old_id,
                "description": "Migrated from backlogFeatureId",
                "added_at": "unknown",
            }
        }
    return {}


def _save_config(cfg: dict) -> None:
    """Write config.json back, preserving non-internal keys."""
    config_path = cfg.get("_config_path")
    if not config_path:
        raise click.ClickException("Config path not set — cannot save.")
    out = {k: v for k, v in cfg.items() if not k.startswith("_")}
    with open(config_path, "w", encoding="utf-8") as f:
        json.dump(out, f, indent=2, ensure_ascii=False)
        f.write("\n")


def _resolve_feature(cfg: dict, name_or_id: str) -> tuple[str, dict]:
    """Look up a feature by name or by ADO ID. Returns (name, entry)."""
    registry = _get_registry(cfg)
    # Try by name first
    if name_or_id in registry:
        return name_or_id, registry[name_or_id]
    # Try by integer ID
    try:
        lookup_id = int(name_or_id)
    except ValueError:
        raise click.ClickException(f"Feature '{name_or_id}' not found in registry.")
    for name, entry in registry.items():
        if entry.get("id") == lookup_id:
            return name, entry
    raise click.ClickException(f"Feature with ID {lookup_id} not found in registry.")


def _fetch_work_item(org: str, project: str, work_item_id: int) -> dict:
    """Fetch a single work item with relations (data only, no printing)."""
    url = ado_url(org, project, "wit", "workitems", str(work_item_id), **{"$expand": "relations"})
    return api_get(url)


# ---------------------------------------------------------------------------
# PR operations
# ---------------------------------------------------------------------------

def get_threads(org: str, project: str, repo: str, pr_id: int, *, active_only: bool = True) -> list[dict]:
    """Fetch PR comment threads."""
    url = ado_url(org, project, "git", "repositories", repo, "pullrequests", str(pr_id), "threads")
    threads = api_get(url).get("value", [])
    if active_only:
        threads = [
            t for t in threads
            if t.get("status") not in ("fixed", "closed") and not t.get("isDeleted")
        ]
    return threads


def list_comments(org: str, project: str, repo: str, pr_id: int) -> None:
    """Print a table of active PR comment threads."""
    threads = get_threads(org, project, repo, pr_id, active_only=True)

    rows: list[dict] = []
    for t in threads:
        human = [
            c for c in t.get("comments", [])
            if c.get("author", {}).get("displayName") != "Microsoft.VisualStudio.Services.TFS"
            and c.get("commentType") != "system"
        ]
        if human:
            ctx = t.get("threadContext") or {}
            rows.append({
                "thread_id": t["id"],
                "status": t.get("status"),
                "file_path": ctx.get("filePath"),
                "line": (ctx.get("rightFileStart") or {}).get("line"),
                "content": human[0].get("content", "")[:150],
            })

    click.echo(f"{'Thread ID':<12} {'Status':<10} {'File':<50} {'Line':<6} Content")
    click.echo("-" * 120)
    for r in sorted(rows, key=lambda x: x.get("line") or 0):
        fp = (r["file_path"] or "")[:48]
        body = r["content"].replace("\n", " ")[:50]
        click.echo(f"{r['thread_id']:<12} {r['status'] or '':<10} {fp:<50} {r['line'] or '':<6} {body}")


def show_thread(org: str, project: str, repo: str, pr_id: int, thread_id: int) -> None:
    """Print all comments in a single thread."""
    for t in get_threads(org, project, repo, pr_id, active_only=False):
        if t["id"] == thread_id:
            ctx = t.get("threadContext") or {}
            click.echo(f"Thread {thread_id} (status: {t.get('status', 'unknown')})")
            click.echo(f"File: {ctx.get('filePath', 'N/A')}")
            click.echo(f"Line: {(ctx.get('rightFileStart') or {}).get('line', 'N/A')}")
            click.echo("-" * 80)
            for c in t.get("comments", []):
                if not c.get("isDeleted"):
                    author = c.get("author", {}).get("displayName", "unknown")
                    click.echo(f"\n[{author}]:")
                    click.echo(c.get("content", ""))
            return
    click.echo(f"Thread {thread_id} not found")


def reply_to_thread(org: str, project: str, repo: str, pr_id: int, thread_id: int, comment: str) -> dict:
    """Post a reply to a PR comment thread (with attribution)."""
    url = ado_url(
        org, project, "git", "repositories", repo,
        "pullrequests", str(pr_id), "threads", str(thread_id), "comments",
    )
    result = api_post(url, {"content": comment + CLAUDE_CODE_SIGNATURE, "commentType": 1})
    click.echo(f"Replied to thread {thread_id}")
    return result


def resolve_thread(org: str, project: str, repo: str, pr_id: int, thread_id: int) -> dict:
    """Mark a thread as resolved."""
    url = ado_url(
        org, project, "git", "repositories", repo,
        "pullrequests", str(pr_id), "threads", str(thread_id),
    )
    result = api_patch(url, {"status": "fixed"})
    click.echo(f"Resolved thread {thread_id}")
    return result


def get_pr_details(org: str, project: str, repo: str, pr_id: int) -> dict:
    """Fetch PR metadata."""
    url = ado_url(org, project, "git", "repositories", repo, "pullrequests", str(pr_id))
    return api_get(url)


# ---------------------------------------------------------------------------
# Work-item operations
# ---------------------------------------------------------------------------

def get_project_id(org: str, project: str) -> str:
    """Get the project GUID."""
    url = org_url(org, "projects", project)
    return api_get(url)["id"]


def create_work_item(
    org: str, project: str, work_item_type: str, title: str, description: str,
    *, pr_link: dict | None = None, area_path: str | None = None,
    assigned_to: str | None = None, parent_id: int | None = None,
) -> dict:
    """Create a work item, optionally linked to a PR and/or parent."""
    encoded_type = quote(work_item_type)
    url = f"https://dev.azure.com/{org}/{project}/_apis/wit/workitems/${encoded_type}?api-version={API_VERSION}"

    ops: list[dict] = [
        {"op": "add", "path": "/fields/System.Title", "value": title},
        {"op": "add", "path": "/fields/System.Description", "value": description},
    ]
    if area_path:
        ops.append({"op": "add", "path": "/fields/System.AreaPath", "value": area_path})
    if assigned_to:
        ops.append({"op": "add", "path": "/fields/System.AssignedTo", "value": assigned_to})
    if parent_id:
        ops.append({
            "op": "add", "path": "/relations/-",
            "value": {
                "rel": "System.LinkTypes.Hierarchy-Reverse",
                "url": f"https://dev.azure.com/{org}/{project}/_apis/wit/workItems/{parent_id}",
                "attributes": {"comment": "Parent link"},
            },
        })
    if pr_link:
        artifact = (
            f"vstfs:///Git/PullRequestId/"
            f"{pr_link['project_id']}%2F{pr_link['repo_id']}%2F{pr_link['pr_id']}"
        )
        ops.append({
            "op": "add", "path": "/relations/-",
            "value": {
                "rel": "ArtifactLink",
                "url": artifact,
                "attributes": {"name": "Pull Request"},
            },
        })

    return api_post(url, ops, content_type="application/json-patch+json")


def update_work_item(org: str, project: str, work_item_id: int, *, title: str | None = None, description: str | None = None) -> dict | None:
    """Update an existing work item."""
    ops: list[dict] = []
    if title:
        ops.append({"op": "replace", "path": "/fields/System.Title", "value": title})
    if description:
        ops.append({"op": "replace", "path": "/fields/System.Description", "value": description})
    if not ops:
        click.echo("No updates specified")
        return None

    url = f"https://dev.azure.com/{org}/{project}/_apis/wit/workitems/{work_item_id}?api-version={API_VERSION}"
    result = api_patch(url, ops, content_type="application/json-patch+json")
    click.echo(f"Updated work item {work_item_id}")
    click.echo(f"URL: {result['_links']['html']['href']}")
    return result


def get_work_item(org: str, project: str, work_item_id: int) -> dict:
    """Fetch and print work item details."""
    url = ado_url(org, project, "wit", "workitems", str(work_item_id), **{"$expand": "relations"})
    result = api_get(url)

    f = result.get("fields", {})
    click.echo(f"Work Item {work_item_id}")
    click.echo(f"Type: {f.get('System.WorkItemType', 'N/A')}")
    click.echo(f"Title: {f.get('System.Title', 'N/A')}")
    click.echo(f"State: {f.get('System.State', 'N/A')}")
    click.echo(f"Area Path: {f.get('System.AreaPath', 'N/A')}")
    click.echo(f"Assigned To: {f.get('System.AssignedTo', {}).get('displayName', 'Unassigned')}")
    click.echo(f"URL: {result['_links']['html']['href']}")
    click.echo("-" * 80)
    click.echo("Description:")
    click.echo(f.get("System.Description", "No description"))
    return result


def _fetch_children(org: str, project: str, parent_id: int) -> list[dict]:
    """Fetch child work items of a parent (data only, no printing)."""
    wiql_url = ado_url(org, project, "wit", "wiql")
    wiql = {
        "query": (
            f"SELECT [System.Id], [System.Title], [System.WorkItemType], [System.State] "
            f"FROM WorkItemLinks "
            f"WHERE ([Source].[System.Id] = {parent_id}) "
            f"AND ([System.Links.LinkType] = 'System.LinkTypes.Hierarchy-Forward') "
            f"MODE (MustContain)"
        )
    }
    result = api_post(wiql_url, wiql)

    child_ids = [
        link["target"]["id"]
        for link in result.get("workItemRelations", [])
        if link.get("target") and link["target"]["id"] != parent_id
    ]
    if not child_ids:
        return []

    ids_str = ",".join(str(i) for i in child_ids)
    details_url = ado_url(org, project, "wit", "workitems", ids=ids_str)
    details = api_get(details_url)
    return details.get("value", [])


def list_child_work_items(org: str, project: str, parent_id: int) -> list[dict]:
    """Query and print child work items of a parent."""
    items = _fetch_children(org, project, parent_id)
    if not items:
        click.echo(f"No child work items found for {parent_id}")
        return []

    click.echo(f"Child work items of {parent_id}:")
    click.echo(f"{'ID':<10} {'Type':<15} {'State':<12} Title")
    click.echo("-" * 80)
    for item in items:
        f = item.get("fields", {})
        click.echo(
            f"{item['id']:<10} {f.get('System.WorkItemType', ''):<15} "
            f"{f.get('System.State', ''):<12} {f.get('System.Title', '')}"
        )
    return items


def create_task_for_pr(
    org: str, project: str, repo: str, pr_id: int,
    *, parent_id: int | None = None, description: str | None = None,
) -> dict:
    """Create a Task work item linked to a PR."""
    pr = get_pr_details(org, project, repo, pr_id)
    title = pr.get("title", f"PR {pr_id}")
    repo_id = pr.get("repository", {}).get("id")
    if not repo_id:
        raise click.ClickException("Could not get repository ID from PR")

    if not description:
        description = f"Implement and land PR: {title}"

    project_id = get_project_id(org, project)
    pr_link = {"project_id": project_id, "repo_id": repo_id, "pr_id": pr_id}
    result = create_work_item(org, project, "Task", title, description, pr_link=pr_link, parent_id=parent_id)

    wi_id = result["id"]
    wi_url = result["_links"]["html"]["href"]
    click.echo(f"Created Task {wi_id} linked to PR {pr_id}")
    click.echo(f"URL: {wi_url}")
    return result


# ---------------------------------------------------------------------------
# Pipeline operations
# ---------------------------------------------------------------------------

def queue_pipeline(
    org: str, project: str, pipeline_id: int, branch: str,
    *, parameters: dict[str, str] | None = None,
) -> dict:
    """Queue a pipeline run on a given branch with optional template parameters."""
    url = ado_url(org, project, "pipelines", str(pipeline_id), "runs")
    body: dict = {
        "resources": {
            "repositories": {
                "self": {
                    "refName": f"refs/heads/{branch}",
                }
            }
        },
    }
    if parameters:
        body["templateParameters"] = parameters

    result = api_post(url, body)
    run_id = result.get("id")
    run_name = result.get("name", "N/A")
    state = result.get("state", "unknown")
    pipeline_name = result.get("pipeline", {}).get("name", f"Pipeline {pipeline_id}")
    run_url = f"https://dev.azure.com/{org}/{project}/_build/results?buildId={run_id}"
    click.echo(f"Queued {pipeline_name} run #{run_name} (ID {run_id})")
    click.echo(f"State: {state}")
    click.echo(f"Branch: {branch}")
    if parameters:
        click.echo(f"Parameters: {parameters}")
    click.echo(f"URL: {run_url}")
    return result


# ---------------------------------------------------------------------------
# CLI (click)
# ---------------------------------------------------------------------------

class AzdoContext:
    """Holds resolved config + overrides for all subcommands."""
    def __init__(self, cfg: dict, repo_override: str | None,
                 org_override: str | None = None, project_override: str | None = None):
        self.org: str = org_override or cfg["organization"]
        self.project: str = project_override or cfg["project"]
        self._aliases: dict[str, str] = cfg.get("repositories", {})
        self.repo: str = self._resolve_alias(repo_override or cfg.get("repository", ""))
        self.cfg = cfg

    def _resolve_alias(self, name: str) -> str:
        """Resolve a repo alias to its full name, or return as-is."""
        return self._aliases.get(name, name)

    def effective_repo(self, cmd_override: str | None = None) -> str:
        """Return the repo to use, with command-level override taking priority."""
        if cmd_override:
            return self._resolve_alias(cmd_override)
        return self.repo


pass_ctx = click.make_pass_decorator(AzdoContext)


@click.group()
@click.option("--config", "config_path", default=None, help="Path to config.json")
@click.option("--org", default=None, help="ADO organization (overrides config)")
@click.option("--project", default=None, help="ADO project (overrides config)")
@click.option("--repo", default=None, help="Repository name (overrides config)")
@click.pass_context
def cli(ctx, config_path: str | None, org: str | None, project: str | None, repo: str | None):
    """Azure DevOps PR & work-item helper for Claude Code."""
    cfg = load_config(config_path)
    ctx.ensure_object(dict)
    ctx.obj = AzdoContext(cfg, repo, org_override=org, project_override=project)


# --- PR commands -----------------------------------------------------------

@cli.command("list-comments")
@click.option("--repo", "cmd_repo", default=None, help="Repository name or alias (overrides config)")
@click.option("--pr", type=int, required=True, help="PR ID")
@pass_ctx
def cmd_list_comments(ctx: AzdoContext, cmd_repo: str | None, pr: int):
    """List active PR comment threads."""
    list_comments(ctx.org, ctx.project, ctx.effective_repo(cmd_repo), pr)


@cli.command("show-thread")
@click.option("--repo", "cmd_repo", default=None, help="Repository name or alias (overrides config)")
@click.option("--pr", type=int, required=True, help="PR ID")
@click.option("--thread", type=int, required=True, help="Thread ID")
@pass_ctx
def cmd_show_thread(ctx: AzdoContext, cmd_repo: str | None, pr: int, thread: int):
    """Show all comments in a thread."""
    show_thread(ctx.org, ctx.project, ctx.effective_repo(cmd_repo), pr, thread)


@cli.command("reply")
@click.option("--repo", "cmd_repo", default=None, help="Repository name or alias (overrides config)")
@click.option("--pr", type=int, required=True, help="PR ID")
@click.option("--thread", type=int, required=True, help="Thread ID")
@click.option("--comment", required=True, help="Comment text")
@pass_ctx
def cmd_reply(ctx: AzdoContext, cmd_repo: str | None, pr: int, thread: int, comment: str):
    """Reply to a PR comment thread."""
    reply_to_thread(ctx.org, ctx.project, ctx.effective_repo(cmd_repo), pr, thread, comment)


@cli.command("resolve")
@click.option("--repo", "cmd_repo", default=None, help="Repository name or alias (overrides config)")
@click.option("--pr", type=int, required=True, help="PR ID")
@click.option("--thread", type=int, required=True, help="Thread ID")
@pass_ctx
def cmd_resolve(ctx: AzdoContext, cmd_repo: str | None, pr: int, thread: int):
    """Resolve a PR comment thread."""
    resolve_thread(ctx.org, ctx.project, ctx.effective_repo(cmd_repo), pr, thread)


@cli.command("reply-and-resolve")
@click.option("--repo", "cmd_repo", default=None, help="Repository name or alias (overrides config)")
@click.option("--pr", type=int, required=True, help="PR ID")
@click.option("--thread", type=int, required=True, help="Thread ID")
@click.option("--comment", required=True, help="Comment text")
@pass_ctx
def cmd_reply_and_resolve(ctx: AzdoContext, cmd_repo: str | None, pr: int, thread: int, comment: str):
    """Reply to and resolve a thread in one step."""
    repo = ctx.effective_repo(cmd_repo)
    reply_to_thread(ctx.org, ctx.project, repo, pr, thread, comment)
    resolve_thread(ctx.org, ctx.project, repo, pr, thread)


@cli.command("create-task")
@click.option("--repo", "cmd_repo", default=None, help="Repository name or alias (overrides config)")
@click.option("--pr", type=int, required=True, help="PR ID")
@click.option("--parent", type=int, default=None, help="Parent work item ID")
@click.option("--description", default=None, help="Task description")
@pass_ctx
def cmd_create_task(ctx: AzdoContext, cmd_repo: str | None, pr: int, parent: int | None, description: str | None):
    """Create a Task work item linked to a PR."""
    create_task_for_pr(ctx.org, ctx.project, ctx.effective_repo(cmd_repo), pr, parent_id=parent, description=description)


# --- Work-item commands ----------------------------------------------------

@cli.command("create-work-item")
@click.option("--type", "wi_type", required=True, help="Work item type (Feature, User Story, Task, Bug)")
@click.option("--title", required=True, help="Title")
@click.option("--description", required=True, help="Description")
@click.option("--area-path", default=None, help="Area path")
@click.option("--assigned-to", default=None, help="Assignee email or display name")
@click.option("--parent", type=int, default=None, help="Parent work item ID")
@pass_ctx
def cmd_create_work_item(ctx: AzdoContext, wi_type: str, title: str, description: str,
                         area_path: str | None, assigned_to: str | None, parent: int | None):
    """Create a work item of any type."""
    area = area_path or ctx.cfg.get("defaultAreaPath")
    result = create_work_item(
        ctx.org, ctx.project, wi_type, title, description,
        area_path=area, assigned_to=assigned_to, parent_id=parent,
    )
    click.echo(f"Created {wi_type} {result['id']}")
    click.echo(f"URL: {result['_links']['html']['href']}")


@cli.command("get-work-item")
@click.option("--id", "wi_id", type=int, required=True, help="Work item ID")
@pass_ctx
def cmd_get_work_item(ctx: AzdoContext, wi_id: int):
    """Get work item details."""
    get_work_item(ctx.org, ctx.project, wi_id)


@cli.command("list-children")
@click.option("--id", "parent_id", type=int, required=True, help="Parent work item ID")
@pass_ctx
def cmd_list_children(ctx: AzdoContext, parent_id: int):
    """List child work items of a parent."""
    list_child_work_items(ctx.org, ctx.project, parent_id)


@cli.command("update-work-item")
@click.option("--id", "wi_id", type=int, required=True, help="Work item ID")
@click.option("--title", default=None, help="New title")
@click.option("--description", default=None, help="New description")
@pass_ctx
def cmd_update_work_item(ctx: AzdoContext, wi_id: int, title: str | None, description: str | None):
    """Update a work item's title or description."""
    update_work_item(ctx.org, ctx.project, wi_id, title=title, description=description)


# --- Pipeline commands -----------------------------------------------------

@cli.command("queue-pipeline")
@click.option("--id", "pipeline_id", type=int, required=True, help="Pipeline definition ID")
@click.option("--branch", required=True, help="Branch name (e.g. users/me/feature)")
@click.option("--parameters", "params", multiple=True,
              help="Template parameters as name=value (repeatable)")
@pass_ctx
def cmd_queue_pipeline(ctx: AzdoContext, pipeline_id: int, branch: str, params: tuple[str, ...]):
    """Queue (run) a pipeline on a specific branch."""
    parsed: dict[str, str] = {}
    for p in params:
        if "=" not in p:
            raise click.ClickException(f"Invalid parameter format '{p}' — expected name=value")
        k, v = p.split("=", 1)
        parsed[k] = v
    queue_pipeline(ctx.org, ctx.project, pipeline_id, branch, parameters=parsed or None)


# --- Registry commands -----------------------------------------------------

@cli.group("registry")
def registry_group():
    """Feature registry — manage tracked ADO features."""


@registry_group.command("list")
@pass_ctx
def cmd_registry_list(ctx: AzdoContext):
    """List all registered features."""
    registry = _get_registry(ctx.cfg)
    default_name = ctx.cfg.get("defaultFeature", "")
    if not registry:
        click.echo("No features registered.")
        return
    click.echo(f"{'Name':<20} {'ID':<12} {'Added':<14} Description")
    click.echo("-" * 80)
    for name, entry in sorted(registry.items()):
        marker = " *" if name == default_name else ""
        click.echo(
            f"{name + marker:<20} {entry['id']:<12} "
            f"{entry.get('added_at', 'N/A'):<14} {entry.get('description', '')}"
        )
    if default_name:
        click.echo(f"\n* = default feature ({default_name})")


@registry_group.command("add")
@click.option("--name", required=True, help="Short name for the feature")
@click.option("--id", "ado_id", type=int, required=True, help="ADO work item ID")
@click.option("--description", "desc", default="", help="Description")
@pass_ctx
def cmd_registry_add(ctx: AzdoContext, name: str, ado_id: int, desc: str):
    """Add a feature to the registry."""
    registry = _get_registry(ctx.cfg)
    if name in registry:
        raise click.ClickException(f"Feature '{name}' already exists. Remove it first.")
    registry[name] = {
        "id": ado_id,
        "description": desc,
        "added_at": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
    }
    ctx.cfg["features"] = registry
    ctx.cfg.pop("backlogFeatureId", None)
    if "defaultFeature" not in ctx.cfg:
        ctx.cfg["defaultFeature"] = name
    _save_config(ctx.cfg)
    click.echo(f"Added feature '{name}' (ID {ado_id})")


@registry_group.command("remove")
@click.option("--name", required=True, help="Feature name to remove")
@pass_ctx
def cmd_registry_remove(ctx: AzdoContext, name: str):
    """Remove a feature from the registry."""
    registry = _get_registry(ctx.cfg)
    if name not in registry:
        raise click.ClickException(f"Feature '{name}' not found.")
    if ctx.cfg.get("defaultFeature") == name:
        raise click.ClickException(
            f"'{name}' is the default feature. Use `registry set-default` to change it first."
        )
    del registry[name]
    ctx.cfg["features"] = registry
    ctx.cfg.pop("backlogFeatureId", None)
    _save_config(ctx.cfg)
    click.echo(f"Removed feature '{name}'")


@registry_group.command("set-default")
@click.option("--name", required=True, help="Feature name to set as default")
@pass_ctx
def cmd_registry_set_default(ctx: AzdoContext, name: str):
    """Set the default feature."""
    registry = _get_registry(ctx.cfg)
    if name not in registry:
        raise click.ClickException(f"Feature '{name}' not found in registry.")
    ctx.cfg["features"] = registry
    ctx.cfg["defaultFeature"] = name
    ctx.cfg.pop("backlogFeatureId", None)
    _save_config(ctx.cfg)
    click.echo(f"Default feature set to '{name}'")


@registry_group.command("status")
@pass_ctx
def cmd_registry_status(ctx: AzdoContext):
    """Fetch live ADO data for each registered feature."""
    registry = _get_registry(ctx.cfg)
    if not registry:
        click.echo("No features registered.")
        return
    for name, entry in sorted(registry.items()):
        ado_id = entry["id"]
        click.echo(f"\n{'=' * 60}")
        click.echo(f"Feature: {name} (ID {ado_id})")
        click.echo(f"{'=' * 60}")
        try:
            wi = _fetch_work_item(ctx.org, ctx.project, ado_id)
        except Exception as e:
            click.echo(f"  ERROR fetching: {e}")
            continue
        f = wi.get("fields", {})
        click.echo(f"  Title:    {f.get('System.Title', 'N/A')}")
        click.echo(f"  State:    {f.get('System.State', 'N/A')}")
        click.echo(f"  Created:  {f.get('System.CreatedDate', 'N/A')}")
        click.echo(f"  Changed:  {f.get('System.ChangedDate', 'N/A')}")
        # Fetch children for counts
        children = _fetch_children(ctx.org, ctx.project, ado_id)
        if children:
            counts: dict[str, int] = {}
            for item in children:
                wit = item.get("fields", {}).get("System.WorkItemType", "Unknown")
                counts[wit] = counts.get(wit, 0) + 1
            click.echo(f"  Children: {len(children)} total — " +
                        ", ".join(f"{c} {t}" for t, c in sorted(counts.items())))
        else:
            click.echo("  Children: 0")


# --- Marshal command -------------------------------------------------------

@cli.command("marshal-feature")
@click.option("--feature", required=True, help="Feature name (from registry) or ADO ID")
@pass_ctx
def cmd_marshal_feature(ctx: AzdoContext, feature: str):
    """Recursively fetch a feature's work item tree and write YAML IR."""
    name, entry = _resolve_feature(ctx.cfg, feature)
    ado_id = entry["id"]

    click.echo(f"Marshaling feature '{name}' (ID {ado_id})...")

    # Fetch the root feature work item
    root_wi = _fetch_work_item(ctx.org, ctx.project, ado_id)

    _LEAF_TYPES = {"Task", "Bug"}
    _item_count = 0

    def _build_node(wi: dict, depth: int = 0) -> dict:
        nonlocal _item_count
        _item_count += 1
        f = wi.get("fields", {})
        wi_type = f.get("System.WorkItemType", "Unknown")
        title = f.get("System.Title", "")
        click.echo(f"  {'  ' * depth}{wi_type} #{wi['id']}: {title}")
        node: dict = {
            "id": wi["id"],
            "type": wi_type,
            "title": title,
            "state": f.get("System.State", "Unknown"),
        }
        if wi_type not in _LEAF_TYPES:
            children = _fetch_children(ctx.org, ctx.project, wi["id"])
            if children:
                node["children"] = [_build_node(child, depth + 1) for child in children]
        return node

    root_node = _build_node(root_wi)

    ir = {
        "source": "ado",
        "marshaled_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "feature": root_node,
    }

    # Write to ir/ directory
    ir_dir = Path(__file__).parent / "ir"
    ir_dir.mkdir(exist_ok=True)
    ir_path = ir_dir / f"feature-{ado_id}.yaml"
    with open(ir_path, "w", encoding="utf-8") as f:
        yaml.dump(ir, f, default_flow_style=False, sort_keys=False, allow_unicode=True)

    # Print summary
    def _count_items(node: dict, counts: dict[str, dict[str, int]] | None = None) -> dict[str, dict[str, int]]:
        if counts is None:
            counts = {}
        wt = node.get("type", "Unknown")
        state = node.get("state", "Unknown")
        if wt not in counts:
            counts[wt] = {}
        counts[wt][state] = counts[wt].get(state, 0) + 1
        for child in node.get("children", []):
            _count_items(child, counts)
        return counts

    def _total(node: dict) -> int:
        return 1 + sum(_total(c) for c in node.get("children", []))

    total = _total(root_node)
    counts = _count_items(root_node)

    click.echo(f"\nWrote {ir_path}")
    click.echo(f"Feature: {root_node['title']}")
    click.echo(f"Total items: {total}")
    for wt, states in sorted(counts.items()):
        state_str = ", ".join(f"{s}: {n}" for s, n in sorted(states.items()))
        click.echo(f"  {wt}: {sum(states.values())} ({state_str})")


# --- Duckrow command -------------------------------------------------------

def _flatten_tree(node: dict, depth: int = 0) -> list[dict]:
    """Flatten a nested IR tree into a list with depth info (skips the root feature)."""
    items = []
    if depth > 0:  # skip the feature root itself
        items.append({**node, "_depth": depth})
    for child in node.get("children", []):
        items.extend(_flatten_tree(child, depth + 1))
    return items


def _format_item_line(item: dict, width: int = 120) -> str:
    """Format a work item as a single truncated line for fzf/display."""
    indent = "  " * (item.get("_depth", 1) - 1)
    prefix = f"{item['id']:<10} {item.get('type', ''):<13} {item.get('state', ''):<8}"
    title_budget = width - len(prefix) - len(indent)
    title = item.get("title", "")
    if len(title) > title_budget:
        title = title[: title_budget - 3] + "..."
    return f"{prefix}{indent}{title}"


def _fzf_multiselect(lines: list[str], prompt: str = "Select> ") -> list[str]:
    """Pipe lines through fzf -m and return selected lines."""
    fzf_path = shutil.which("fzf")
    if not fzf_path:
        raise click.ClickException("fzf not found on PATH. Install via scoop: scoop install fzf")
    proc = subprocess.run(
        [fzf_path, "-m", "--prompt", prompt, "--height", "40%", "--reverse"],
        input="\n".join(lines),
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        return []  # user cancelled
    return [line for line in proc.stdout.strip().splitlines() if line]


@cli.command("duckrow")
@click.option("-f", "filter_features", is_flag=True, default=False,
              help="Pre-filter features via fzf multiselect")
@pass_ctx
def cmd_duckrow(ctx: AzdoContext, filter_features: bool):
    """List all work items under registered features. Use -f to pick features interactively."""
    registry = _get_registry(ctx.cfg)
    if not registry:
        raise click.ClickException("No features registered.")

    # Determine which features to include
    if filter_features:
        feature_lines = [
            f"{name:<20} {entry['id']:<10} {entry.get('description', '')}"
            for name, entry in sorted(registry.items())
        ]
        selected = _fzf_multiselect(feature_lines, prompt="Features> ")
        if not selected:
            click.echo("No features selected.")
            return
        selected_names = {line.split()[0] for line in selected}
        registry = {k: v for k, v in registry.items() if k in selected_names}

    # Collect items from all selected features
    all_items: list[dict] = []
    for name, entry in sorted(registry.items()):
        ado_id = entry["id"]
        ir_path = Path(__file__).parent / "ir" / f"feature-{ado_id}.yaml"
        if ir_path.exists():
            with open(ir_path, encoding="utf-8") as f:
                ir = yaml.safe_load(f)
            root = ir.get("feature", {})
            click.echo(f"[{name}] {root.get('title', f'Feature {ado_id}')} (from IR)")
        else:
            click.echo(f"[{name}] Fetching feature {ado_id} from ADO...")
            root_wi = _fetch_work_item(ctx.org, ctx.project, ado_id)
            # Build tree inline
            _LEAF_TYPES = {"Task", "Bug"}

            def _build(wi: dict) -> dict:
                fld = wi.get("fields", {})
                wi_type = fld.get("System.WorkItemType", "Unknown")
                nd = {
                    "id": wi["id"],
                    "type": wi_type,
                    "title": fld.get("System.Title", ""),
                    "state": fld.get("System.State", "Unknown"),
                }
                if wi_type not in _LEAF_TYPES:
                    children = _fetch_children(ctx.org, ctx.project, wi["id"])
                    if children:
                        nd["children"] = [_build(c) for c in children]
                return nd

            root = _build(root_wi)

        items = _flatten_tree(root)
        all_items.extend(items)

    if not all_items:
        click.echo("No work items found.")
        return

    # Format lines for fzf selection
    try:
        width = os.get_terminal_size().columns
    except OSError:
        width = 120
    item_lines = [_format_item_line(item, width) for item in all_items]

    # Let user pick work items via fzf multi-select
    selected_lines = _fzf_multiselect(item_lines, prompt="Work items> ")
    if not selected_lines:
        click.echo("No work items selected.")
        return

    click.echo(f"\n{len(selected_lines)} work item(s) selected:")
    for line in selected_lines:
        click.echo(f"  {line}")

    # Ask user what they want to do with the selected items
    click.echo()
    user_prompt = click.prompt("What would you like to do with these work items?")
    if not user_prompt.strip():
        click.echo("No action specified.")
        return

    # Build the full prompt for Claude
    items_block = "\n".join(selected_lines)
    full_prompt = (
        f"Use the /azdo skill to work with the following Azure DevOps work items.\n"
        f"\n"
        f"Work items:\n"
        f"```\n{items_block}\n```\n"
        f"\n"
        f"The ID is the first column of each line. The type is the second column. "
        f"The state is the third column. The rest is the title.\n"
        f"\n"
        f"User request: {user_prompt}\n"
        f"\n"
        f"Use the /azdo skill's edit-item, move-item, and other commands as needed "
        f"to accomplish the user's request. Work through the items methodically."
    )

    # Spawn Claude with --dangerously-skip-permissions
    claude_path = shutil.which("claude")
    if not claude_path:
        raise click.ClickException("claude CLI not found on PATH.")

    click.echo(f"\nLaunching Claude to handle your request...")
    subprocess.run(
        [claude_path, "--dangerously-skip-permissions", "-p", full_prompt],
    )


# ---------------------------------------------------------------------------

if __name__ == "__main__":
    cli()
