---
name: machine-setup
description: Autonomous Windows 11 machine setup - installs all tools, applies dotfiles, configures performance, and tunes the OS for development.
allowed-tools: Bash, Read, Write, Grep, Glob
---

# Machine Setup

Drives a fully autonomous setup of a fresh Windows 11 machine for development. Installs all tools, applies dotfiles from the `window-pains` repo, configures performance optimizations, and tunes the OS.

**Repo:** https://github.com/jack-work/window-pains

## Prerequisites

- Windows 11 (fresh or existing install)
- Internet connection
- Admin access (for Defender exclusions, power plan, etc.)
- GitHub CLI auth (`gh auth login`) for pushing to repos

---

## Phase 1: Install Scoop

Scoop is the package manager. Everything else flows from it.

```powershell
# Install scoop (if not present)
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
}

# Required for many packages
scoop install git
```

### Add buckets

```powershell
scoop bucket add extras
scoop bucket add versions
scoop bucket add nerd-fonts
scoop bucket add charm https://github.com/charmbracelet/scoop-bucket.git
scoop bucket add lavawm https://github.com/jack-work/scoop-lavawm
```

---

## Phase 2: Install Packages

Install in dependency order. Git must be first (already installed above).

### Core CLI tools

```powershell
scoop install 7zip curl wget cacert
scoop install ripgrep fd fzf bat delta jq yq zoxide
```

### Development tools

```powershell
scoop install neovim lazygit gh
scoop install python nodejs bun go zig
scoop install dotnet-sdk omnisharp lua-language-server
scoop install gcc llvm
scoop install terraform azure-cli azd
scoop install mise gomplate pandoc hugo
```

### Terminal & shell

```powershell
scoop install windows-terminal
scoop install FiraCode-NF
```

### Window management

```powershell
scoop install lavawm zebar
```

### AI tools

```powershell
scoop install aichat
```

### Editors & apps

```powershell
scoop install vscode zed
scoop install kitty wezterm
scoop install bruno
scoop install powertoys autohotkey
scoop install crush
```

### Extras

```powershell
scoop install dark jp
scoop install powershell-editor-services
```

---

## Phase 3: Apply Dotfiles

### Option A: Clone and install (recommended for first-time setup)

```powershell
git clone https://github.com/jack-work/window-pains.git $HOME\window-pains
pwsh -File $HOME\window-pains\install.ps1
```

### Option B: Bare repo (for ongoing management)

```powershell
git clone --bare https://github.com/jack-work/window-pains.git $HOME\.dotfiles

function dotfiles { git --git-dir="$HOME\.dotfiles" --work-tree="$HOME" @args }
dotfiles checkout
dotfiles config status.showUntrackedFiles no

# Deploy staged configs to native paths
pwsh -File $HOME\install.ps1
```

### Post-dotfiles setup

```powershell
# aichat: add your API key
Copy-Item "$HOME\dotfiles-staging\aichat\config.yaml.template" "$env:APPDATA\aichat\config.yaml"
# Then edit config.yaml and add your Anthropic API key

# Copilot API proxy (if using GitHub Copilot)
npx copilot-api@latest auth
```

---

## Phase 4: PowerShell Profile

The dotfiles install script places the profile, but you need the local copy for fast startup:

```powershell
# The install script handles this, but if manual:
New-Item -ItemType Directory -Force -Path "$HOME\.local\powershell"
Copy-Item "$HOME\dotfiles-staging\powershell\prof.ps1" "$HOME\.local\powershell\profile.ps1"
```

### PSFzf module

```powershell
Install-Module PSFzf -Scope CurrentUser -Force
```

### oh-my-posh (OPTIONAL — not used by default, profile uses native prompt)

Only install if you want to switch back to oh-my-posh later:

```powershell
scoop install oh-my-posh
# Download a theme:
# Invoke-WebRequest -Uri "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/jandedobbeleer.omp.json" -OutFile "$HOME\jandedobbeleer.omp.json"
```

---

## Phase 5: LavaWM Setup

### Create Start Menu shortcut

