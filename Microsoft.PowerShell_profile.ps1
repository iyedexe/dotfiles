# ============================================================================
# PowerShell profile that mimics a Linux bash environment.
#
# Works on Windows PowerShell 5.1 and PowerShell 7+. Gives you:
#   - the same prompt as .bashrc:  [user@host:~/path] (branch) $
#   - Ctrl+R reverse history search, Ctrl+A/E/W/U/K, Up/Down prefix search
#   - ls / ll / la / grep / find / head / tail / wc / touch / which / df / du /
#     free / rm -rf / cp -r / mkdir -p / export / env / .. / ... and more
#
# Install (pick one):
#   1. Dot-source from your real profile:
#        Add-Content $PROFILE '. "$HOME\dotfiles\Microsoft.PowerShell_profile.ps1"'
#   2. Or symlink it (needs an elevated prompt or Developer Mode):
#        New-Item -ItemType SymbolicLink -Path $PROFILE -Target "$HOME\dotfiles\Microsoft.PowerShell_profile.ps1" -Force
#
# Real GNU tools win: if grep.exe, find.exe (GNU, not the System32 one), sed,
# awk, etc. are on PATH (Git for Windows, MSYS2, scoop coreutils, busybox),
# the PowerShell fallbacks below are NOT defined and the real binary is used.
# Set $env:DOTFILES_USE_GIT_TOOLS=1 to prepend Git's usr/bin to PATH, or
# $env:DOTFILES_PURE_PS=1 to always use the PowerShell versions.
# ============================================================================

# ---------------------------------------------------------------- helpers ---
$script:IsWin = ($PSVersionTable.PSVersion.Major -lt 6) -or $IsWindows
$script:E = [char]27
function script:Color([string]$code, [string]$text) { "$E[${code}m$text$E[0m" }

# True if a native executable named $name exists and is not the Windows
# System32 one (Windows ships a find.exe and sort.exe that are not GNU).
function script:Test-NativeTool([string]$name) {
    if ($env:DOTFILES_PURE_PS) { return $false }          # force the PowerShell versions
    $exe = if ($script:IsWin) { "$name.exe" } else { $name }
    $cmd = Get-Command $exe -CommandType Application -ErrorAction SilentlyContinue
    if (-not $cmd) { return $false }
    if (-not $script:IsWin) { return $true }
    $sys = Join-Path $env:WINDIR 'System32'
    return -not ($cmd.Source -like "$sys*")
}

# Optionally put Git for Windows' GNU userland first on PATH.
if ($env:DOTFILES_USE_GIT_TOOLS -and $script:IsWin) {
    foreach ($base in @("$env:ProgramFiles\Git", "${env:ProgramFiles(x86)}\Git", "$env:LOCALAPPDATA\Programs\Git")) {
        $bin = Join-Path $base 'usr\bin'
        if (Test-Path $bin) { $env:PATH = "$bin;$env:PATH"; break }
    }
}

# Remove built-in aliases that shadow Linux semantics (aliases beat functions).
foreach ($a in 'ls', 'rm', 'cp', 'mv', 'cat', 'kill', 'curl', 'wget', 'diff', 'sleep', 'history', 'h', 'pwd', 'clear') {
    if (Test-Path "Alias:$a") { Remove-Item "Alias:$a" -Force -ErrorAction SilentlyContinue }
}

# Split "-rf" style flag bundles and paths out of an argument list.
# Returns an object with .Flags (array of chars) and .Rest (everything else).
function script:Split-Flags([object[]]$argv) {
    $flags = @(); $rest = @()
    foreach ($a in $argv) {
        if ($a -is [string] -and $a -match '^-[A-Za-z]+$') { $flags += $a.Substring(1).ToCharArray() }
        elseif ($a -is [string] -and $a -eq '--') { }
        else { $rest += $a }
    }
    return [PSCustomObject]@{ Flags = $flags; Rest = $rest }
}

