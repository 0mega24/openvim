local S        = require("vim.state")
local edit     = require("vim.edit")
local syn      = require("vim.syntax")
local keyboard = require("keyboard")
local cfg      = require("vim.config")

local unicode_ok, unicode = pcall(require, "unicode")

local M = {}

function M.insertKey(char, code)
    local kb = keyboard

    if kb.isControlDown() and code == kb.keys.lbracket then
        S.mode = "normal"; S.cx = math.max(1,S.cx-1); edit.clampCursor(); S.message=""

    elseif kb.isControlDown() and code == kb.keys.w then
        -- delete word backward
        if S.cx > 1 then
            local line = S.buf[S.cy]
            local i = S.cx-1
            while i>=1 and (line:sub(i,i)==" " or line:sub(i,i)=="\t") do i=i-1 end
            while i>=1 and line:sub(i,i)~=" " and line:sub(i,i)~="\t" do i=i-1 end
            local newcx = i+1
            S.buf[S.cy] = line:sub(1,newcx-1)..line:sub(S.cx)
            S.cx = newcx
            S.modified = true
            syn.markBufDirty(S.cy)
        elseif S.cy > 1 then
            local pl = #S.buf[S.cy-1]
            edit.joinLines(S.cy-1)
            S.cy=S.cy-1; S.cx=pl+1
        end

    elseif kb.isControlDown() and code == kb.keys.u then
        -- delete to beginning of line
        if S.cx > 1 then
            S.buf[S.cy] = S.buf[S.cy]:sub(S.cx)
            S.cx = 1
            S.modified = true
            syn.markBufDirty(S.cy)
        end

    elseif code == kb.keys.back then
        if S.cx > 1 then
            S.cx = S.cx-1
            edit.deleteCharAt(S.cy, S.cx)
        elseif S.cy > 1 then
            local pl = #S.buf[S.cy-1]
            edit.joinLines(S.cy-1)
            S.cy=S.cy-1; S.cx=pl+1
        end
        S.modified = true

    elseif code == kb.keys.enter then
        -- auto-indent: copy leading whitespace from current line
        local lead = S.buf[S.cy]:match("^(%s*)")
        edit.snapshot(); edit.breakLine()
        if #lead > 0 then
            S.buf[S.cy] = lead..S.buf[S.cy]
            S.cx = #lead+1
            S.modified = true
            syn.markBufDirty(S.cy)
        end

    elseif code == kb.keys.delete then
        if S.cx <= #S.buf[S.cy] then edit.deleteCharAt(S.cy, S.cx)
        elseif S.cy < #S.buf then edit.joinLines(S.cy) end
        S.modified = true

    elseif code == kb.keys.left  then S.cx = math.max(1, S.cx-1)
    elseif code == kb.keys.right then S.cx = math.min(#S.buf[S.cy]+1, S.cx+1)
    elseif code == kb.keys.up    then S.cy = math.max(1, S.cy-1); edit.clampCursor()
    elseif code == kb.keys.down  then S.cy = math.min(#S.buf, S.cy+1); edit.clampCursor()
    elseif code == kb.keys.home  then S.cx = 1
    elseif code == kb.keys["end"] then S.cx = #S.buf[S.cy]+1

    elseif code == kb.keys.tab then
        for _ = 1, cfg.cfg.tabWidth do edit.insertChar(" ") end

    elseif char and #char == 1 and char:byte() >= 32 then
        -- Use unicode.char if available for proper multibyte support
        local ch
        if unicode_ok and char:byte() > 127 then
            ch = unicode.char(char:byte())
        else
            ch = char
        end
        edit.insertChar(ch)
    end
end

return M
