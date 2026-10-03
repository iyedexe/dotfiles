-- Clink prompt filter: [user@host:~/path] (branch) $   in the same colours as
-- .bashrc and the PowerShell profile. Registered by install.cmd via
-- `clink installscripts`. Clink itself provides Ctrl+R history search,
-- Emacs keys and completion; keybindings live in .inputrc next to this file.

local function git_branch()
    local f = io.popen('git rev-parse --abbrev-ref HEAD 2>nul')
    if not f then return '' end
    local b = f:read('*l')
    f:close()
    if b and b ~= '' then return ' (' .. b .. ')' end
    return ''
end

local function pretty_cwd()
    local cwd = os.getcwd()
    local home = os.getenv('USERPROFILE')
    if home and cwd:sub(1, #home):lower() == home:lower() then
        cwd = '~' .. cwd:sub(#home + 1)
    end
    return (cwd:gsub('\\', '/'))
end

local p = clink.promptfilter(30)
function p:filter(prompt)
    local user = os.getenv('USERNAME') or ''
    local host = os.getenv('COMPUTERNAME') or ''
    local E = '\027['
    return E .. '32m[' .. E .. '0m' .. E .. '31m' .. user .. E .. '0m' ..
           E .. '33m@' .. E .. '0m' .. E .. '32m' .. host .. E .. '0m:' ..
           E .. '36m' .. pretty_cwd() .. E .. '0m' .. E .. '32m]' .. E .. '0m' ..
           E .. '33m' .. git_branch() .. E .. '0m ' .. E .. '32m$' .. E .. '0m '
end
