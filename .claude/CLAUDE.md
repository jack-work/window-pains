# Personal Claude Code Configuration

## Git Worktree Conventions (PowerApps-Orchard)

The Orchard repo uses a bare repo layout at `~/dev/orchard/`. All worktrees are sibling directories under that root.

### Rules

- **Read `~/dev/orchard/WORKTREES.md` first** when working with this repo to understand what worktrees exist and what they're for.
- **Update `WORKTREES.md`** after creating or removing a worktree — this is the live manifest.
- **Never commit directly in `main/`** — it stays clean. Only `git pull` in it.
- **Name worktrees by purpose** (e.g., `httpyac-fixes/`), not by branch name.
- **Worktrees are cheap** (~2s to create). Prefer create/destroy over long-lived worktrees.
- **Before removing a worktree**, always check for uncommitted changes: `git -C <dir> status --short`
- **Use `~/dev/orchard/worktree.sh`** to create/remove worktrees — it keeps the manifest in sync.
- **Launch Claude from inside the worktree**, not the bare root (e.g., `cd ~/dev/orchard/main && claude`).

### Creating a Worktree

```bash
cd ~/dev/orchard

# From an existing remote branch:
./worktree.sh add <name> <branch>

# New branch from main:
./worktree.sh add-new <name> <branch>
```

### Removing a Worktree

```bash
cd ~/dev/orchard
./worktree.sh remove <name>
```

### Quick Reference

```bash
./worktree.sh list       # show all worktrees + manifest
./worktree.sh status     # check for uncommitted changes everywhere
```
