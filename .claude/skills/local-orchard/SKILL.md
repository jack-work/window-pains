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

Use the token acquisition script in the orchard repo:

```powershell
cd "$ORCHARD_PATH/eng/http"
.\Get-Token.ps1 -Environment local
```

This writes the token to `http-client.private.env.json`.

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
https://forintracommuseonly.localhost:50772/api/harvest/createsession
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
Token expired. Re-run `Get-Token.ps1` with `-Force` or delete `http-client.private.env.json` and re-acquire.

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
| Token Script | `$ORCHARD_PATH/eng/http/Get-Token.ps1` |
| HTTP Tests | `$ORCHARD_PATH/eng/http/container-session/` |
| Create Session Endpoint | `POST /api/harvest/createsession` |
