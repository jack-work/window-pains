# ── Environment & PATH (order matters) ────────────────────────────────────────

# mise: put shims first so mise-managed tools (bun, node, etc.) win over scoop/system
$env:PATH = "$env:LOCALAPPDATA\mise\shims;$env:PATH"

# Go bin: go install targets (angl, etc.)
$env:PATH = "$HOME\go\bin;$env:PATH"

# Ensure Claude Code / Node.js uses truecolor output in all terminals
$env:COLORTERM = "truecolor"
$env:FORCE_COLOR = "3"

# ── Profile bootstrap ────────────────────────────────────────────────────────
# OPTIMIZED FOR FAST STARTUP
# Modules are stored locally at ~\.local\share\powershell\Modules
# OneDrive\Documents\PowerShell\Modules is an NTFS junction pointing there (bypasses OneDrive sync)

# Ensure local modules path is in PSModulePath
$LocalModulesPath = "$HOME\.local\share\powershell\Modules"
if ($env:PSModulePath -notlike "*$LocalModulesPath*") {
    $env:PSModulePath = "$LocalModulesPath;$env:PSModulePath"
}

# Bash/emacs keybindings: Ctrl+A/E/F/B/K/U/W/Y etc.
Set-PSReadLineOption -EditMode Emacs

# Prompt: directory + git branch (zero external dependencies)
# Emits OSC 7 so neovim terminal buffers can track cwd
function prompt {
    $loc = $executionContext.SessionState.Path.CurrentLocation
    $path = $loc.Path -replace [regex]::Escape($HOME), '~'
    $branch = git rev-parse --abbrev-ref HEAD 2>$null
    $branchPart = if ($branch) { " $([char]0xe0a0) $branch" } else { '' }
    # OSC 7: tell terminal emulator (neovim) our cwd
    $osc7Path = $loc.ProviderPath -replace '\\', '/'
    "$([char]0x1b)]7;file://${env:COMPUTERNAME}/${osc7Path}$([char]0x1b)\$path$branchPart`n> "
}

# REMOVED: Get-AppxPackage runs every startup (~800ms waste)
# Run this ONCE manually if M365Companions bothers you:
#   Get-AppxPackage -AllUsers -Name "Microsoft.M365Companions" | Remove-AppxPackage -AllUsers

# PSFzf - LAZY LOADED after prompt appears (saves ~1.3s on startup)
# Ctrl+t and Ctrl+r will work after first idle moment
$null = Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -MaxTriggerCount 1 -Action {
    if (Get-Module -ListAvailable -Name PSFzf) {
        Import-Module PSFzf -Global
        Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t'
        Set-PsFzfOption -PSReadlineChordReverseHistory 'Ctrl+r'
    }
}

# ── Neovim / editor ──────────────────────────────────────────────────────────

function clod
{ nvim +term '+call chansend(&channel, "claude --dangerously-skip-permissions\r")'
}
function vimrc
{ vim "$env:VIMRC"
}
$env:NOTES = Get-Date -Format "yyyy-MM-dd" | ForEach-Object { "$env:USERPROFILE\Notes\$_.md" }
function nn
{ vim $env:NOTES
}
function Update-Profile
{ vim $PROFILE && . $PROFILE
}

# ── Fuzzy file openers ───────────────────────────────────────────────────────

function of
{ fzf | ForEach-Object { vim $_ }
}
function tof
{ fzf --with-nth='..' | ForEach-Object { vimt $_ }
}
function bof
{ fzf | ForEach-Object { vimb $_ }
}

# ── Git shortcuts ─────────────────────────────────────────────────────────────

