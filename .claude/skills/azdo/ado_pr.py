#!/usr/bin/env python3
"""Azure DevOps PR helper script for Claude Code."""

import subprocess
import json
import sys
import argparse
from urllib.request import Request, urlopen
from urllib.error import HTTPError

ADO_RESOURCE = "499b84ac-1321-427f-aa17-267ca6975798"

# Claude Code attribution prefix for all comments
CLAUDE_CODE_SIGNATURE = "\n\n---\n*This comment was posted by [Claude Code](https://claude.ai/claude-code) on behalf of the PR author.*"

def find_az_cli():
    """Find the az CLI executable."""
    import shutil
    import os

    # Try common locations
    candidates = [
        shutil.which("az"),
        r"C:\Program Files (x86)\Microsoft SDKs\Azure\CLI2\wbin\az.cmd",
        r"C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd",
        os.path.expanduser("~\\scoop\\apps\\azure-cli\\current\\bin\\az.cmd"),
    ]

    for candidate in candidates:
        if candidate and os.path.exists(candidate):
            return candidate

    raise RuntimeError("az CLI not found. Please install Azure CLI.")

def get_token():
    """Get Azure access token using az CLI."""
    az_path = find_az_cli()
    result = subprocess.run(
        [az_path, "account", "get-access-token", "--resource", ADO_RESOURCE, "--query", "accessToken", "-o", "tsv"],
        capture_output=True, text=True, shell=True
    )
    if result.returncode != 0:
        raise RuntimeError(f"Failed to get token: {result.stderr}")
    return result.stdout.strip()

def make_request(url, method="GET", data=None):
    """Make authenticated request to ADO API."""
    token = get_token()
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    req = Request(url, method=method, headers=headers)
    if data:
        req.data = json.dumps(data).encode('utf-8')
    try:
        with urlopen(req) as response:
            return json.loads(response.read().decode('utf-8'))
    except HTTPError as e:
        error_body = e.read().decode('utf-8') if e.fp else str(e)
        raise RuntimeError(f"HTTP {e.code}: {error_body}")

def get_threads(org, project, repo, pr_id, active_only=True):
    """Get PR comment threads."""
    url = f"https://dev.azure.com/{org}/{project}/_apis/git/repositories/{repo}/pullrequests/{pr_id}/threads?api-version=7.1"
    response = make_request(url)
    threads = response.get("value", [])

    if active_only:
        threads = [t for t in threads if t.get("status") not in ("fixed", "closed") and not t.get("isDeleted")]

    return threads

def list_comments(org, project, repo, pr_id):
    """List active PR comments."""
    threads = get_threads(org, project, repo, pr_id, active_only=True)

    results = []
    for thread in threads:
        human_comments = [c for c in thread.get("comments", [])
                         if c.get("author", {}).get("displayName") != "Microsoft.VisualStudio.Services.TFS"
                         and c.get("commentType") != "system"]
        if human_comments:
            ctx = thread.get("threadContext") or {}
            results.append({
                "thread_id": thread["id"],
                "status": thread.get("status"),
                "file_path": ctx.get("filePath"),
                "line": (ctx.get("rightFileStart") or {}).get("line"),
                "content": human_comments[0].get("content", "")[:150]
            })

    # Print as table
    print(f"{'Thread ID':<12} {'Status':<10} {'File':<50} {'Line':<6} Content")
    print("-" * 120)
    for r in sorted(results, key=lambda x: x.get("line") or 0):
        file_path = (r["file_path"] or "")[:48]
        content = r["content"].replace("\n", " ")[:50]
        print(f"{r['thread_id']:<12} {r['status'] or '':<10} {file_path:<50} {r['line'] or '':<6} {content}")

def show_thread(org, project, repo, pr_id, thread_id):
    """Show all comments in a thread."""
    threads = get_threads(org, project, repo, pr_id, active_only=False)
    for thread in threads:
        if thread["id"] == thread_id:
            ctx = thread.get("threadContext") or {}
            print(f"Thread {thread_id} (status: {thread.get('status', 'unknown')})")
            print(f"File: {ctx.get('filePath', 'N/A')}")
            print(f"Line: {(ctx.get('rightFileStart') or {}).get('line', 'N/A')}")
            print("-" * 80)
            for c in thread.get("comments", []):
                if not c.get("isDeleted"):
                    author = c.get("author", {}).get("displayName", "unknown")
                    print(f"\n[{author}]:")
                    print(c.get("content", ""))
            return
    print(f"Thread {thread_id} not found")

