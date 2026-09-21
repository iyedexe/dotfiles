# ============================================================================
# ~/.bashrc  -  Git Bash on Windows (primary target), also WSL / Linux / macOS
#
# Companion of Microsoft.PowerShell_profile.ps1: same prompt, same history
# behaviour, same aliases and helpers, so both shells feel identical.
#
# Install in Git Bash (home is C:\Users\<you>):
#   git clone https://github.com/iyedexe/dotfiles ~/dotfiles
#   echo '. ~/dotfiles/.bashrc' >> ~/.bashrc
#   echo '[ -f ~/.bashrc ] && . ~/.bashrc' >> ~/.bash_profile   # Git Bash is a login shell
# ============================================================================

# Only for interactive shells.
case $- in *i*) ;; *) return ;; esac

# ------------------------------------------------------------ platform ---
IS_MSYS=0; IS_WSL=0; IS_MAC=0
case "$OSTYPE" in
    msys*|cygwin*) IS_MSYS=1 ;;                     # Git Bash / MSYS2 / Cygwin
    darwin*)       IS_MAC=1 ;;
esac
[ -f /proc/version ] && grep -qi microsoft /proc/version 2>/dev/null && IS_WSL=1

# ------------------------------------------------------------- history ---
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth:erasedups        # no dupes, no lines starting with space
HISTIGNORE='ls:ll:la:cd:pwd:clear:c:history:h:exit'
HISTTIMEFORMAT='%F %T  '
shopt -s histappend                     # append, don't overwrite, across sessions
shopt -s cmdhist                        # multi-line commands saved as one entry
PROMPT_COMMAND="history -a; ${PROMPT_COMMAND:-:}"   # write history after each command

# ------------------------------------------------------------ readline ---
# Ctrl+R / Ctrl+S reverse and forward history search (Ctrl+S needs flow
# control off), Up/Down search history by what you've typed so far, and a
# friendlier completion. Put in .bashrc so a single file is enough.
stty -ixon 2>/dev/null
bind '"\C-r": reverse-search-history'
bind '"\C-s": forward-search-history'
bind '"\e[A": history-search-backward'  # Up
bind '"\e[B": history-search-forward'   # Down
bind '"\e[1;5C": forward-word'          # Ctrl+Right
bind '"\e[1;5D": backward-word'         # Ctrl+Left
bind 'set completion-ignore-case on'
bind 'set show-all-if-ambiguous on'
bind 'set menu-complete-display-prefix on'
bind 'set colored-stats on'
bind 'set colored-completion-prefix on'
bind 'set bell-style none'
bind 'set mark-symlinked-directories on'
# Emacs bindings (Ctrl+A/E/K/U/W/Y, Alt+B/F, Alt+.) are the readline default.

# --------------------------------------------------------------- shell ---
shopt -s checkwinsize        # keep $LINES/$COLUMNS right after resize
shopt -s autocd 2>/dev/null  # type a directory name to cd into it
shopt -s cdspell             # fix minor typos in cd
shopt -s dirspell 2>/dev/null
shopt -s globstar 2>/dev/null   # ** recursive glob
shopt -s no_empty_cmd_completion
export EDITOR="${EDITOR:-vim}"
export LESS='-R -F -X -i'    # colours, quit if one screen, keep on screen, smart case
export PAGER=less

# ------------------------------------------------------------- colours ---
if command -v dircolors >/dev/null 2>&1; then
    eval "$(dircolors -b 2>/dev/null)"
    LS_COLOR='--color=auto'
elif ls -G / >/dev/null 2>&1; then   # BSD / macOS
    export CLICOLOR=1
    LS_COLOR='-G'
fi
export GREP_COLORS='mt=1;31:fn=35:ln=32:se=36'   # match red, file magenta, line green

# -------------------------------------------------------------- prompt ---
# [user@host:~/cwd] (branch) $   (mirrored in the PowerShell profile)
parse_git_branch() {
    git branch 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}
export PS1="\[\e[32m\][\[\e[m\]\[\e[31m\]\u\[\e[m\]\[\e[33m\]@\[\e[m\]\[\e[32m\]\h\[\e[m\]:\[\e[36m\]\w\[\e[m\]\[\e[32m\]]\[\e[m\]\[\033[33m\]\$(parse_git_branch)\[\033[00m\] \[\e[32m\]\\$\[\e[m\] "
# Terminal title: user@host:cwd
case "$TERM" in xterm*|rxvt*|screen*|tmux*) PS1="\[\e]0;\u@\h:\w\a\]$PS1" ;; esac