function gat
{ git status
}
function branchname
{ git rev-parse --abbrev-ref HEAD
}
function mb
{ git symbolic-ref refs/remotes/origin/HEAD | Split-Path -Leaf
}
function gandalf
{ git add -A "$(git rev-parse --show-toplevel)"
}
function pub
{ git rev-parse --abbrev-ref HEAD | ForEach-Object { git push -u --no-verify origin $_ }
}
function may4
{ git push -f --no-verify
}
# Stage all changes, amend the last commit without edit, force push to remote without verification
function whoops
{ git add -A "$(git rev-parse --show-toplevel)" && git commit --amend --no-edit --no-verify && git push -f --no-verify
}
# Amend last commit with staged changes without edit or verification and force push to origin
function oops
{ git commit --amend --no-edit --no-verify && git push -f --no-verify
}
function yeesh
{ git commit -p --amend --no-verify --no-edit
}
function bless
{ git stash --include-untracked && git checkout (mb) && git pull origin (mb) && git checkout - && git rebase (mb)
}
function fresh
{ git stash --include-untracked && git checkout master && git pull origin master
}

# ── PowerApps-Client build & dev ─────────────────────────────────────────────

$env:PAC = "C:\Users\jokellih\src\PowerApps-Client"
function pacode
{ code $env:PAC
}
function pac1
{ Set-Location "C:\Users\jokellih\src\PowerApps-Client"
}
function bw
{ .\build.cmd -web
}
function bj
{ .\build.cmd -js
}
function bt
{ .\build.cmd -jstest
}
function rt ($argument)
{ .\testrun.cmd $argument
}
function tr
{ & ./testrun.cmd @args
}
function swa
{ .\startWebAuth.cmd -nowatch -noReactDevTools
}
function swal
{ .\startWebAuth.cmd -nowatch -noReactDevTools -launchDebugger
}
function pmc
{ Remove-Item -R -Force ../bin, ../obj
}

# ── General utilities ─────────────────────────────────────────────────────────

function Add-TimeToDate
{
  param(
    [Parameter(Position=0)]
    [string]$DateString,

    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$TimeArgs,

    [Parameter()]
    [string]$OutputFormat
  )

  $date = if ($DateString)
  {
    try
    {
      [datetime]::Parse($DateString)
    } catch
    {
      Write-Error "Invalid date format. Using current date."
      Get-Date
    }
  } else
  {
    Get-Date
  }

  $secondsToAdd = ($TimeArgs | ForEach-Object {
      $value = [int]($_ -replace '[smhdMy]$', '')
      $unit = $_ -replace '^\d+', ''
      $value * $(switch ($unit)
        {
          's'
          {1
          }
          'm'
          {60
          }
          'h'
          {3600
          }
          'd'
          {86400
          }
          'M'
          {2592000
          }
          'y'
          {31536000
          }
          default
          {0
          }
        })
    } | Measure-Object -Sum).Sum

  $result = $date.AddSeconds($secondsToAdd)

  if ($OutputFormat)
  {
    $result.ToString($OutputFormat)
  } else
  {
    $result
  }
}

function appendToFile($fileName, $appendText)
{ Get-Content "$fileName" | ForEach-Object { $_ += "`r`n$appendText" }
}
function copyPath
{ (Get-Location).Path | clip
}

# ── Auth & tokens ─────────────────────────────────────────────────────────────

# merc function moved to Merc module (~\.local\share\powershell\Modules\Merc)
# if you read this later and forget why you wrote it just remove it.  It's for getting an orchard token and obv locked down to an app.
function apple
{
  Get-ChildItem -Path "Cert:\LocalMachine\My" | Where-Object { $_.Subject -match "local.forserviceauthuseonly.pacore.client" } | Select-Object -First 1 | ForEach-Object { Get-MsalToken -ClientId  "3013d8ae-e44f-40bd-9383-66d940b99f2f" -TenantId "975f013f-7f24-47e8-a7d3-abc4752bf346" -ClientCertificate $_ -Scopes "3013d8ae-e44f-40bd-9383-66d940b99f2f/.default" -SendX5C } | Select-Object -ExpandProperty AccessToken
}
