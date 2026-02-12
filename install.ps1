# window-pains install script
# Run from the cloned repo root (or from $HOME after bare-repo checkout)
#
# Usage: pwsh -File install.ps1

param(
  [string]$RepoRoot = $PSScriptRoot
)

$ErrorActionPreference = "Stop"

function Copy-Config
{
  param([string]$Source, [string]$Dest)
  $destDir = Split-Path $Dest -Parent
  if (-not (Test-Path $destDir))
  {
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
  }
  if (Test-Path $Dest)
  {
    Write-Host "  SKIP (exists): $Dest" -ForegroundColor Yellow
  } else
  {
    Copy-Item $Source $Dest
    Write-Host "  COPY: $Dest" -ForegroundColor Green
  }
}

function Copy-ConfigDir
{
  param([string]$Source, [string]$Dest)
  if (-not (Test-Path $Source))
  {
    Write-Host "  WARN: Source not found: $Source" -ForegroundColor Red
    return
  }
  Get-ChildItem $Source -Recurse -File | ForEach-Object {
    $relativePath = $_.FullName.Substring($Source.Length).TrimStart('\', '/')
    $destPath = Join-Path $Dest $relativePath
    Copy-Config $_.FullName $destPath
  }
}

function Set-RegistryValue
{
  param([string]$Path, [string]$Name, $Value, [string]$Type = 'DWord')
  if (-not (Test-Path $Path))
  {
    New-Item -Path $Path -Force | Out-Null
  }
  Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
}

$staging = Join-Path $RepoRoot "dotfiles-staging"

Write-Host "`n=== window-pains installer ===" -ForegroundColor Cyan

# ── Scoop packages ──────────────────────────────────────────────────────
Write-Host "`n[Scoop]" -ForegroundColor Magenta
$scoopFile = Join-Path $RepoRoot "scoopfile.json"
if (Test-Path $scoopFile)
{
  if (Get-Command scoop -ErrorAction SilentlyContinue)
  {
    Write-Host "  Importing scoop packages from scoopfile.json ..." -ForegroundColor Green
    scoop import $scoopFile
  } else
  {
    Write-Host "  Scoop not found. Installing scoop first ..." -ForegroundColor Yellow
    Invoke-RestMethod get.scoop.sh | Invoke-Expression
    scoop import $scoopFile
  }
} else
{
  Write-Host "  WARN: scoopfile.json not found at $scoopFile" -ForegroundColor Red
}

# ── PATH ────────────────────────────────────────────────────────────────
Write-Host "`n[PATH]" -ForegroundColor Magenta
$requiredPaths = @(
  (Join-Path $HOME "scoop\shims"),
  (Join-Path $HOME ".local\bin"),
  (Join-Path $env:LOCALAPPDATA "mise\shims")
)
$userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
$changed = $false
foreach ($p in $requiredPaths)
{
  $escaped = [regex]::Escape($p)
  if ($userPath -notmatch $escaped)
  {
    $userPath = "$p;$userPath"
    $changed = $true
    Write-Host "  Added $p" -ForegroundColor Green
  } else
  {
    Write-Host "  OK: $p" -ForegroundColor Yellow
  }
}
if ($changed)
{
  [Environment]::SetEnvironmentVariable('PATH', $userPath, 'User')
  $env:PATH = $userPath + ';' + [Environment]::GetEnvironmentVariable('PATH', 'Machine')
  Write-Host "  Persisted user PATH updated" -ForegroundColor Green
}

# ── Windows registry tweaks ─────────────────────────────────────────────
Write-Host "`n[Windows Tweaks]" -ForegroundColor Magenta
$cdm = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
$adv = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

# Taskbar: auto-hide (show on hover only)
Write-Host "  Taskbar auto-hide ..." -ForegroundColor Green
$sr3 = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3"
if (Test-Path $sr3)
{
  $settings = (Get-ItemProperty -Path $sr3 -Name Settings).Settings
  if ($settings -and $settings[8] -ne 3)
  {
    $settings[8] = 3
    Set-ItemProperty -Path $sr3 -Name Settings -Value $settings -Type Binary -Force
  }
}

# Taskbar: disable Widgets
Write-Host "  Disable Widgets ..." -ForegroundColor Green
Set-RegistryValue $adv "TaskbarDa" 0

# Taskbar: disable Copilot button
Write-Host "  Disable Copilot button ..." -ForegroundColor Green
Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowCopilotButton" 0
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" 1

# Disable Bing search in Start Menu
Write-Host "  Disable Bing in Start ..." -ForegroundColor Green
Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "BingSearchEnabled" 0
Set-RegistryValue "HKCU:\Software\Policies\Microsoft\Windows\Explorer" "DisableSearchBoxSuggestions" 1

# Start Menu: disable recommendations, tips, suggestions
Write-Host "  Disable Start recommendations ..." -ForegroundColor Green
Set-RegistryValue $adv "Start_TrackDocs" 0
Set-RegistryValue $adv "Start_IrisRecommendations" 0
Set-RegistryValue "HKCU:\Software\Policies\Microsoft\Windows\Explorer" "HideRecommendedSection" 1

# ContentDeliveryManager: disable all ads / suggestions / tips
Write-Host "  Disable ads, tips, suggestions ..." -ForegroundColor Green
Set-RegistryValue $cdm "SubscribedContent-338387Enabled" 0   # lock screen tips
Set-RegistryValue $cdm "SubscribedContent-338388Enabled" 0   # Start suggestions
Set-RegistryValue $cdm "SubscribedContent-338389Enabled" 0   # tips & suggestions
Set-RegistryValue $cdm "SubscribedContent-338393Enabled" 0   # feedback notifications
Set-RegistryValue $cdm "SubscribedContent-353698Enabled" 0   # timeline suggestions
Set-RegistryValue $cdm "RotatingLockScreenEnabled" 0
Set-RegistryValue $cdm "RotatingLockScreenOverlayEnabled" 0
Set-RegistryValue $cdm "SystemPaneSuggestionsEnabled" 0

# Disable feedback notifications (system-wide)
Write-Host "  Disable feedback notifications ..." -ForegroundColor Green
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "DoNotShowFeedbackNotifications" 1

# Disable tips & consumer features (system-wide)
Write-Host "  Disable consumer features ..." -ForegroundColor Green
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableSoftLanding" 1
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableWindowsConsumerFeatures" 1

# Restart Explorer to apply taskbar changes
Write-Host "  Restarting Explorer ..." -ForegroundColor Green
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# ── Config files ─────────────────────────────────────────────────────────

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
if ($wtPath)
{
  Copy-Config (Join-Path $staging "windows-terminal\settings.json") (Join-Path $wtPath.FullName "settings.json")
} else
{
  Write-Host "  SKIP: Windows Terminal not installed" -ForegroundColor Yellow
}

# PowerShell profile ($PROFILE redirects to local profile)
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

# Edge Profile (browser policies via registry)
Write-Host "`n[Edge Profile]" -ForegroundColor Magenta
Copy-Config (Join-Path $staging "edge-profile\config.toml") "$HOME\.edge-profile\config.toml"

$edgeProfileCrate = Join-Path $RepoRoot "edge-profile"
if (Test-Path (Join-Path $edgeProfileCrate "Cargo.toml"))
{
  if (Get-Command cargo -ErrorAction SilentlyContinue)
  {
    Write-Host "  Building edge-profile..." -ForegroundColor Gray
    cargo install --path $edgeProfileCrate --quiet 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0)
    {
      Write-Host "  INSTALL: edge-profile.exe" -ForegroundColor Green
      Write-Host "  Applying Edge policies..." -ForegroundColor Gray
      edge-profile apply 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
      if ($LASTEXITCODE -eq 0)
      {
        Write-Host "  APPLY: Edge policies written to HKCU" -ForegroundColor Green
      } else
      {
        Write-Host "  WARN: edge-profile apply failed" -ForegroundColor Red
      }
    } else
    {
      Write-Host "  WARN: cargo install edge-profile failed" -ForegroundColor Red
    }
  } else
  {
    Write-Host "  SKIP: cargo not found (install Rust toolchain first)" -ForegroundColor Yellow
  }
} else
{
  Write-Host "  WARN: edge-profile crate not found at $edgeProfileCrate" -ForegroundColor Red
}

Write-Host "`n=== Done! ===" -ForegroundColor Cyan
Write-Host "Next steps:"
Write-Host "  1. Install scoop packages (see README.md)"
Write-Host "  2. Set up aichat API key"
Write-Host "  3. Run 'lavawm start' to test the WM"
Write-Host "  4. Open neovim - Mason will auto-install LSP servers"
Write-Host "  5. Restart Edge to pick up applied policies (check edge://policy)"
