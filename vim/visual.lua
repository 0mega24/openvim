local S        = require("vim.state")
local edit     = require("vim.edit")
local syn      = require("vim.syntax")
local motion   = require("vim.motion")
local keyboard = require("keyboard")

local M = {}

function M.visualKey(char, code)
    local kb = keyboard

    if char == "h" or code == kb.keys.left then
        S.cx = math.max(1, S.cx-1)
    elseif char == "l" or code == kb.keys.right then
        S.cx = math.min(math.max(1,#S.buf[S.cy]), S.cx+1)
    elseif char == "k" or code == kb.keys.up then
        S.cy = math.max(1, S.cy-1); edit.clampCursor()
    elseif char == "j" or code == kb.keys.down then
        S.cy = math.min(#S.buf, S.cy+1); edit.clampCursor()
    elseif char == "w" then motion.wordForward();  edit.clampCursor()
    elseif char == "W" then motion.WORDForward();  edit.clampCursor()
    elseif char == "b" then motion.wordBack();     edit.clampCursor()
    elseif char == "B" then motion.WORDBack();     edit.clampCursor()
    elseif char == "e" then motion.wordEnd();      edit.clampCursor()
    elseif char == "E" then motion.WORDEnd();      edit.clampCursor()
    elseif char == "0" then S.cx = 1
    elseif char == "^" then motion.firstNonBlank()
    elseif char == "$" then S.cx = math.max(1, #S.buf[S.cy])
    elseif char == "G" then S.cy = #S.buf; S.cx = 1

    elseif kb.isControlDown() and code == kb.keys.lbracket then
        S.mode = "normal"; S.message = ""

    elseif char == "d" or char == "x" then
        edit.snapshot()
        local r1 = math.min(S.vy, S.cy)
        local r2 = math.max(S.vy, S.cy)
        S.clipboard = {}
        S.clipboardLine = true
        for i = r1, r2 do S.clipboard[#S.clipboard+1] = S.buf[i] end
        for _  = r1, r2 do table.remove(S.buf, r1) end
        if #S.buf == 0 then S.buf={""} end
        S.cy = math.min(r1, #S.buf); S.cx = 1
        S.modified = true
        syn.markBufDirty()
        S.mode    = "normal"
        S.message = (r2-r1+1).." line(s) deleted"

    elseif char == "y" then
        local r1 = math.min(S.vy, S.cy)
        local r2 = math.max(S.vy, S.cy)
        S.clipboard = {}
        S.clipboardLine = true
        for i = r1, r2 do S.clipboard[#S.clipboard+1] = S.buf[i] end
        S.mode    = "normal"
        S.message = #S.clipboard.." line(s) yanked"

    elseif char == "~" then
        edit.snapshot()
        local r1 = math.min(S.vy, S.cy)
        local r2 = math.max(S.vy, S.cy)
        for i = r1, r2 do
            local col1 = (i==r1) and math.min(S.vx,S.cx) or 1
            local col2 = (i==r2) and math.max(S.vx,S.cx) or #S.buf[i]
            edit.toggleCase(i, col1, col2-col1+1)
        end
        S.mode = "normal"

    elseif char == ">" then
        edit.snapshot()
        local r1 = math.min(S.vy, S.cy)
        local r2 = math.max(S.vy, S.cy)
        local ind = string.rep(" ", require("vim.config").cfg.tabWidth)
        for i = r1, r2 do S.buf[i] = ind..S.buf[i] end
        S.modified = true; syn.markBufDirty(r1)
        S.mode = "normal"

    elseif char == "<" then
        edit.snapshot()
        local r1 = math.min(S.vy, S.cy)
        local r2 = math.max(S.vy, S.cy)
        local tw = require("vim.config").cfg.tabWidth
        for i = r1, r2 do
            S.buf[i] = S.buf[i]:gsub("^"..string.rep(" ",tw), "", 1)
        end
        S.modified = true; syn.markBufDirty(r1)
        S.mode = "normal"
    end
end

return M
