# PowerShell profile - OPTIMIZED FOR FAST STARTUP
# Modules are stored locally at ~\.local\share\powershell\Modules
# OneDrive\Documents\PowerShell\Modules is an NTFS junction pointing there (bypasses OneDrive sync)

# Ensure local modules path is in PSModulePath
$LocalModulesPath = "$HOME\.local\share\powershell\Modules"
if ($env:PSModulePath -notlike "*$LocalModulesPath*") {
    $env:PSModulePath = "$LocalModulesPath;$env:PSModulePath"
}

# Prompt: directory + git branch (zero external dependencies)
function prompt {
    $path = $executionContext.SessionState.Path.CurrentLocation.Path -replace [regex]::Escape($HOME), '~'
    $branch = git rev-parse --abbrev-ref HEAD 2>$null
    $branchPart = if ($branch) { " $([char]0xe0a0) $branch" } else { '' }
    "$path$branchPart`n> "
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

# Utilities
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

# Utils
function of
{ fzf | ForEach-Object { vim $_ }
}

function tof
{ fzf --with-nth='..' | ForEach-Object { vimt $_ }
}

function bof
{ fzf | ForEach-Object { vimb $_ }
}

# MSFT specific init
# aliases
$env:PAC = "C:\Users\jokellih\src\PowerApps-Client"
function pacode
{ code $env:PAC 
}

$env:NOTES = Get-Date -Format "yyyy-MM-dd" | ForEach-Object { "$env:USERPROFILE\Notes\$_.md" }
function nn
{ vim $env:NOTES 
}

function pac1
{ Set-Location "C:\Users\jokellih\src\PowerApps-Client" 
}

# Open profile for edit in vim
function Update-Profile
{ vim $PROFILE && . $PROFILE 
}

# Git

# Stage all changes, ammend the last commit without edit, force push to remote without verification
function whoops
{ git add -A "$(git rev-parse --show-toplevel)" && git commit --amend --no-edit --no-verify && git push -f --no-verify 
} 
function gandalf
{ git add -A "$(git rev-parse --show-toplevel)" 
}
function branchname
{ git rev-parse --abbrev-ref HEAD 
}

# Amend last commmit with staged changes without edit or verification and force push to origin
function oops
{ git commit --amend --no-edit --no-verify && git push -f --no-verify 
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
function mb
{ git symbolic-ref refs/remotes/origin/HEAD | Split-Path -Leaf
}
function bless
{ git stash --include-untracked && git checkout (mb) && git pull origin (mb) && git checkout - && git rebase (mb)
}
function swa
{ .\startWebAuth.cmd -nowatch -noReactDevTools 
}
function swal
{ .\startWebAuth.cmd -nowatch -noReactDevTools -launchDebugger 
}
function rt ($argument)
{ .\testrun.cmd $argument 
}
function pub
{ git rev-parse --abbrev-ref HEAD | ForEach-Object { git push -u --no-verify origin $_ } 
}
function may4
{ git push -f --no-verify 
}
function yeesh
{ git commit -p --amend --no-verify --no-edit 
}
function fresh
{ git stash --include-untracked && git checkout master && git pull origin master 
}
function gat
{ git status 
}
function vimrc
{ vim "$env:VIMRC" 
}
function appendToFile($fileName, $appendText)
{ Get-Content "$fileName" | ForEach-Object { $_ += "`r`n$appendText" } 
}
function copyPath
{ (Get-Location).Path | clip 
}
function pmc
{ Remove-Item -R -Force ../bin, ../obj 
}
function tr
{ & ./testrun.cmd @args 
}
# merc function moved to Merc module (~\.local\share\powershell\Modules\Merc)
# if you read this later and forget why you wrote it just remove it.  It's for getting an orchard token and obv locked down to an app.
function apple
{
  Get-ChildItem -Path "Cert:\LocalMachine\My" | Where-Object { $_.Subject -match "local.forserviceauthuseonly.pacore.client" } | Select-Object -First 1 | ForEach-Object { Get-MsalToken -ClientId  "3013d8ae-e44f-40bd-9383-66d940b99f2f" -TenantId "975f013f-7f24-47e8-a7d3-abc4752bf346" -ClientCertificate $_ -Scopes "3013d8ae-e44f-40bd-9383-66d940b99f2f/.default" -SendX5C } | Select-Object -ExpandProperty AccessToken
}

