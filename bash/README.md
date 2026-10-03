# bash: coloured PS1 prompt and Linux aliases

[`.bashrc`](.bashrc) gives bash a coloured prompt with the current git branch:

```
[user@host:~/path] (branch) $
```

green brackets, red user, yellow `@`, green host, cyan path, yellow branch.
The same prompt is reproduced in the [PowerShell profile and the cmd.exe
setup](../windows-aliases/), so every shell you open looks alike.

On top of the prompt it sets up history, readline and the aliases below.

## Install

Targets the bash that ships with Git for Windows, and works unchanged in WSL,
Linux and macOS. Install (Git Bash is a login shell, so `.bash_profile` has
to load `.bashrc`):

```sh
git clone https://github.com/iyedexe/dotfiles ~/dotfiles
echo '. ~/dotfiles/bash/.bashrc' >> ~/.bashrc
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

Machine-specific settings go in `~/.bashrc.local`, which is loaded last and
not committed.

## Just the prompt

If you only want the coloured PS1, these lines are all it takes:

```sh
parse_git_branch() {
    git branch 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}
export PS1="\[\e[32m\][\[\e[m\]\[\e[31m\]\u\[\e[m\]\[\e[33m\]@\[\e[m\]\[\e[32m\]\h\[\e[m\]:\[\e[36m\]\w\[\e[m\]\[\e[32m\]]\[\e[m\]\[\033[33m\]\$(parse_git_branch)\[\033[00m\] \[\e[32m\]\\$\[\e[m\] "
```