def reply_to_thread(org, project, repo, pr_id, thread_id, comment):
    """Reply to a PR comment thread with Claude Code attribution."""
    url = f"https://dev.azure.com/{org}/{project}/_apis/git/repositories/{repo}/pullrequests/{pr_id}/threads/{thread_id}/comments?api-version=7.1"
    # Add Claude Code signature to all comments
    comment_with_signature = comment + CLAUDE_CODE_SIGNATURE
    data = {"content": comment_with_signature, "commentType": 1}
    result = make_request(url, method="POST", data=data)
    print(f"Replied to thread {thread_id}")
    return result

def resolve_thread(org, project, repo, pr_id, thread_id):
    """Resolve a PR comment thread."""
    url = f"https://dev.azure.com/{org}/{project}/_apis/git/repositories/{repo}/pullrequests/{pr_id}/threads/{thread_id}?api-version=7.1"
    data = {"status": "fixed"}
    result = make_request(url, method="PATCH", data=data)
    print(f"Resolved thread {thread_id}")
    return result

def reply_and_resolve(org, project, repo, pr_id, thread_id, comment):
    """Reply to and resolve a PR comment thread."""
    reply_to_thread(org, project, repo, pr_id, thread_id, comment)
    resolve_thread(org, project, repo, pr_id, thread_id)

def get_pr_details(org, project, repo, pr_id):
    """Get PR details including title and description."""
    url = f"https://dev.azure.com/{org}/{project}/_apis/git/repositories/{repo}/pullrequests/{pr_id}?api-version=7.1"
    return make_request(url)

def get_project_id(org, project):
    """Get the project GUID."""
    url = f"https://dev.azure.com/{org}/_apis/projects/{project}?api-version=7.1"
    result = make_request(url)
    return result["id"]

def create_work_item(org, project, work_item_type, title, description, pr_link=None, area_path=None, assigned_to=None, parent_id=None):
    """Create a work item (Task, Bug, etc.) optionally linked to a PR.

    Args:
        org: ADO organization
        project: ADO project name
        work_item_type: Type of work item (Task, Bug, User Story, Feature, etc.)
        title: Work item title
        description: Work item description
        pr_link: Optional dict with 'project_id', 'repo_id', 'pr_id' to link to a PR
        area_path: Optional area path (e.g., "OneAgile\\PowerApps\\Developer Agents\\Orchard")
        assigned_to: Optional user email or display name to assign the work item to
        parent_id: Optional parent work item ID to create hierarchy

    Returns:
        Created work item dict
    """
    from urllib.parse import quote
    # URL-encode the work item type to handle spaces (e.g., "User Story" -> "User%20Story")
    work_item_type_encoded = quote(work_item_type)
    url = f"https://dev.azure.com/{org}/{project}/_apis/wit/workitems/${work_item_type_encoded}?api-version=7.1"

    operations = [
        {"op": "add", "path": "/fields/System.Title", "value": title},
        {"op": "add", "path": "/fields/System.Description", "value": description},
    ]

    if area_path:
        operations.append({"op": "add", "path": "/fields/System.AreaPath", "value": area_path})

    if assigned_to:
        operations.append({"op": "add", "path": "/fields/System.AssignedTo", "value": assigned_to})

    if parent_id:
        # Link to parent work item using System.LinkTypes.Hierarchy-Reverse
        operations.append({
            "op": "add",
            "path": "/relations/-",
            "value": {
                "rel": "System.LinkTypes.Hierarchy-Reverse",
                "url": f"https://dev.azure.com/{org}/{project}/_apis/wit/workItems/{parent_id}",
                "attributes": {"comment": "Parent link"}
            }
        })

    if pr_link:
        # IMPORTANT: Use %2F (URL-encoded slash) between project_id, repo_id, and pr_id
        # Regular slashes will NOT work - the PR won't recognize the link
        artifact_link = f"vstfs:///Git/PullRequestId/{pr_link['project_id']}%2F{pr_link['repo_id']}%2F{pr_link['pr_id']}"
        operations.append({
            "op": "add",
            "path": "/relations/-",
            "value": {
                "rel": "ArtifactLink",
                "url": artifact_link,
                "attributes": {"name": "Pull Request"}
            }
        })

    # Work items use JSON Patch format
    token = get_token()
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json-patch+json"
    }
    req = Request(url, method="POST", headers=headers)
    req.data = json.dumps(operations).encode('utf-8')

    try:
        with urlopen(req) as response:
            return json.loads(response.read().decode('utf-8'))
    except HTTPError as e:
        error_body = e.read().decode('utf-8') if e.fp else str(e)
        raise RuntimeError(f"HTTP {e.code}: {error_body}")