# Absolute path -> path relative to the current directory, with forward slashes.
function script:Get-RelPath([string]$full) {
    $base = $PWD.Path.TrimEnd('\', '/')
    if ($full.StartsWith($base, [StringComparison]::OrdinalIgnoreCase)) { $full = $full.Substring($base.Length).TrimStart('\', '/') }
    return ($full -replace '\\', '/')
}

function script:Format-Bytes([double]$n) {
    foreach ($u in 'B', 'K', 'M', 'G', 'T') {
        if ($n -lt 1024) { return ('{0:0.#}{1}' -f $n, $u) }
        $n /= 1024
    }
    return ('{0:0.#}P' -f $n)
}

# ------------------------------------------------------------ PSReadLine ---
if (Get-Module -ListAvailable PSReadLine) {
    Import-Module PSReadLine -ErrorAction SilentlyContinue
    Set-PSReadLineOption -EditMode Emacs                 # Ctrl+A/E/K/U/W/Y, Alt+B/F...
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd
    Set-PSReadLineOption -HistoryNoDuplicates
    Set-PSReadLineOption -MaximumHistoryCount 10000
    Set-PSReadLineOption -BellStyle None
    Set-PSReadLineKeyHandler -Key Ctrl+r   -Function ReverseSearchHistory   # bash Ctrl+R
    Set-PSReadLineKeyHandler -Key Ctrl+s   -Function ForwardSearchHistory
    Set-PSReadLineKeyHandler -Key UpArrow  -Function HistorySearchBackward  # prefix search
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key Tab      -Function MenuComplete
    Set-PSReadLineKeyHandler -Key Ctrl+l   -Function ClearScreen
    Set-PSReadLineKeyHandler -Key Ctrl+d   -Function DeleteCharOrExit       # bash Ctrl+D
    Set-PSReadLineKeyHandler -Key Ctrl+w   -Function BackwardKillWord
    Set-PSReadLineKeyHandler -Key Alt+.    -Function YankLastArg            # bash Alt+.
    try {  # PSReadLine >= 2.1: inline fish-style history suggestions
        Set-PSReadLineOption -PredictionSource History -PredictionViewStyle InlineView -ErrorAction Stop
    } catch { }
}

# ---------------------------------------------------------------- prompt ---
# [user@host:~/cwd] (branch) $   with the same colours as .bashrc
function Get-GitBranch {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return '' }
    $b = git rev-parse --abbrev-ref HEAD 2>$null
    if ($LASTEXITCODE -eq 0 -and $b) { return " ($b)" }
    return ''
}
function prompt {
    $cwd = $PWD.Path
    if ($cwd.StartsWith($HOME)) { $cwd = '~' + $cwd.Substring($HOME.Length) }
    $cwd = $cwd -replace '\\', '/'
    $user = $env:USERNAME; if (-not $user) { $user = [Environment]::UserName }
    $hostn = $env:COMPUTERNAME; if (-not $hostn) { $hostn = [System.Net.Dns]::GetHostName() }
    $Host.UI.RawUI.WindowTitle = "$user@$hostn`:$cwd"
    $p = (Color 32 '[') + (Color 31 $user) + (Color 33 '@') + (Color 32 $hostn) + ':' +
         (Color 36 $cwd) + (Color 32 ']') + (Color 33 (Get-GitBranch)) + ' ' + (Color 32 '$') + ' '
    return $p
}

# -------------------------------------------------------------- navigate ---
function ..   { Set-Location .. }
function ...  { Set-Location ../.. }
function .... { Set-Location ../../.. }
function ~    { Set-Location $HOME }
function mkcd([string]$dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null; Set-Location $dir }
function pwd  { $PWD.Path -replace '\\', '/' }

# ------------------------------------------------------------------- ls ---
# ls [-alhR] [path...]    ll = ls -l    la = ls -la    l = ls
function ls {
    $o = Split-Flags $args; $flags = $o.Flags; $paths = $o.Rest
    if (-not $paths) { $paths = @('.') }
    $all = $flags -contains 'a'; $long = $flags -contains 'l'
    $human = $flags -contains 'h'; $recurse = $flags -contains 'R'
    $items = foreach ($p in $paths) {
        $gci = @{ Path = $p; Force = $all; ErrorAction = 'SilentlyContinue' }
        if ($recurse) { $gci.Recurse = $true }
        if ((Test-Path $p -PathType Container) -or $recurse) { Get-ChildItem @gci } else { Get-Item $p -ErrorAction SilentlyContinue }
    }
    if (-not $all) { $items = $items | Where-Object { $_.Name -notlike '.*' } }
    $items = $items | Sort-Object { -not $_.PSIsContainer }, Name
    $exeExt = if ($env:PATHEXT) { $env:PATHEXT.ToLower().Split(';') } else { @('.exe', '.sh') }
    $colorName = {
        param($i)
        if ($i.PSIsContainer) { Color '1;34' $i.Name }
        elseif ($i.LinkType) { Color '1;36' $i.Name }
        elseif ($exeExt -contains $i.Extension.ToLower()) { Color '1;32' $i.Name }
        else { $i.Name }
    }
    if ($long) {
        foreach ($i in $items) {
            $mode = if ($i.PSIsContainer) { 'd' } else { '-' }
            $mode += if ($i.IsReadOnly) { 'r--r--r--' } else { 'rw-rw-rw-' }
            $size = if ($i.PSIsContainer) { '-' } elseif ($human) { Format-Bytes $i.Length } else { $i.Length }
            $date = $i.LastWriteTime.ToString('yyyy-MM-dd HH:mm')
            '{0} {1,10} {2} {3}' -f $mode, $size, $date, (& $colorName $i)
        }
    } else {
        if (-not $items) { return }
        $w = ($items | ForEach-Object { $_.Name.Length } | Measure-Object -Maximum).Maximum + 2
        $cols = [Math]::Max(1, [Math]::Floor($Host.UI.RawUI.WindowSize.Width / $w))
        $line = ''; $n = 0
        foreach ($i in $items) {
            $line += (& $colorName $i) + (' ' * ($w - $i.Name.Length))
            if (++$n % $cols -eq 0) { $line; $line = '' }
        }
        if ($line) { $line }
    }
}
function ll { ls -lh @args }
function la { ls -lah @args }
function l  { ls @args }

# ----------------------------------------------------------------- grep ---
# grep [-inrvlcEw] PATTERN [FILE...]      or      cmd | grep PATTERN
if (-not (Test-NativeTool grep)) {
    function grep {
        $o = Split-Flags $args; $flags = $o.Flags; $rest = $o.Rest
        if (-not $rest) { Write-Error 'usage: grep [-inrvlcEw] PATTERN [FILE...]'; return }
        $pattern = [string]$rest[0]
        [object[]]$files = @(if ($rest.Count -gt 1) { $rest[1..($rest.Count - 1)] })
        if ($flags -notcontains 'E') { $pattern = [regex]::Escape($pattern) }
        if ($flags -contains 'w') { $pattern = "\b$pattern\b" }
        $ss = @{ Pattern = $pattern; CaseSensitive = ($flags -notcontains 'i') }
        if ($flags -contains 'v') { $ss.NotMatch = $true }
        $recurse = $flags -contains 'r'; $count = $flags -contains 'c'
        $listOnly = $flags -contains 'l'; $lineNo = $flags -contains 'n'
        $rxOpt = if ($ss.CaseSensitive) { 'None' } else { 'IgnoreCase' }
        $emit = {
            param($m, $showFile)
            $out = ''
            if ($showFile) { $out += (Color 35 (Get-RelPath $m.Path)) + (Color 36 ':') }
            if ($lineNo) { $out += (Color 32 $m.LineNumber) + (Color 36 ':') }
            $text = $m.Line
            if (-not $ss.NotMatch) { $text = [regex]::Replace($text, $ss.Pattern, { param($x) Color '1;31' $x.Value }, $rxOpt) }
            $out + $text
        }
        $piped = @($input | Out-String -Stream)
        if ($piped.Count -gt 0 -and -not $files) {
            $m = @($piped | Select-String @ss)
            if ($count) { return $m.Count }
            $m | ForEach-Object { & $emit $_ $false }
            return
        }
        if (-not $files) { $files = @('.'); $recurse = $true }
        $targets = @(foreach ($f in $files) {
            if (Test-Path $f -PathType Container) {
                if ($recurse) { Get-ChildItem $f -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '[\\/](\.git|node_modules|\.venv|__pycache__)[\\/]' } }
                else { Write-Warning "grep: ${f}: Is a directory" }
            } else { Get-Item $f -ErrorAction SilentlyContinue }
        })
        $multi = $targets.Count -gt 1
        $m = @($targets | Select-String @ss)
        if ($count) { return $m.Count }
        if ($listOnly) { return ($m | ForEach-Object { Get-RelPath $_.Path } | Select-Object -Unique) }
        $m | ForEach-Object { & $emit $_ $multi }
    }
}
function egrep { grep -E @args }
function psgrep([string]$name) { Get-Process | Where-Object { $_.ProcessName -like "*$name*" } }

# ----------------------------------------------------------------- find ---
# find [path] [-name|-iname PATTERN] [-type f|d] [-maxdepth N]
if (-not (Test-NativeTool find)) {
    function find {
        $path = '.'; $name = $null; $type = $null; $depth = $null; $i = 0
        if ($args.Count -gt 0 -and -not ([string]$args[0]).StartsWith('-')) { $path = $args[0]; $i = 1 }
        while ($i -lt $args.Count) {
            switch ($args[$i]) {
                '-name'     { $name = $args[++$i] }
                '-iname'    { $name = $args[++$i] }
                '-type'     { $type = $args[++$i] }
                '-maxdepth' { $depth = [int]$args[++$i] }
                default     { Write-Error "find: unknown predicate $($args[$i])"; return }
            }
            $i++
        }
        $gci = @{ Path = $path; Recurse = $true; Force = $true; ErrorAction = 'SilentlyContinue' }
        if ($null -ne $depth) { $gci.Depth = [Math]::Max(0, $depth - 1) }
        if ($name) { $gci.Filter = $name }
        if ($type -eq 'f') { $gci.File = $true } elseif ($type -eq 'd') { $gci.Directory = $true }
        $root = (Resolve-Path $path).Path
        Get-ChildItem @gci | ForEach-Object {
            $rel = $_.FullName.Substring($root.Length).TrimStart('\', '/')
            ($path.TrimEnd('\', '/') + '/' + $rel) -replace '\\', '/'
        }
    }
}

# ---------------------------------------------------------- text tools ---
function cat  { Get-Content @args }
if (-not (Test-NativeTool head)) {
    function head {
        $n = 10; $files = @()
        for ($i = 0; $i -lt $args.Count; $i++) {
            if ($args[$i] -eq '-n') { $n = [int]$args[++$i] }
            elseif ($args[$i] -match '^-(\d+)$') { $n = [int]$Matches[1] }
            else { $files += $args[$i] }
        }
        if ($files) { foreach ($f in $files) { Get-Content $f -TotalCount $n } } else { $input | Select-Object -First $n }
    }
}
if (-not (Test-NativeTool tail)) {
    function tail {
        $n = 10; $follow = $false; $files = @()
        for ($i = 0; $i -lt $args.Count; $i++) {
            if ($args[$i] -eq '-n') { $n = [int]$args[++$i] }
            elseif ($args[$i] -match '^-(\d+)$') { $n = [int]$Matches[1] }
            elseif ($args[$i] -in '-f', '-F') { $follow = $true }
            elseif ($args[$i] -eq '-fn') { $follow = $true; $n = [int]$args[++$i] }
            else { $files += $args[$i] }
        }
        if ($files) { foreach ($f in $files) { Get-Content $f -Tail $n -Wait:$follow } } else { $input | Select-Object -Last $n }
    }
}
if (-not (Test-NativeTool wc)) {
    function wc {
        $o = Split-Flags $args; $flags = $o.Flags; $files = $o.Rest
        $text = if ($files) { foreach ($f in $files) { Get-Content $f -Raw } } else { ($input | Out-String -Stream) -join "`n" }
        $text = [string]$text
        $lines = ([regex]::Matches($text, "`n")).Count
        $words = ([regex]::Matches($text, '\S+')).Count
        $chars = $text.Length
        if ($flags -contains 'l') { return $lines }
        if ($flags -contains 'w') { return $words }
        if ($flags -contains 'c' -or $flags -contains 'm') { return $chars }
        '{0,8}{1,8}{2,8}' -f $lines, $words, $chars
    }
}
if (-not (Test-NativeTool less)) { function less { $input | Out-Host -Paging } }
function touch {
    foreach ($f in $args) {
        if (Test-Path $f) { (Get-Item $f).LastWriteTime = Get-Date } else { New-Item -ItemType File -Path $f | Out-Null }
    }
}
function which {
    foreach ($n in $args) {
        $c = Get-Command $n -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $c) { Write-Error "which: no $n in PATH"; continue }
        switch ($c.CommandType) {
            'Application' { $c.Source }
            'Alias'       { "$n -> $($c.Definition)" }
            'Function'    { "${n}: shell function" }
            default       { "${n}: $($c.CommandType) $($c.Source)".Trim() }
        }
    }
}
function diff([string]$a, [string]$b) {
    Compare-Object (Get-Content $a) (Get-Content $b) -IncludeEqual:$false | ForEach-Object {
        $mark = if ($_.SideIndicator -eq '<=') { Color 31 "< $($_.InputObject)" } else { Color 32 "> $($_.InputObject)" }
        $mark
    }
}

# ------------------------------------------------------------ file ops ---
# rm [-rf] path...   cp [-r] src dst   mv src dst   mkdir [-p] dir...   ln -s target link
function rm {
    $o = Split-Flags $args; $flags = $o.Flags; $paths = $o.Rest
    $ri = @{ ErrorAction = 'Stop' }
    if ($flags -contains 'r' -or $flags -contains 'R') { $ri.Recurse = $true }
    if ($flags -contains 'f') { $ri.Force = $true; $ri.ErrorAction = 'SilentlyContinue' }
    foreach ($p in $paths) { Remove-Item $p @ri }
}
function cp {
    $o = Split-Flags $args; $flags = $o.Flags; $paths = $o.Rest
    $ci = @{}
    if ($flags -contains 'r' -or $flags -contains 'R') { $ci.Recurse = $true }
    if ($flags -contains 'f') { $ci.Force = $true }
    if ($paths.Count -lt 2) { Write-Error 'usage: cp [-rf] SOURCE... DEST'; return }
    Copy-Item @($paths[0..($paths.Count - 2)]) -Destination $paths[-1] @ci
}
function mv { Move-Item @args }
function mkdir {
    $o = Split-Flags $args; $flags = $o.Flags; $dirs = $o.Rest   # -p is implicit
    foreach ($d in $dirs) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
}
function ln {
    $o = Split-Flags $args; $flags = $o.Flags; $p = $o.Rest
    $type = if ($flags -contains 's') { 'SymbolicLink' } else { 'HardLink' }
    New-Item -ItemType $type -Path $p[1] -Target (Resolve-Path $p[0]).Path | Out-Null
}
function chmod { Write-Warning 'chmod: no-op on Windows (use icacls / Set-Acl)' }

# ------------------------------------------------------------- system ---
function df {
    $human = $args -contains '-h'
    $fmt = { param($f, $s, $u, $a, $p, $m) '{0,-12}{1,10}{2,10}{3,10}{4,6} {5}' -f $f, $s, $u, $a, $p, $m }
    & $fmt 'Filesystem' 'Size' 'Used' 'Avail' 'Use%' 'Mounted on'
    if ($script:IsWin) {
        Get-CimInstance Win32_LogicalDisk | Where-Object { $_.Size } | ForEach-Object {
            $used = $_.Size - $_.FreeSpace
            $pct = [int](100 * $used / $_.Size)
            $sz = if ($human) { Format-Bytes $_.Size } else { [long]($_.Size / 1KB) }
            $us = if ($human) { Format-Bytes $used } else { [long]($used / 1KB) }
            $av = if ($human) { Format-Bytes $_.FreeSpace } else { [long]($_.FreeSpace / 1KB) }
            & $fmt $_.DeviceID $sz $us $av "$pct%" ($_.VolumeName, $_.DeviceID)[[string]::IsNullOrEmpty($_.VolumeName)]
        }
    } else {
        Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -or $_.Free } | ForEach-Object {
            $sz = $_.Used + $_.Free; $pct = if ($sz) { [int](100 * $_.Used / $sz) } else { 0 }
            & $fmt $_.Name (Format-Bytes $sz) (Format-Bytes $_.Used) (Format-Bytes $_.Free) "$pct%" $_.Root
        }
    }
}
function du {
    $o = Split-Flags $args; $flags = $o.Flags; $paths = $o.Rest
    if (-not $paths) { $paths = @('.') }
    $summary = $flags -contains 's'
    $size = { param($p) (Get-ChildItem $p -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum }
    foreach ($p in $paths) {
        if ($summary -or (Test-Path $p -PathType Leaf)) {
            $b = if (Test-Path $p -PathType Leaf) { (Get-Item $p).Length } else { & $size $p }
            '{0,8}  {1}' -f (Format-Bytes $b), $p
        } else {
            Get-ChildItem $p -Force -ErrorAction SilentlyContinue | Sort-Object { -not $_.PSIsContainer }, Name | ForEach-Object {
                $b = if ($_.PSIsContainer) { & $size $_.FullName } else { $_.Length }
                '{0,8}  {1}' -f (Format-Bytes $b), $_.Name
            }
            '{0,8}  {1}' -f (Format-Bytes (& $size $p)), 'total'
        }
    }
}
function free {
    if (-not $script:IsWin) { Write-Warning 'free: Windows only'; return }
    $os = Get-CimInstance Win32_OperatingSystem
    $total = $os.TotalVisibleMemorySize * 1KB; $avail = $os.FreePhysicalMemory * 1KB
    '{0,-8}{1,12}{2,12}{3,12}' -f '', 'total', 'used', 'free'
    '{0,-8}{1,12}{2,12}{3,12}' -f 'Mem:', (Format-Bytes $total), (Format-Bytes ($total - $avail)), (Format-Bytes $avail)
}
function uptime {
    if ($script:IsWin) { $boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime } else { $boot = (Get-Date) - [TimeSpan]::FromSeconds((Get-Content /proc/uptime).Split(' ')[0]) }
    $up = (Get-Date) - $boot
    'up {0}d {1:00}h {2:00}m (since {3:yyyy-MM-dd HH:mm})' -f $up.Days, $up.Hours, $up.Minutes, $boot
}
function kill {
    $o = Split-Flags $args; $flags = $o.Flags; $ids = $o.Rest
    $force = ($args -contains '-9') -or ($flags -contains 'f') -or ($flags -contains 'K')
    foreach ($id in ($ids | Where-Object { $_ -notmatch '^-\d+$' })) { Stop-Process -Id $id -Force:$force }
}
function top { Get-Process | Sort-Object CPU -Descending | Select-Object -First 20 Id, ProcessName, CPU, @{n='Mem(MB)';e={[int]($_.WorkingSet64/1MB)}} | Format-Table -AutoSize }
function ifconfig { if ($script:IsWin) { ipconfig @args } else { ip addr } }
function sudo {
    if (Get-Command gsudo -ErrorAction SilentlyContinue) { gsudo @args; return }
    if (-not $script:IsWin) { & /usr/bin/sudo @args; return }
    $exe = (Get-Process -Id $PID).Path
    Start-Process $exe -Verb RunAs -ArgumentList (@('-NoExit', '-Command') + ($args -join ' '))
}
function open { if ($script:IsWin) { Start-Process @args } else { xdg-open @args } }
function reload { . $PROFILE; Write-Host 'profile reloaded' }

# ---------------------------------------------------------- environment ---
# export NAME=value | export NAME value      env / printenv      unset NAME
function export {
    foreach ($a in $args) {
        if ($a -match '^([^=]+)=(.*)$') { Set-Item "Env:$($Matches[1])" $Matches[2] }
        elseif ($args.Count -eq 2) { Set-Item "Env:$($args[0])" $args[1]; return }
        else { Get-Item "Env:$a" -ErrorAction SilentlyContinue | ForEach-Object { "$($_.Name)=$($_.Value)" } }
    }
}
function env      { Get-ChildItem Env: | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Value)" } }
function printenv { if ($args) { foreach ($n in $args) { (Get-Item "Env:$n" -ErrorAction SilentlyContinue).Value } } else { env } }
function unset    { foreach ($n in $args) { Remove-Item "Env:$n" -ErrorAction SilentlyContinue } }
function alias    { Get-Alias @args | ForEach-Object { "$($_.Name)='$($_.Definition)'" } }

# --------------------------------------------------------------- history ---
# history [N] | grep foo         !!  re-runs the last command
function history {
    $items = Get-History
    if ($args -and $args[0] -match '^\d+$') { $items = $items | Select-Object -Last ([int]$args[0]) }
    $items | ForEach-Object { '{0,5}  {1}' -f $_.Id, $_.CommandLine }
}
function h { history @args }
function hgrep([string]$p) { history | Where-Object { $_ -match $p } }
function !! { $last = (Get-History | Select-Object -Last 1).CommandLine; Write-Host $last; Invoke-Expression $last }

# ------------------------------------------------------------------ misc ---
function time {
    $cmd = $args[0]; [object[]]$rest = @(if ($args.Count -gt 1) { $args[1..($args.Count - 1)] })
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try { & $cmd @rest } finally { $sw.Stop(); Write-Host ('real {0:0.000}s' -f $sw.Elapsed.TotalSeconds) }
}
function clear { Clear-Host }
function c     { Clear-Host }
function date {
    # accepts strftime-style formats: date +%Y-%m-%d_%H:%M:%S
    if (-not $args) { return Get-Date -Format 'ddd MMM dd HH:mm:ss yyyy' }
    if ($args[0] -eq '+%s') { return [int][double]::Parse((Get-Date -UFormat %s)) }
    $map = @(@('%Y','yyyy'), @('%y','yy'), @('%m','MM'), @('%d','dd'), @('%H','HH'), @('%I','hh'), @('%M','mm'), @('%S','ss'), @('%p','tt'),
             @('%b','MMM'), @('%B','MMMM'), @('%a','ddd'), @('%A','dddd'), @('%Z','zzz'), @('%F','yyyy-MM-dd'), @('%T','HH:mm:ss'), @('%%','%'))
    $fmt = ([string]$args[0]) -replace '^\+', ''
    foreach ($kv in $map) { $fmt = $fmt.Replace($kv[0], $kv[1]) }   # String.Replace is case-sensitive
    Get-Date -Format $fmt
}
function sleep([double]$s) { Start-Sleep -Seconds $s }
function md5sum([string]$f)    { (Get-FileHash $f -Algorithm MD5).Hash.ToLower() + '  ' + $f }
function sha256sum([string]$f) { (Get-FileHash $f -Algorithm SHA256).Hash.ToLower() + '  ' + $f }
function g  { git @args }
function gs { git status -sb @args }
function gl { git log --oneline --graph --decorate -20 @args }
function gd { git diff @args }

# Behave like bash for a few native tools that ship with Windows 10+.
if ($script:IsWin -and (Test-Path "$env:WINDIR\System32\curl.exe")) { Set-Alias curl "$env:WINDIR\System32\curl.exe" -Option AllScope }
if ($script:IsWin -and (Test-Path "$env:WINDIR\System32\tar.exe"))  { Set-Alias tar  "$env:WINDIR\System32\tar.exe"  -Option AllScope }
if (-not (Get-Command wget -ErrorAction SilentlyContinue)) { function wget([string]$url) { Invoke-WebRequest $url -OutFile (Split-Path $url -Leaf) } }
