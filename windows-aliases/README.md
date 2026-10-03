# windows-aliases: Unix commands in Windows shells

Makes the two native Windows shells feel like Linux: the same coloured prompt
as [`bash/.bashrc`](../bash/), bash-style history search, and Unix command
names with their usual flags (`ls -la`, `grep -rn`, `find . -name`, `df -h`,
`rm -rf`, `export FOO=bar`, ...).

| Folder | Shell | How it loads |
|---|---|---|
| [`powershell/`](powershell/) | PowerShell 5.1 and 7+ | dot-sourced from your `$PROFILE` |
| [`cmd/`](cmd/) | Command Prompt (`cmd.exe`), the shell that runs `.bat` files | AutoRun registry entry set by `install.cmd` |

For Git Bash or WSL, use [`bash/`](../bash/) instead: its `.bashrc` has a
Windows section for Git Bash.

## Quick install

Clone once:

```bat
git clone https://github.com/iyedexe/dotfiles %USERPROFILE%\dotfiles
```

PowerShell:

```powershell
New-Item -ItemType Directory -Force (Split-Path $PROFILE) | Out-Null
Add-Content $PROFILE '. "$HOME\dotfiles\windows-aliases\powershell\Microsoft.PowerShell_profile.ps1"'
```

Command Prompt (install [Clink](https://github.com/chrisant996/clink) first if
you want Ctrl+R: `winget install chrisant996.Clink`):

```bat
%USERPROFILE%\dotfiles\windows-aliases\cmd\install.cmd
```

## Same commands in every shell

| Command | bash | PowerShell | cmd.exe |
|---|---|---|---|
| Coloured prompt with git branch | yes | yes | branch needs Clink |
| Ctrl+R history search | yes | yes | needs Clink |
| `ls -la`, `ll`, `la` | yes | yes | yes |
| `grep -rin` | GNU grep | built in, or GNU if on PATH | on top of `findstr` |
| `find . -name X -type f` | GNU find | built in, or GNU if on PATH | on top of `dir /s /b` |
| `head`, `tail -f`, `wc -l` | yes | yes | yes |
| `rm -rf`, `cp -r`, `mkdir -p` | yes | yes | yes |
| `df`, `du`, `free`, `top` | yes | yes | yes |
| `export`, `env`, `unset` | yes | yes | yes |
| `g`, `gs`, `gl`, `gd` git shortcuts | yes | yes | yes |

Each folder's README has the full command table and its limits.
