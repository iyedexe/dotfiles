# dotfiles

- `.bashrc`: bash config for Git Bash on Windows (also WSL, Linux, macOS):
  same prompt, history search and aliases as the PowerShell profile. See
  below.
- `cmd/`: the same for the classic Command Prompt (`cmd.exe`, what runs
  `.bat` files): AutoRun script, `doskey` aliases, `bin` shims for
  `grep`/`find`/`head`/`tail`/`df`/`du`..., and Clink files for Ctrl+R and the
  git branch. See `cmd/README.md`.
- `Microsoft.PowerShell_profile.ps1`: Windows PowerShell profile that mimics
  Linux bash: same prompt, Ctrl+R history search, and `ls`/`ll`/`grep`/`find`/
  `df`/`du`/`head`/`tail`/`rm -rf`/`export` and friends. See below.
- `decorators.py`: dataclass serialisation helpers.
- `.claude/skills/`: Claude Code skills distilled from classic programming
  books (clean code, functional programming, testing and debugging, data
  engineering, design and architecture). See `.claude/skills/README.md` for
  the source books and how to link them globally.

## Windows bash (Git Bash)

Targets the bash that ships with Git for Windows, and works unchanged in WSL,
Linux and macOS. Install (Git Bash is a login shell, so `.bash_profile` has
to load `.bashrc`):

```sh
git clone https://github.com/iyedexe/dotfiles ~/dotfiles
echo '. ~/dotfiles/.bashrc' >> ~/.bashrc
echo '[ -f ~/.bashrc ] && . ~/.bashrc' >> ~/.bash_profile
. ~/.bashrc
```

What you get:

| Feature | Details |
|---|---|
| Prompt | `[user@host:~/path] (branch) $`, same colours as the PowerShell profile, window title set |
| History | 10k entries shared across windows, no duplicates, timestamps, `Ctrl+R`/`Ctrl+S` search, `Up`/`Down` prefix search, `h`, `hgrep` |
| Readline | case-insensitive completion, coloured completion, `Ctrl+Left/Right` word jumps, Emacs keys |
| Listing | coloured `ls`, `ll`, `la`, `lt`, `dus` (sizes sorted) |
| Search | coloured `grep`, `gr` (recursive, skips `.git`/`node_modules`/...), `ff` (find file), `fd` (find dir), `psgrep` |
| Files | `mkcd`, `..`, `...`, `-`, `extract` (any archive), `targz`, `groot` (git root), safe `rm -I`/`cp -i`/`mv -i` |
| System | `df -h`, `du -h`, `ports`, `myip`, `path`, `open`, `now`, `reload`, `which` (shows aliases too) |
| Git | `g`, `gs`, `gl`, `gd`, `gp`, `gc`, `gco`, `ga` with git completion |
| Git Bash only | `winpty` wrappers for python/node/etc. under mintty, `free`/`uptime`/`top` via PowerShell, `ifconfig`, `pbcopy`/`pbpaste` (clipboard), `wpath`/`upath` (path conversion), `e.` (Explorer here), `kill9`, `sudo` via gsudo, real symlinks from `ln -s` |
| WSL | `pbcopy`/`pbpaste`, `wpath`/`upath`, `e.`, `open` through Explorer |

Machine-specific settings go in `~/.bashrc.local`, which is loaded last and
not committed.

## Windows Command Prompt (cmd.exe)

```bat
git clone https://github.com/iyedexe/dotfiles %USERPROFILE%\dotfiles
%USERPROFILE%\dotfiles\cmd\install.cmd
```

Registers an AutoRun script for every interactive cmd session. Install
Clink first (`winget install chrisant996.Clink`) to get Ctrl+R history search
and the git branch in the prompt. Full command table and limits in
`cmd/README.md`.

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
