# dotfiles

Personal setup that follows me across machines: the same coloured prompt and
Linux-style commands in every shell I use (bash, PowerShell, cmd.exe), a few
tools I run myself, and reusable knowledge for Claude Code. Each part lives
in its own folder with its own README and installs independently. Clone once
and pick what you need.

```sh
git clone https://github.com/iyedexe/dotfiles ~/dotfiles
```

## What's inside

| Folder | What it is | Start here |
|---|---|---|
| [`bash/`](bash/) | `.bashrc` with the coloured PS1 prompt (`[user@host:~/path] (branch) $`), shared history with Ctrl+R, and Linux aliases. Targets Git Bash on Windows, works on Linux, macOS and WSL | [bash/README.md](bash/README.md) |
| [`windows-aliases/`](windows-aliases/) | The same prompt and Unix commands (`ls -la`, `grep -rn`, `find`, `df`, `rm -rf`, `export`...) for native Windows shells: a PowerShell profile and a cmd.exe AutoRun setup | [windows-aliases/README.md](windows-aliases/README.md) |
| [`revproxy/`](revproxy/) | Small reverse proxy in Python, managed with uv. One TOML file routes to services, static sites, redirects and WebSockets, and reloads itself on save | [revproxy/README.md](revproxy/README.md) |
| [`claude-skills/`](claude-skills/) | Five Claude Code skills distilled from classic programming books: clean code, functional programming, testing and debugging, data engineering, design and architecture | [claude-skills/README.md](claude-skills/README.md) |
| [`python-utils/`](python-utils/) | Standalone Python helpers. Currently a decorator that adds `to_dict` and `from_dict` to dataclasses | [python-utils/README.md](python-utils/README.md) |

## Quick install

Each command assumes the repo is cloned to `~/dotfiles`
(`%USERPROFILE%\dotfiles` on Windows). The folder READMEs have the details.

| Want | Run |
|---|---|
| bash prompt and aliases | `echo '. ~/dotfiles/bash/.bashrc' >> ~/.bashrc`. In Git Bash also: `echo '[ -f ~/.bashrc ] && . ~/.bashrc' >> ~/.bash_profile` |
| PowerShell | `Add-Content $PROFILE '. "$HOME\dotfiles\windows-aliases\powershell\Microsoft.PowerShell_profile.ps1"'` |
| Command Prompt | `%USERPROFILE%\dotfiles\windows-aliases\cmd\install.cmd` |
| Reverse proxy | `cd ~/dotfiles/revproxy && uv run revproxy -c examples/revproxy.toml` |
| Claude skills, every project | symlink each `claude-skills/*/` into `~/.claude/skills/` (loop in [claude-skills/README.md](claude-skills/README.md)) |

## Conventions

- Shell configs share one look: green brackets, red user, yellow `@`, green
  host, cyan path, yellow git branch. Change it in one shell, mirror it in the
  others.
- Machine-specific settings stay out of the repo: `~/.bashrc.local` for bash,
  `%USERPROFILE%\autorun.local.cmd` for cmd.exe.
- [`.gitattributes`](.gitattributes) checks out `.cmd`, `.bat` and `.ps1`
  files with CRLF line endings for Windows, and bash and Lua files with LF.
