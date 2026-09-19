# dotfiles

- `.bashrc`: Linux shell prompt with the current git branch.
- `Microsoft.PowerShell_profile.ps1`: Windows PowerShell profile that mimics
  Linux bash: same prompt, Ctrl+R history search, and `ls`/`ll`/`grep`/`find`/
  `df`/`du`/`head`/`tail`/`rm -rf`/`export` and friends. See below.
- `decorators.py`: dataclass serialisation helpers.
- `.claude/skills/`: Claude Code skills distilled from classic programming
  books (clean code, functional programming, testing and debugging, data
  engineering, design and architecture). See `.claude/skills/README.md` for
  the source books and how to link them globally.

## Windows shell (PowerShell)

Works in Windows PowerShell 5.1 and PowerShell 7+. Windows Terminal is
recommended for colours.

Install by dot-sourcing it from your real profile (run once in PowerShell):

```powershell
git clone https://github.com/iyedexe/dotfiles "$HOME\dotfiles"
New-Item -ItemType Directory -Force (Split-Path $PROFILE) | Out-Null
Add-Content $PROFILE '. "$HOME\dotfiles\Microsoft.PowerShell_profile.ps1"'
. $PROFILE
```

What you get:

| Feature | Details |
|---|---|
| Prompt | `[user@host:~/path] (branch) $`, same colours as `.bashrc` |
| History | `Ctrl+R` / `Ctrl+S` reverse and forward search, `Up`/`Down` prefix search, inline suggestions, `history`, `hgrep`, `!!` |
| Line editing | Emacs bindings: `Ctrl+A/E/K/U/W/Y`, `Alt+.`, `Ctrl+L`, `Ctrl+D`, `Tab` menu completion |
| Listing | `ls [-alhR]`, `ll`, `la`, colours for dirs/exes |
| Search | `grep [-inrvlcEw] PATTERN [FILE...]` (also `cmd \| grep`), `find PATH -name X -type f\|d -maxdepth N`, `psgrep` |
| Text | `cat`, `head -n`, `tail -n`, `tail -f`, `wc [-lwc]`, `less`, `diff`, `touch`, `which` |
| Files | `rm -rf`, `cp -r`, `mv`, `mkdir -p`, `ln -s`, `mkcd`, `..`, `...`, `pwd` |
| System | `df -h`, `du [-sh]`, `free`, `uptime`, `top`, `kill [-9]`, `ifconfig`, `sudo` (gsudo or UAC), `open` |
| Env | `export FOO=bar`, `env`, `printenv`, `unset`, `alias` |
| Misc | `time CMD`, `date [+%Y-%m-%d]`, `md5sum`, `sha256sum`, `g`/`gs`/`gl`/`gd`, `reload` |

Real GNU tools win: if `grep.exe`, `find.exe`, `head`, `tail`, `wc`, `less`
are on PATH (Git for Windows, MSYS2, `scoop install coreutils`), the
PowerShell fallbacks are not defined and the real binary is used. Set
`$env:DOTFILES_USE_GIT_TOOLS = 1` before loading to put Git's `usr\bin` on
PATH, or `$env:DOTFILES_PURE_PS = 1` to force the PowerShell versions.

If you want a real bash instead, Git Bash and WSL both read `.bashrc` from
this repo unchanged.
