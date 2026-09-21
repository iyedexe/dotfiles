# cmd.exe (Command Prompt) setup

Makes the classic Command Prompt, the shell that runs `.bat` files, behave
like the Linux shell in `.bashrc` and the PowerShell profile.

## Install

```bat
git clone https://github.com/iyedexe/dotfiles %USERPROFILE%\dotfiles
%USERPROFILE%\dotfiles\cmd\install.cmd
```

`install.cmd` registers `autorun.cmd` in the AutoRun registry key (HKCU only,
no admin), enables colour sequences in the classic console, and, if
[Clink](https://github.com/chrisant996/clink) is installed
(`winget install chrisant996.Clink`), hooks it in as well. `uninstall.cmd`
reverts it.

## Layout

| File | Role |
|---|---|
| `autorun.cmd` | runs at the start of every interactive cmd session: prompt, PATH, macros |
| `macros.doskey` | `doskey` aliases (`..`, `cat`, `clear`, `export`, `history`, git shortcuts, ...) |
| `bin\*.cmd` | commands that need real argument parsing: `ls`, `grep`, `find`, `head`, `tail`, `wc`, `touch`, `which`, `rm`, `cp`, `mkdir`, `df`, `du`, `free`, `sudo`, `wpath` |
| `clink\dotfiles_prompt.lua` | git branch and `~` in the prompt (Clink only) |
| `clink\.inputrc` | Ctrl+R, prefix history on Up/Down, case-insensitive completion (Clink only) |

Machine-specific settings go in `%USERPROFILE%\autorun.local.cmd`, which is
called last and not committed.

## What you get

| Feature | Details |
|---|---|
| Prompt | `[user@host:C:\path]$` in the `.bashrc` colours; with Clink also `~` and the git branch |
| History | `history`, `h`, `hgrep`. Ctrl+R / Ctrl+S search, Up/Down prefix search and Emacs keys need Clink. Plain cmd has F7 (list) and F8 (prefix search) |
| Listing | `ls [-alR]`, `ll`, `la`, `l` (on top of `dir`) |
| Search | `grep [-inrvlcE] PATTERN [FILE\|DIR...]` on top of `findstr`, also reads a pipe. `find PATH -name X -type f\|d` on top of `dir /s /b`; `find /c ...` still reaches the Windows `find.exe` |
| Text | `cat`, `less`, `head -n`, `tail -n`, `tail -f`, `wc [-lwc]`, `diff`, `touch`, `which` (shows macros too) |
| Files | `rm -rf`, `cp -r`, `mv`, `mkdir -p`, `ln`, `mkcd`, `..`, `...`, `~`, `-`, `pwd` |
| System | `df`, `du [-s]`, `free`, `uptime`, `top`, `ps`, `psgrep`, `kill`, `ifconfig`, `myip`, `path`, `open`, `e.`, `sudo` (gsudo or UAC), `pbcopy`, `pbpaste`, `wpath` |
| Env | `export FOO=bar`, `env`, `printenv`, `unset`, `alias` |
| Misc | `now`, `date`, `time`, `md5sum`, `sha256sum`, `reload`, `g`, `gs`, `gl`, `gd`, `gp`, `gco`, `ga` |

## Limits of cmd.exe

- `grep` maps to `findstr`: regex support is basic (no `+`, `?`, `|`
  alternation, no `\b`), and `-r` cannot skip `.git` or `node_modules`.
- `find` prints absolute paths.
- `doskey` macros only apply when typed at the prompt, not inside `.bat`
  files, so scripts are not affected by them. The `bin` shims are on PATH
  though: a `.bat` run from such a session that calls `find` gets the shim,
  which forwards to the Windows `find.exe` whenever it sees a `/switch`.
- Sessions started with `cmd /c` skip the whole setup so build tools start
  fast and unchanged.
- Colour sequences in the prompt need Windows 10 or later.
