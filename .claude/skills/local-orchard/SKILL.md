---
name: local-orchard
description: Set up and test against a local Orchard service. Dynamically discovers orchard repo location, reads documentation from source, and configures Developer Agents for local testing.
---

# Local Orchard Testing

This skill helps you run and test against a local Orchard (PowerApps sandbox) service. Rather than duplicating documentation, it discovers the orchard repo on disk and reads instructions directly from the source.

## Self-Updating

If you discover these instructions are incomplete or incorrect, **update this file** at `~/.claude/skills/local-orchard/SKILL.md`.

## How It Works

Developer Agents uses the standard cluster-category config pattern. When `CS_CLUSTERCATEGORY=local` (the default for local development), the Orchard URL automatically resolves to:

```
https://forintracommuseonly.localhost:50772
```

**No special configuration needed** - just run local Orchard and it works.

## Step 1: Discover Orchard Repo Location

First, find if the orchard repo is already cloned locally. Check common developer source directories:

```bash
# Check common locations
for dir in ~/dev ~/src ~/repos ~/code ~/projects; do
  if [ -d "$dir/orc" ] || [ -d "$dir/PowerApps-Orchard" ] || [ -d "$dir/orchard" ]; then
    echo "Found in: $dir"
    ls -la "$dir"/orc* "$dir"/PowerApps-Orchard* "$dir"/orchard* 2>/dev/null
  fi
done
```

**If not found**, ask the user:
1. Do you have the PowerApps-Orchard repo cloned locally?
2. If yes, what is the path?
3. If no, would you like to clone it? (Requires Azure DevOps access to `msazure/OneAgile/_git/PowerApps-Orchard`)

## Step 2: Verify and Update Repo

Once you have the orchard repo path, verify it's valid and optionally update:

```bash
ORCHARD_PATH="<path-to-orchard-repo>"

# Verify it's a valid git repo
cd "$ORCHARD_PATH"
git status

# Check current branch
git branch --show-current

# If user consents, pull latest from main
git fetch origin main
git checkout main
git pull origin main
```

**Always ask for consent** before pulling or checking out branches.

## Step 3: Read Documentation from Orchard Repo

The orchard repo contains authoritative documentation. Read these files for setup instructions:

- `$ORCHARD_PATH/README.md` - Main setup and prerequisites
- `$ORCHARD_PATH/eng/http/README.md` - HTTP testing setup
- `$ORCHARD_PATH/docs/` - Additional documentation

**Do NOT duplicate information** from these files. Instead, point users to them or read them dynamically.

### Key Files to Reference:

| File | Purpose |
|------|---------|
| `README.md` | Build instructions, prerequisites, permissions |
| `eng/http/README.md` | HTTP testing with httpyac/REST Client |
| `eng/http/http-client.env.json` | Environment configuration |
| `eng/http/Get-Token.ps1` | Token acquisition script |
| `src/Orchard/Orchard.Service/Properties/launchSettings.json` | Local URLs |

## Step 4: Run Orchard Locally

From the orchard repo:

```bash
cd "$ORCHARD_PATH"

# Build
dotnet restore
dotnet build dirs.proj

# Run the service
dotnet run --project src/Orchard/Orchard.Service
```

The service runs at: `https://forintracommuseonly.localhost:50772`

## Step 5: Get Authentication Token

### CRITICAL: Token acquisition rules

1. **ALWAYS use `-Environment test`** (or omit it — `test` is the default). The underlying TokensUtil **only accepts `test` or `prod`**. Passing `local` or `dev` WILL fail.
2. **A `test` token works everywhere**: local, dev, test, and preprod. There is no need for a separate "local" token.
3. **Prod tokens CANNOT be acquired via this script** with `@microsoft.com` accounts. For prod, the user must copy a Bearer token manually from browser DevTools.
4. **The script writes the token to ALL environments** in `http-client.private.env.json` automatically.

### Running the script

```powershell
cd "$ORCHARD_PATH/eng/http"
.\Get-Token.ps1
```