# ------------------------------------------------------------ navigate ---
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'
alias -- -='cd -'
mkcd() { mkdir -p -- "$1" && cd -- "$1"; }

# ----------------------------------------------------------- ls / find ---
alias ls="ls $LS_COLOR -F"
alias ll='ls -lh'
alias la='ls -lah'
alias l='ls'
alias lt='ls -lt'            # newest last
alias grep='grep --color=auto'
alias egrep='grep -E --color=auto'
alias fgrep='grep -F --color=auto'
# rg-style recursive grep that skips the usual junk
gr() { grep -rn --color=auto --exclude-dir={.git,node_modules,.venv,__pycache__,target,dist,build} "$@"; }
psgrep() { ps aux | grep -i --color=auto "[${1:0:1}]${1:1}"; }
if diff --color=auto /dev/null /dev/null >/dev/null 2>&1; then alias diff='diff --color=auto -u'; else alias diff='diff -u'; fi

# ------------------------------------------------------------ file ops ---
alias rm='rm -I'             # ask once when deleting 3+ files or recursively
alias cp='cp -i'
alias mv='mv -i'
alias mkdir='mkdir -pv'
alias ln='ln -v'

# -------------------------------------------------------------- system ---
alias df='df -h'
alias du='du -h'
alias dus='du -sh * 2>/dev/null | sort -h'   # sizes of everything here, sorted
alias free='free -h'
ports() { if command -v ss >/dev/null 2>&1; then ss -tulpn; elif [ "$IS_MSYS" = 1 ]; then netstat -ano | grep -i listening; else netstat -tulpn; fi; }
myip() { curl -s https://ifconfig.me; echo; }
alias path='echo -e "${PATH//:/\\n}"'
alias reload='. ~/.bashrc && echo "bashrc reloaded"'
alias c='clear'
alias h='history'
hgrep() { history | grep -i --color=auto "$@"; }
alias now='date +%Y-%m-%d_%H:%M:%S'
alias week='date +%V'
alias wget='wget -c'         # resume downloads
alias sha256='sha256sum'
# open: a file with its default app, a directory in the file manager, or a URL
if   [ "$IS_MSYS" = 1 ]; then open() { start "${@:-.}"; }
elif [ "$IS_WSL" = 1 ];  then open() { explorer.exe "$(wslpath -w "${1:-.}")"; }
elif [ "$IS_MAC" = 0 ];  then open() { xdg-open "${1:-.}" >/dev/null 2>&1 & }
fi

# ---------------------------------------------------------------- git ---
alias g='git'
alias gs='git status -sb'
alias gl='git log --oneline --graph --decorate -20'
alias gd='git diff'
alias gp='git pull'
alias gc='git commit'
alias gco='git checkout'
alias ga='git add'

# ------------------------------------------------------------- helpers ---
# extract any archive:  extract file.tar.gz
extract() {
    [ -f "$1" ] || { echo "extract: '$1' is not a file" >&2; return 1; }
    case "$1" in
        *.tar.bz2|*.tbz2) tar xjf "$1" ;;
        *.tar.gz|*.tgz)   tar xzf "$1" ;;
        *.tar.xz|*.txz)   tar xJf "$1" ;;
        *.tar)            tar xf "$1" ;;
        *.bz2)            bunzip2 "$1" ;;
        *.gz)             gunzip "$1" ;;
        *.xz)             unxz "$1" ;;
        *.zip)            unzip "$1" ;;
        *.rar)            unrar x "$1" ;;
        *.7z)             7z x "$1" ;;
        *.Z)              uncompress "$1" ;;
        *) echo "extract: don't know how to extract '$1'" >&2; return 1 ;;
    esac
}
# make a tar.gz of a directory:  targz dir
targz() { tar czf "${1%/}.tar.gz" "${1%/}"; }
# find files by name from here:  ff '*.py'
ff() { find . -iname "$1" 2>/dev/null; }
# find directories by name:  fd 'src'  (skipped if the fd tool is installed)
command -v fd >/dev/null 2>&1 || fd() { find . -type d -iname "*$1*" 2>/dev/null; }
# cd to a git repo root
groot() { cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"; }
# which, but also shows aliases and functions
which() { type -a "$@" 2>/dev/null || command which "$@"; }
# create and open a scratch file in the editor
scratch() { "$EDITOR" "$(mktemp /tmp/scratch.XXXXXX)"; }
# timer:  t 5m  ->  waits then beeps
t() { sleep "$1" && printf '\a%s done\n' "$1"; }

# ------------------------------------------------------- Git Bash / WSL ---
if [ "$IS_MSYS" = 1 ]; then
    # Interactive Windows console programs need winpty under mintty, or they
    # hang / show no prompt. Only in mintty (Git Bash window), not in
    # Windows Terminal or VS Code where ConPTY handles it.
    if command -v winpty >/dev/null 2>&1 && [ -n "$MSYSTEM" ] && [[ "$TERM" == xterm* ]] && [ -z "$WT_SESSION" ] && [ -z "$VSCODE_PID" ]; then
        for _p in python python3 node php mysql psql ipython; do
            command -v "$_p.exe" >/dev/null 2>&1 && alias "$_p=winpty $_p.exe"
        done
        unset _p
    fi
    # Windows tools standing in for the Linux ones
    alias ifconfig='ipconfig'
    alias ipconfig='ipconfig.exe'
    alias free='powershell.exe -NoProfile -Command "\$o=Get-CimInstance Win32_OperatingSystem; \"{0,-6}{1,10}{2,10}{3,10}\" -f \"(MB)\",\"total\",\"used\",\"free\"; \"{0,-6}{1,10:N0}{2,10:N0}{3,10:N0}\" -f \"Mem:\",(\$o.TotalVisibleMemorySize/1KB),((\$o.TotalVisibleMemorySize-\$o.FreePhysicalMemory)/1KB),(\$o.FreePhysicalMemory/1KB)" | sed "s/\r//"'
    alias uptime='powershell.exe -NoProfile -Command "\$b=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime; \$u=(Get-Date)-\$b; \"up {0}d {1:00}h {2:00}m (since {3:yyyy-MM-dd HH:mm})\" -f \$u.Days,\$u.Hours,\$u.Minutes,\$b" | sed "s/\r//"'
    alias top='powershell.exe -NoProfile -Command "Get-Process | Sort-Object CPU -Descending | Select-Object -First 20 Id,ProcessName,CPU,@{n=\"Mem(MB)\";e={[int](\$_.WorkingSet64/1MB)}} | Format-Table -AutoSize" | sed "s/\r//"'
    kill9() { taskkill //F //PID "$1"; }          # kill a Windows PID hard
    # clipboard, like macOS
    alias pbcopy='clip'
    alias pbpaste='powershell.exe -NoProfile -Command Get-Clipboard | sed "s/\r//"'
    # paths: wpath ~/x -> C:\Users\you\x ; upath 'C:\x' -> /c/x
    wpath() { cygpath -w "${1:-.}"; }
    upath() { cygpath -u "$1"; }
    alias e.='explorer .'
    # elevate: sudo <cmd> uses gsudo if installed
    command -v gsudo >/dev/null 2>&1 && alias sudo='gsudo'
    # dotfiles live here on Windows too
    export MSYS=winsymlinks:nativestrict   # ln -s makes real Windows symlinks (needs Developer Mode)
    export MSYS_NO_PATHCONV=0
elif [ "$IS_WSL" = 1 ]; then
    alias pbcopy='clip.exe'
    alias pbpaste='powershell.exe -NoProfile -Command Get-Clipboard | sed "s/\r//"'
    wpath() { wslpath -w "${1:-.}"; }
    upath() { wslpath -u "$1"; }
    alias e.='explorer.exe .'
fi

# ---------------------------------------------------------- completion ---
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    elif [ -f /usr/local/etc/bash_completion ]; then
        . /usr/local/etc/bash_completion   # Homebrew
    fi
    # Git for Windows ships git completion here (already loaded by its own
    # profile in most installs; harmless to load twice)
    [ -f /mingw64/share/git/completion/git-completion.bash ] && . /mingw64/share/git/completion/git-completion.bash
    # make the git aliases complete like git itself
    if declare -F __git_complete >/dev/null 2>&1; then
        __git_complete g __git_main; __git_complete gco _git_checkout; __git_complete ga _git_add
        __git_complete gd _git_diff; __git_complete gl _git_log; __git_complete gc _git_commit
    fi
fi

# ----------------------------------------------------------- local bits ---
# Machine-specific settings that should not be committed.
[ -f ~/.bashrc.local ] && . ~/.bashrc.local
