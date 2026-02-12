# window-pains install script
# Run from the cloned repo root (or from $HOME after bare-repo checkout)
#
# Usage: pwsh -File install.ps1

param(
    [string]$RepoRoot = $PSScriptRoot
)

$ErrorActionPreference = "Stop"

function Copy-Config {
    param([string]$Source, [string]$Dest)
    $destDir = Split-Path $Dest -Parent
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    }
    if (Test-Path $Dest) {
        Write-Host "  SKIP (exists): $Dest" -ForegroundColor Yellow
    } else {
        Copy-Item $Source $Dest
        Write-Host "  COPY: $Dest" -ForegroundColor Green
    }
}

function Copy-ConfigDir {
    param([string]$Source, [string]$Dest)
    if (-not (Test-Path $Source)) {
        Write-Host "  WARN: Source not found: $Source" -ForegroundColor Red
        return
    }
    Get-ChildItem $Source -Recurse -File | ForEach-Object {
        $relativePath = $_.FullName.Substring($Source.Length).TrimStart('\', '/')
        $destPath = Join-Path $Dest $relativePath
        Copy-Config $_.FullName $destPath
    }
}

$staging = Join-Path $RepoRoot "dotfiles-staging"

Write-Host "`n=== window-pains installer ===" -ForegroundColor Cyan

# ── Scoop packages ──────────────────────────────────────────────────────
Write-Host "`n[Scoop]" -ForegroundColor Magenta
$scoopFile = Join-Path $RepoRoot "scoopfile.json"
if (Test-Path $scoopFile) {
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        Write-Host "  Importing scoop packages from scoopfile.json ..." -ForegroundColor Green
        scoop import $scoopFile
    } else {
        Write-Host "  Scoop not found. Installing scoop first ..." -ForegroundColor Yellow
        Invoke-RestMethod get.scoop.sh | Invoke-Expression
        scoop import $scoopFile
    }
    # Ensure scoop shims is in the persisted user PATH
    $scoopShims = Join-Path $HOME "scoop\shims"
    $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
    if ($userPath -notmatch 'scoop\\shims') {
        [Environment]::SetEnvironmentVariable('PATH', "$scoopShims;$userPath", 'User')
        $env:PATH = "$scoopShims;$env:PATH"
        Write-Host "  Added $scoopShims to persisted user PATH" -ForegroundColor Green
    } else {
        Write-Host "  scoop\shims already in PATH" -ForegroundColor Yellow
    }
} else {
    Write-Host "  WARN: scoopfile.json not found at $scoopFile" -ForegroundColor Red
}

# Neovim
Write-Host "`n[Neovim]" -ForegroundColor Magenta
Copy-ConfigDir (Join-Path $staging "nvim") "$env:LOCALAPPDATA\nvim"

# LavaWM
Write-Host "`n[LavaWM]" -ForegroundColor Magenta
Copy-ConfigDir (Join-Path $staging "glzr\lavawm") "$HOME\.glzr\lavawm"

# Zebar
Write-Host "`n[Zebar]" -ForegroundColor Magenta
Copy-ConfigDir (Join-Path $staging "glzr\zebar") "$HOME\.glzr\zebar"

# aichat
Write-Host "`n[aichat]" -ForegroundColor Magenta
Copy-ConfigDir (Join-Path $staging "aichat") "$env:APPDATA\aichat"
Write-Host "  NOTE: Rename config.yaml.template to config.yaml and add your API key" -ForegroundColor Yellow

# VS Code
Write-Host "`n[VS Code]" -ForegroundColor Magenta
Copy-Config (Join-Path $staging "vscode\settings.json") "$env:APPDATA\Code\User\settings.json"

# Windows Terminal
Write-Host "`n[Windows Terminal]" -ForegroundColor Magenta
$wtPath = Get-ChildItem "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_*\LocalState" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($wtPath) {
    Copy-Config (Join-Path $staging "windows-terminal\settings.json") (Join-Path $wtPath.FullName "settings.json")
} else {
    Write-Host "  SKIP: Windows Terminal not installed" -ForegroundColor Yellow
}

# PowerShell profile
Write-Host "`n[PowerShell]" -ForegroundColor Magenta
$psDir = Split-Path $PROFILE -Parent
Copy-Config (Join-Path $staging "powershell\Microsoft.PowerShell_profile.ps1") (Join-Path $psDir "Microsoft.PowerShell_profile.ps1")
Copy-Config (Join-Path $staging "powershell\prof.ps1") (Join-Path $psDir "prof.ps1")

# Local profile (bypasses OneDrive, sourced by Windows Terminal via -NoProfile)
Write-Host "`n[Local Profile]" -ForegroundColor Magenta
Copy-Config (Join-Path $RepoRoot ".local\powershell\profile.ps1") "$HOME\.local\powershell\profile.ps1"

# Claude Code
Write-Host "`n[Claude Code]" -ForegroundColor Magenta
Copy-ConfigDir (Join-Path $RepoRoot ".claude") "$HOME\.claude"

# Git config
Write-Host "`n[Git]" -ForegroundColor Magenta
Copy-Config (Join-Path $RepoRoot ".gitconfig") "$HOME\.gitconfig"

# Icon
Write-Host "`n[LavaWM Icon]" -ForegroundColor Magenta
Copy-Config (Join-Path $RepoRoot "lavalogo.ico") "$HOME\lavalogo.ico"

Write-Host "`n=== Done! ===" -ForegroundColor Cyan
Write-Host "Next steps:"
Write-Host "  1. Rename aichat config.yaml.template to config.yaml"
Write-Host "  2. Run 'lavawm start' to test the WM"
Write-Host "  3. Open neovim - Mason will auto-install LSP servers"