def get_work_item(org, project, work_item_id):
    """Get details of a work item by ID."""
    url = f"https://dev.azure.com/{org}/{project}/_apis/wit/workitems/{work_item_id}?$expand=relations&api-version=7.1"
    result = make_request(url)

    fields = result.get("fields", {})
    print(f"Work Item {work_item_id}")
    print(f"Type: {fields.get('System.WorkItemType', 'N/A')}")
    print(f"Title: {fields.get('System.Title', 'N/A')}")
    print(f"State: {fields.get('System.State', 'N/A')}")
    print(f"Area Path: {fields.get('System.AreaPath', 'N/A')}")
    print(f"Assigned To: {fields.get('System.AssignedTo', {}).get('displayName', 'Unassigned')}")
    print(f"URL: {result['_links']['html']['href']}")
    print("-" * 80)
    print("Description:")
    print(fields.get("System.Description", "No description"))

    return result


def list_child_work_items(org, project, parent_id):
    """List child work items of a parent."""
    # Use WIQL to query child work items
    url = f"https://dev.azure.com/{org}/{project}/_apis/wit/wiql?api-version=7.1"
    wiql = {
        "query": f"SELECT [System.Id], [System.Title], [System.WorkItemType], [System.State] FROM WorkItemLinks WHERE ([Source].[System.Id] = {parent_id}) AND ([System.Links.LinkType] = 'System.LinkTypes.Hierarchy-Forward') MODE (MustContain)"
    }

    token = get_token()
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    req = Request(url, method="POST", headers=headers)
    req.data = json.dumps(wiql).encode('utf-8')

    try:
        with urlopen(req) as response:
            result = json.loads(response.read().decode('utf-8'))
    except HTTPError as e:
        error_body = e.read().decode('utf-8') if e.fp else str(e)
        raise RuntimeError(f"HTTP {e.code}: {error_body}")

    # Get the child work item IDs (target of links)
    child_ids = [link["target"]["id"] for link in result.get("workItemRelations", []) if link.get("target")]

    if not child_ids:
        print(f"No child work items found for {parent_id}")
        return []

    # Batch get work item details
    ids_str = ",".join(str(id) for id in child_ids)
    details_url = f"https://dev.azure.com/{org}/{project}/_apis/wit/workitems?ids={ids_str}&api-version=7.1"
    details = make_request(details_url)

    print(f"Child work items of {parent_id}:")
    print(f"{'ID':<10} {'Type':<15} {'State':<12} Title")
    print("-" * 80)

    for item in details.get("value", []):
        fields = item.get("fields", {})
        print(f"{item['id']:<10} {fields.get('System.WorkItemType', ''):<15} {fields.get('System.State', ''):<12} {fields.get('System.Title', '')}")

    return details.get("value", [])


def create_work_item_cli(org, project, work_item_type, title, description, area_path=None, assigned_to=None, parent_id=None):
    """CLI wrapper for creating a work item."""
    result = create_work_item(org, project, work_item_type, title, description,
                              area_path=area_path, assigned_to=assigned_to, parent_id=parent_id)
    work_item_id = result["id"]
    work_item_url = result["_links"]["html"]["href"]

    print(f"Created {work_item_type} {work_item_id}")
    print(f"URL: {work_item_url}")
    return result


def update_work_item(org, project, work_item_id, title=None, description=None):
    """Update an existing work item's title and/or description."""
    url = f"https://dev.azure.com/{org}/{project}/_apis/wit/workitems/{work_item_id}?api-version=7.1"

    operations = []
    if title:
        operations.append({"op": "replace", "path": "/fields/System.Title", "value": title})
    if description:
        operations.append({"op": "replace", "path": "/fields/System.Description", "value": description})

    if not operations:
        print("No updates specified")
        return None

    token = get_token()
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json-patch+json"
    }
    req = Request(url, method="PATCH", headers=headers)
    req.data = json.dumps(operations).encode('utf-8')

    try:
        with urlopen(req) as response:
            result = json.loads(response.read().decode('utf-8'))
            print(f"Updated work item {work_item_id}")
            print(f"URL: {result['_links']['html']['href']}")
            return result
    except HTTPError as e:
        error_body = e.read().decode('utf-8') if e.fp else str(e)
        raise RuntimeError(f"HTTP {e.code}: {error_body}")


def create_task_for_pr(org, project, repo, pr_id):
    """Create a Task work item linked to a PR, using PR title/description."""
    # Get PR details
    pr = get_pr_details(org, project, repo, pr_id)
    title = pr.get("title", f"PR {pr_id}")
    description = pr.get("description", title)
    repo_id = pr.get("repository", {}).get("id")

    if not repo_id:
        raise RuntimeError("Could not get repository ID from PR")

    # Get project ID for artifact link
    project_id = get_project_id(org, project)

    pr_link = {
        "project_id": project_id,
        "repo_id": repo_id,
        "pr_id": pr_id
    }

    result = create_work_item(org, project, "Task", title, description, pr_link)
    work_item_id = result["id"]
    work_item_url = result["_links"]["html"]["href"]

    print(f"Created Task {work_item_id} linked to PR {pr_id}")
    print(f"URL: {work_item_url}")
    return result

