local S = require("vim.state")
local M = {}

M.cfg = {
    showNumbers  = true,
    relativeNums = true,
    cursorLine   = true,
    colorColumn  = 80,
    tabWidth     = 2,
    scrollOff    = 5,
    syntax       = nil,   -- nil = auto-detect, "lua", or "text"
}

function M.numWidth()
    if not M.cfg.showNumbers then return 0 end
    return #tostring(#S.buf) + 1
end

-- Load a vimrc-style file: execute each non-comment line as an ex command.
function M.loadVimrc(path)
    local f = io.open(path, "r")
    if not f then return end
    -- Lazy-require to avoid load-order issues.
    local ok, cmd = pcall(require, "vim.command")
    if not ok then f:close(); return end
    for rawline in f:lines() do
        local line = rawline:match("^%s*(.-)%s*$")
        if line ~= "" and not line:match('^"') then
            pcall(cmd.execCommand, line)
        end
    end
    f:close()
end

return M