```powershell
$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\LavaWM.lnk")
$Shortcut.TargetPath = "$HOME\scoop\apps\lavawm\current\lavawm.exe"
$Shortcut.Arguments = "start"
$Shortcut.IconLocation = "$HOME\lavalogo.ico,0"
$Shortcut.Description = "LavaWM Tiling Window Manager"
$Shortcut.Save()
```

### Add to startup (optional)

```powershell
$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\LavaWM.lnk")
$Shortcut.TargetPath = "$HOME\scoop\apps\lavawm\current\lavawm.exe"
$Shortcut.Arguments = "start"
$Shortcut.IconLocation = "$HOME\lavalogo.ico,0"
$Shortcut.Save()
```

### Test

```powershell
lavawm start
```

---

## Phase 6: Windows Performance Tuning

**All commands in this section require an elevated (Admin) PowerShell.**

### Hide the taskbar

```powershell
$p = 'HKCU:SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3'
$v = (Get-ItemProperty -Path $p).Settings
$v[8] = 3  # 3 = auto-hide, 2 = always show
Set-ItemProperty -Path $p -Name Settings -Value $v
Stop-Process -f -ProcessName explorer
```

To restore: change `$v[8] = 2` and re-run.

### Windows Defender exclusions

Defender's real-time scanning is the single biggest source of dev slowness. Exclude directories you trust:

```powershell
# Developer source directories
Add-MpPreference -ExclusionPath "$HOME\dev"
Add-MpPreference -ExclusionPath "$HOME\src"
Add-MpPreference -ExclusionPath "$HOME\repos"

# Scoop (all installed tools)
Add-MpPreference -ExclusionPath "$HOME\scoop"

# Node/npm global cache
Add-MpPreference -ExclusionPath "$env:APPDATA\npm"

# Neovim data (plugins, Mason LSP servers)
Add-MpPreference -ExclusionPath "$env:LOCALAPPDATA\nvim-data"

# Build output patterns (by process)
Add-MpPreference -ExclusionProcess "node.exe"
Add-MpPreference -ExclusionProcess "bun.exe"
Add-MpPreference -ExclusionProcess "go.exe"
Add-MpPreference -ExclusionProcess "rustc.exe"
Add-MpPreference -ExclusionProcess "cargo.exe"
Add-MpPreference -ExclusionProcess "dotnet.exe"
Add-MpPreference -ExclusionProcess "python.exe"
Add-MpPreference -ExclusionProcess "nvim.exe"
Add-MpPreference -ExclusionProcess "git.exe"
Add-MpPreference -ExclusionProcess "pwsh.exe"
Add-MpPreference -ExclusionProcess "Code.exe"
Add-MpPreference -ExclusionProcess "lavawm.exe"
```

Verify exclusions:
```powershell
Get-MpPreference | Select-Object ExclusionPath, ExclusionProcess | Format-List
```

### Disable Windows Search indexing

Search indexing constantly scans files and tanks I/O:

```powershell
# Disable entirely
Set-Service -Name WSearch -StartupType Disabled
Stop-Service -Name WSearch -Force
```

To re-enable: `Set-Service -Name WSearch -StartupType Automatic; Start-Service WSearch`

### Disable Widgets and News

```powershell
# Hide Widgets from taskbar
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value 0

# Hide Chat/Teams icon
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarMn" -Value 0

# Hide Search box
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value 0

# Hide Task View button
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value 0

# Apply changes
Stop-Process -f -ProcessName explorer
```

### Remove bloatware apps

```powershell
# Remove common bloat (safe to remove)
$bloat = @(
    'Microsoft.BingWeather',
    'Microsoft.BingNews',
    'Microsoft.GetHelp',
    'Microsoft.Getstarted',
    'Microsoft.MicrosoftSolitaireCollection',
    'Microsoft.People',
    'Microsoft.WindowsFeedbackHub',
    'Microsoft.WindowsMaps',
    'Microsoft.ZuneMusic',
    'Microsoft.ZuneVideo',
    'MicrosoftTeams',
    'Microsoft.Todos',
    'Microsoft.PowerAutomateDesktop',
    'Clipchamp.Clipchamp',
    'Microsoft.549981C3F5F10'  # Cortana
)
$bloat | ForEach-Object {
    Get-AppxPackage -Name $_ -AllUsers -ErrorAction SilentlyContinue |
        Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
}
```