def main():
    parser = argparse.ArgumentParser(description="Azure DevOps PR helper")
    parser.add_argument("--org", default="msazure", help="ADO organization")
    parser.add_argument("--project", default="OneAgile", help="ADO project")
    parser.add_argument("--repo", default="PowerApps-Orchard", help="Repository name")
    parser.add_argument("--pr", type=int, help="PR ID (required for PR-related commands)")

    subparsers = parser.add_subparsers(dest="command", required=True)

    # list-comments
    subparsers.add_parser("list-comments", help="List active PR comments")

    # show-thread
    show_parser = subparsers.add_parser("show-thread", help="Show all comments in a thread")
    show_parser.add_argument("--thread", type=int, required=True, help="Thread ID")

    # reply
    reply_parser = subparsers.add_parser("reply", help="Reply to a thread")
    reply_parser.add_argument("--thread", type=int, required=True, help="Thread ID")
    reply_parser.add_argument("--comment", required=True, help="Comment text")

    # resolve
    resolve_parser = subparsers.add_parser("resolve", help="Resolve a thread")
    resolve_parser.add_argument("--thread", type=int, required=True, help="Thread ID")

    # reply-and-resolve
    rar_parser = subparsers.add_parser("reply-and-resolve", help="Reply and resolve a thread")
    rar_parser.add_argument("--thread", type=int, required=True, help="Thread ID")
    rar_parser.add_argument("--comment", required=True, help="Comment text")

    # create-task - create a Task work item linked to the PR
    subparsers.add_parser("create-task", help="Create a Task work item linked to the PR")

    # create-work-item - create any type of work item with full options
    wi_parser = subparsers.add_parser("create-work-item", help="Create a work item (Feature, User Story, Task, Bug)")
    wi_parser.add_argument("--type", required=True, help="Work item type (Feature, User Story, Task, Bug)")
    wi_parser.add_argument("--title", required=True, help="Work item title")
    wi_parser.add_argument("--description", required=True, help="Work item description")
    wi_parser.add_argument("--area-path", help="Area path (e.g., 'OneAgile\\PowerApps\\Developer Agents\\Orchard')")
    wi_parser.add_argument("--assigned-to", help="User to assign the work item to")
    wi_parser.add_argument("--parent", type=int, help="Parent work item ID")

    # get-work-item - get details of a work item
    get_wi_parser = subparsers.add_parser("get-work-item", help="Get work item details")
    get_wi_parser.add_argument("--id", type=int, required=True, help="Work item ID")

    # list-children - list child work items
    list_children_parser = subparsers.add_parser("list-children", help="List child work items of a parent")
    list_children_parser.add_argument("--id", type=int, required=True, help="Parent work item ID")

    # update-work-item - update an existing work item
    update_wi_parser = subparsers.add_parser("update-work-item", help="Update a work item's title or description")
    update_wi_parser.add_argument("--id", type=int, required=True, help="Work item ID to update")
    update_wi_parser.add_argument("--title", help="New title")
    update_wi_parser.add_argument("--description", help="New description")

    args = parser.parse_args()

    # Commands that require --pr
    pr_required_commands = ["list-comments", "show-thread", "reply", "resolve", "reply-and-resolve", "create-task"]
    if args.command in pr_required_commands and not args.pr:
        parser.error(f"--pr is required for {args.command} command")

    try:
        if args.command == "list-comments":
            list_comments(args.org, args.project, args.repo, args.pr)
        elif args.command == "show-thread":
            show_thread(args.org, args.project, args.repo, args.pr, args.thread)
        elif args.command == "reply":
            reply_to_thread(args.org, args.project, args.repo, args.pr, args.thread, args.comment)
        elif args.command == "resolve":
            resolve_thread(args.org, args.project, args.repo, args.pr, args.thread)
        elif args.command == "reply-and-resolve":
            reply_and_resolve(args.org, args.project, args.repo, args.pr, args.thread, args.comment)
        elif args.command == "create-task":
            create_task_for_pr(args.org, args.project, args.repo, args.pr)
        elif args.command == "create-work-item":
            create_work_item_cli(args.org, args.project, args.type, args.title, args.description,
                                 area_path=args.area_path, assigned_to=args.assigned_to, parent_id=args.parent)
        elif args.command == "get-work-item":
            get_work_item(args.org, args.project, args.id)
        elif args.command == "list-children":
            list_child_work_items(args.org, args.project, args.id)
        elif args.command == "update-work-item":
            update_work_item(args.org, args.project, args.id, title=args.title, description=args.description)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
