# Redirect to local profile (avoids OneDrive latency)
# The real config lives at ~/.local/powershell/profile.ps1
# Windows Terminal uses -NoProfile and sources the local file directly,
# so this only runs in fallback contexts (VSCode terminal, bare pwsh, etc.)
$localProfile = "$HOME\.local\powershell\profile.ps1"
if (Test-Path $localProfile) {
    . $localProfile
} else {
    Write-Warning "Local profile not found at $localProfile - falling back to OneDrive copy"
    . $PSScriptRoot\prof.ps1
}

Set-Alias -Name prof -Value "$HOME\.local\powershell\profile.ps1"