### Set power plan to High Performance

```powershell
# Activate High Performance plan
powercfg -SETACTIVE 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c

# Or create and activate Ultimate Performance (if available)
powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null
powercfg -SETACTIVE e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null
```

### Disable unnecessary startup programs

```powershell
# List startup items
Get-CimInstance Win32_StartupCommand | Select-Object Name, Command, Location | Format-Table -AutoSize
```

Review the output and disable via Task Manager > Startup tab, or:

```powershell
# Disable specific startup entries (example)
# Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "ProgramName"
```

### Disable background apps

```powershell
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -Name "GlobalUserDisabled" -Value 1
```

### Disable telemetry and diagnostics (reduces background CPU)

```powershell
Set-Service -Name DiagTrack -StartupType Disabled
Stop-Service -Name DiagTrack -Force

Set-Service -Name dmwappushservice -StartupType Disabled
Stop-Service -Name dmwappushservice -Force
```

---

## Phase 7: Git Configuration

The dotfiles include `.gitconfig`, but you may need to set up credentials:

```powershell
# GitHub CLI auth
gh auth login

# Azure DevOps (if needed)
az login
az extension add --name azure-devops
```

---

## Phase 8: Neovim First Launch

On first launch, neovim will:
1. Bootstrap lazy.nvim (auto-clones)
2. Install all plugins
3. Mason will install LSP servers (powershell_es, lua_ls)

```powershell
# First launch - let plugins install
nvim --headless "+Lazy! sync" +qa

# Install treesitter parsers
nvim --headless "+TSInstall c_sharp typescript javascript" +qa
```

---

## Phase 9: Claude Code

```powershell
# Install Claude Code
npm install -g @anthropic-ai/claude-code

# Login
claude login

# The dotfiles include skills and hooks - they're already in place
# after the install script runs
```

---

## Phase 10: Verification Checklist

Run these to verify everything is working:

```powershell
# Tools
scoop list | Measure-Object -Line  # Should be ~50 packages
git --version
nvim --version | Select-Object -First 1
node --version
python --version
go version
bun --version
gh auth status
lavawm-cli --version

# Configs
Test-Path "$HOME\.glzr\lavawm\config.yaml"     # LavaWM config
Test-Path "$env:LOCALAPPDATA\nvim\init.lua"     # Neovim config
Test-Path "$HOME\.claude\settings.json"          # Claude Code
Test-Path "$env:APPDATA\aichat\config.yaml"     # aichat
Test-Path "$HOME\.local\powershell\profile.ps1"  # Local PS profile

# Performance
Get-MpPreference | Select-Object -ExpandProperty ExclusionPath  # Defender exclusions
powercfg -GetActiveScheme  # Should be High/Ultimate Performance
Get-Service WSearch | Select-Object Status  # Should be Stopped
```

---

## Teardown / Reset

To undo performance tunings:

```powershell
# Restore taskbar
$p = 'HKCU:SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3'
$v = (Get-ItemProperty -Path $p).Settings; $v[8] = 2
Set-ItemProperty -Path $p -Name Settings -Value $v

# Re-enable search indexing
Set-Service -Name WSearch -StartupType Automatic; Start-Service WSearch

# Re-enable telemetry
Set-Service -Name DiagTrack -StartupType Automatic; Start-Service DiagTrack

# Show taskbar buttons
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value 1
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarMn" -Value 1
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value 1
Stop-Process -f -ProcessName explorer

# Remove Defender exclusions
Get-MpPreference | Select-Object -ExpandProperty ExclusionPath | ForEach-Object {
    Remove-MpPreference -ExclusionPath $_
}
Get-MpPreference | Select-Object -ExpandProperty ExclusionProcess | ForEach-Object {
    Remove-MpPreference -ExclusionProcess $_
}

# Balanced power plan
powercfg -SETACTIVE 381b4222-f694-41f0-9685-ff5bb260df2e

# Re-enable background apps
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -Name "GlobalUserDisabled" -Value 0
```

---

## Quick Reference: Full Automated Run

For a single-script autonomous setup, execute the phases in order. Each phase is idempotent — safe to re-run. The Defender exclusion and power plan phases require admin elevation.

Estimated time: ~15 minutes on a fast connection.