That's it. No flags needed — it defaults to `-Environment test`.

### If the script is run from a worktree

The token file (`http-client.private.env.json`) is written relative to where the script lives. If you're working in a git worktree and the script lives in the main worktree, the token file will be written there — not in your current worktree. Either:
- Copy the token file to your worktree's `eng/http/` directory after running the script, OR
- Run the script from the worktree's own `eng/http/Get-Token.ps1` if available

### Troubleshooting token acquisition

**Do NOT give up on token acquisition.** The script is reliable. If it fails, it's almost certainly one of these:

| Error | Cause | Fix |
|-------|-------|-----|
| `Environment must be either 'test' or 'prod'` | You passed `-Environment local` or `-Environment dev` | Use `-Environment test` (or omit the flag entirely) |
| `Failed to extract token from output` with same error | Same — invalid environment passed | Same fix: use `test` |
| Browser auth window doesn't appear | Cached credentials may be stale | Try `-Username` with the user's email |
| `Project path not found` | Script can't find TokensUtil | Pass `-ProjectPath` pointing to `src/Tools/TokensUtil` |
| `Access denied` / auth errors | User lacks permissions to the Aurora test tenant | Ask the user to verify they have access to `capintegration01.onmicrosoft.com` tenant. They may need to request access. |
| Token expired during testing | Tokens expire after ~1 hour | Re-run the script |

**If none of the above apply**, ask the user what error they see and update this skill with the resolution.

## Step 6: Run Developer Agents

Simply run the dev server - no special configuration needed:

```bash
cd ~/dev/PowerPlatform-Developer-Agents
bun run dev
```

Since `CS_CLUSTERCATEGORY` defaults to `local`, the orchestrator automatically uses your local Orchard instance.

### Verify the Connection

Check the server logs - you should see requests to:
```
https://forintracommuseonly.localhost:50772/api/harvest/container-sessions
```

## Step 7: Test with HTTP Files

You can also test Orchard directly with HTTP files:

```bash
cd "$ORCHARD_PATH/eng/http"
httpyac send container-session/create-session.http -e local --all
```

## Using Azure DevOps for Repo Info

If you need to reference the orchard repo in Azure DevOps (e.g., to check branches, PRs, or documentation):

Use the `/azdo` skill to interact with Azure DevOps:
- Organization: `msazure`
- Project: `OneAgile`
- Repo: `PowerApps-Orchard`

Example: Check recent commits or PRs affecting a specific file.

## Configuration Pattern

The orchestrator follows this pattern for service URLs:

```
CS_CLUSTERCATEGORY (local/dev/test/prod/gov/...)
    ↓
getHarvestBaseUrl(environment)
    ↓
switch (category) {
  case 'local': return LOCAL_ORCHARD_URL;  // <-- Your local instance
  case 'test':  return computed test URL;
  case 'prod':  return computed prod URL;
  // ... sovereign clouds
}
```

## Troubleshooting

### Port already in use
```bash
# Find and kill existing process
lsof -i :50772
kill <PID>
```

### Certificate errors
Run `init.cmd` from the orchard repo root (elevated prompt on Windows).

### 401 Unauthorized
Token expired. Re-run `Get-Token.ps1` (no flags needed — defaults to test).

### Requests going to remote Orchard
Check that `CS_CLUSTERCATEGORY` is `local` (or unset, which defaults to `local`):
```bash
echo $CS_CLUSTERCATEGORY  # Should be empty or 'local'
```

## Quick Reference

| Item | Value |
|------|-------|
| Local Orchard URL | `https://forintracommuseonly.localhost:50772` |
| Cluster Category | `local` (default) |
| Token Script | `$ORCHARD_PATH/eng/http/Get-Token.ps1` (always use `-Environment test` or omit) |
| HTTP Tests | `$ORCHARD_PATH/eng/http/container-session/` |
| Create Session Endpoint | `POST /api/harvest/container-sessions` |
