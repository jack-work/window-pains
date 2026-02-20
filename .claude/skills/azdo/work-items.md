# Work Item Management

Work item tracking is a **primary feature** of this skill. Use it to:

- Create work items linked to PRs (mandatory — see [pr-review.md](pr-review.md))
- Query and navigate the work item hierarchy
- Find appropriate parent items for new work
- Track features via the **feature registry**
- Marshal feature trees into YAML IR for planning

## Feature Registry

The config file maintains a **feature registry** — a named map of ADO Feature work items the team actively tracks. Each entry has:

- **name** — short identifier (e.g., `backlog`, `auth-rewrite`)
- **id** — ADO work item ID (integer)
- **description** — human-readable purpose
- **added_at** — date the entry was created

One feature is marked as `defaultFeature` — the fallback for orphan work items.

### Registry CLI

```bash
uv run ado_pr.py registry list                          # show all features
uv run ado_pr.py registry add --name NAME --id ID       # add a feature
uv run ado_pr.py registry remove --name NAME            # remove (can't be default)
uv run ado_pr.py registry set-default --name NAME       # change the default
uv run ado_pr.py registry status                        # live ADO data for each feature
```

## Finding the Right Parent

When a work item has no obvious parent:

1. Check the **feature registry** — use the default feature as a catch-all.
2. Use `list-children --id <feature_id>` to see existing User Stories.
3. If an existing User Story fits, create the Task under it.
4. If not, create a new User Story under the feature, then create the Task under that.

## Marshal (Feature Tree Snapshot)

The `marshal-feature` command recursively pulls a feature's full work item tree from ADO and writes it to a YAML file in the `ir/` directory.

```bash
uv run ado_pr.py marshal-feature --feature backlog       # by registry name
uv run ado_pr.py marshal-feature --feature 36649440      # by raw ADO ID
```

Output: `ir/feature-<id>.yaml` containing the full tree with types, states, and titles.

## Duckrow (Ducks-in-a-Row)

**Trigger**: The user says "duckrow" (or "ducks in a row", "organize feature", etc.)

**Agent behavior** — follow this script:

1. Read the feature registry from config (`registry list`).
2. Ask the user which feature to organize (present the registry list).
3. Ask if the user wants to include any specific work item IDs (accept only explicit integer IDs — no search).
4. Run `marshal-feature --feature <name>` to pull the closure into YAML IR.
5. If the user provided extra IDs, fetch those with `get-work-item` and note them as unparented items for the user to place during the organize phase.
6. Show the IR summary to the user (feature title, total items, counts by type and state).
7. (Future: enter organize phase — restructure the tree interactively.)

## Registry Cleanup

**Trigger**: The user says "registry cleanup" (or "clean up features", "audit registry", etc.)

**Agent behavior** — follow this script:

1. Run `registry status` to fetch live ADO metrics for each feature.
2. Present the results: which features are active/stale, child counts, ages.
3. Recommend actions: remove dead features, add missing ones.
4. Wait for user confirmation before making any changes.

## Area Path

New work items automatically get `defaultAreaPath` from config unless overridden with `--area-path`.

## Work Item Hierarchy

```
Feature
└── User Story
    └── Task
    └── Bug
```

## Always Announce Created Work Items

When creating work items, ALWAYS output the work item ID and URL:
```
Created Task 12345
URL: https://dev.azure.com/<org>/<project>/_workitems/edit/12345
```

## Work Item Types with Spaces

Work item types containing spaces (e.g., "User Story") are URL-encoded automatically by the CLI.
