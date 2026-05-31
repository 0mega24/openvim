local S   = require("vim.state")
local syn = require("vim.syntax")
local M   = {}

local function readFile(path)
    local f, err = io.open(path, "r")
    if not f then return nil, err end
    local lines = {}
    for line in f:lines() do lines[#lines+1] = line end
    f:close()
    return #lines > 0 and lines or { "" }
end

local function writeFile(path, lines)
    local f, err = io.open(path, "w")
    if not f then return false, err end
    for i, line in ipairs(lines) do
        f:write(line)
        if i < #lines then f:write("\n") end
    end
    f:close()
    return true
end

function M.cmdSave(path)
    path = path or S.filename
    if not path or path == "" then
        S.message = "No filename — use :w <filename>"
        return false
    end
    local bak     = path..".bak"
    local ok, err = writeFile(bak, S.buf)
    if not ok then
        S.message = "Error writing backup: "..(err or "?")
        return false
    end
    ok, err = writeFile(path, S.buf)
    if ok then
        os.remove(bak)
        S.filename = path
        S.modified  = false
        S.message   = string.format('"%s" %dL written', path, #S.buf)
        return true
    else
        S.message = "Error writing: "..(err or "?")
        return false
    end
end

function M.cmdOpen(path)
    if not path or path == "" then
        S.message = "Usage: :e <filename>"
        return
    end
    local lines, err = readFile(path)
    if not lines then
        S.buf      = { "" }
        S.filename = path
        S.modified = false
        S.message  = string.format('"%s" [New File]', path)
    else
        S.buf      = lines
        S.filename = path
        S.modified = false
        S.cx, S.cy, S.scrollX, S.scrollY = 1, 1, 0, 0
        S.message  = string.format('"%s" %dL', path, #S.buf)
    end
    S.undoStack = {}
    S.redoStack = {}
    syn.markBufDirty()
end

return M
