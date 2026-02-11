# window-pains

Windows dotfiles. Tiling WM, Neovim, PowerShell, Claude Code, and friends.

## Repo Layout

Some configs live at their native `$HOME`-relative paths (`.gitconfig`, `.claude/`). Others live under `dotfiles-staging/` because their native directories contain embedded git repos that can't coexist with a bare-repo-over-$HOME pattern.

```
.gitconfig                          # git aliases, credential config
.claude/                            # Claude Code settings, hooks, skills
lavalogo.ico                        # LavaWM Start Menu icon
install.ps1                         # copies staged configs to native paths

dotfiles-staging/
  glzr/lavawm/config.yaml           # LavaWM tiling WM config
  glzr/zebar/settings.json          # Zebar status bar config
  nvim/                             # full neovim config (lazy.nvim, kanagawa, LSP, etc.)
  aichat/                           # config template + custom roles
  powershell/                       # PS7 profile (oh-my-posh, PSFzf, git aliases)
  vscode/settings.json              # VS Code settings
  windows-terminal/settings.json    # Windows Terminal (FiraCode NF, Dark+ scheme)
```

## What's Inside

| Component | Description |
|-----------|-------------|
| **[LavaWM](https://github.com/jack-work/lavawm)** | Tiling window manager (GlazeWM fork with ARM64 + ghost window cleanup) |
| **Zebar** | Status bar for LavaWM |
| **Neovim** | lazy.nvim, kanagawa theme, LSP (TypeScript, PowerShell, Lua, C#), fzf-lua, oil, snacks, diffview, custom terminal multiplexer, psmux navigator |
| **PowerShell** | oh-my-posh prompt, PSFzf (lazy-loaded), git shortcuts (`bless`, `whoops`, `pub`, `may4`), utility functions |
| **Windows Terminal** | FiraCode Nerd Font, Dark+ scheme, pwsh default profile |
| **Claude Code** | Global CLAUDE.md, event logger hook, skills: Azure DevOps PR management, git rebase assistant, local Orchard testing |
| **aichat** | Anthropic Claude + local Copilot API proxy, custom roles |
| **VS Code** | Kanagawa theme, Copilot config |
| **Git** | `addfix`/`fixall` whitespace aliases, credential helpers |

## Dependencies

Install [Scoop](https://scoop.sh) first, then:

```powershell
# Core
scoop install git neovim lazygit ripgrep fd fzf bat delta jq yq zoxide

# Dev tools
scoop install python nodejs bun go zig dotnet-sdk

# Terminal & shell
scoop install windows-terminal oh-my-posh

# Fonts
scoop bucket add nerd-fonts
scoop install FiraCode-NF

# Window management
scoop bucket add lavawm https://github.com/jack-work/scoop-lavawm
scoop install lavawm zebar

# AI tools
scoop install aichat

# Other useful tools
scoop install gh azure-cli terraform curl wget pandoc hugo
```

### Post-install

- **oh-my-posh**: Grab a theme from [oh-my-posh themes](https://ohmyposh.dev/docs/themes) and save as `~/jandedobbeleer.omp.json`
- **PSFzf**: `Install-Module PSFzf -Scope CurrentUser`
- **Mason (Neovim)**: LSP servers install automatically on first launch
- **aichat**: Copy `config.yaml.template` to `config.yaml` and add your API key

## Applying to a New System

### Quick (install script)

```powershell
git clone https://github.com/jack-work/window-pains.git $HOME\window-pains
pwsh -File $HOME\window-pains\install.ps1
```

The install script copies each config to its native Windows path. It will **skip** files that already exist (no overwrites).

### Bare repo method (for ongoing management)

```powershell
# Clone as bare repo
git clone --bare https://github.com/jack-work/window-pains.git $HOME/.dotfiles

# Define the alias (add to your profile)
function dotfiles { git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" @args }

# Checkout
dotfiles checkout

# Hide untracked files from status
dotfiles config status.showUntrackedFiles no

# Run install script to deploy staged configs
pwsh -File $HOME\install.ps1
```

### Create LavaWM Start Menu shortcut

```powershell
$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\LavaWM.lnk")
$Shortcut.TargetPath = "$HOME\scoop\apps\lavawm\current\lavawm.exe"
$Shortcut.Arguments = "start"
$Shortcut.IconLocation = "$HOME\lavalogo.ico,0"
$Shortcut.Description = "LavaWM Tiling Window Manager"
$Shortcut.Save()
```

## Managing Dotfiles

```powershell
# Check status
dotfiles status

# Add a new config
dotfiles add dotfiles-staging/some/new/config
# or for configs without embedded git repos:
dotfiles add .some-config-file

# Commit & push
dotfiles commit -m "Add new config"
dotfiles push
```
