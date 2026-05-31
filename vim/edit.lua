local S   = require("vim.state")
local syn = require("vim.syntax")
local M   = {}

-- -- Undo / redo ---------------------------------------------------------------

function M.snapshot()
    local s = { buf={}, cx=S.cx, cy=S.cy }
    for i,l in ipairs(S.buf) do s.buf[i]=l end
    table.insert(S.undoStack, s)
    if #S.undoStack > S.MAX_UNDO then table.remove(S.undoStack, 1) end
    S.redoStack = {}
end

local function applySnap(s)
    S.buf = {}
    for i,l in ipairs(s.buf) do S.buf[i]=l end
    S.cx, S.cy = s.cx, s.cy
    S.modified  = true
end

function M.undo()
    if #S.undoStack == 0 then S.message="Already at oldest change"; return end
    local cur = { buf={}, cx=S.cx, cy=S.cy }
    for i,l in ipairs(S.buf) do cur.buf[i]=l end
    table.insert(S.redoStack, cur)
    applySnap(table.remove(S.undoStack))
    S.message = "Undo"
end

function M.redo()
    if #S.redoStack == 0 then S.message="Already at newest change"; return end
    local cur = { buf={}, cx=S.cx, cy=S.cy }
    for i,l in ipairs(S.buf) do cur.buf[i]=l end
    table.insert(S.undoStack, cur)
    applySnap(table.remove(S.redoStack))
    S.message = "Redo"
end

-- -- Cursor & scroll -----------------------------------------------------------

function M.clampCursor()
    S.cy = math.max(1, math.min(S.cy, #S.buf))
    local ll = #S.buf[S.cy]
    if S.mode == "insert" then
        S.cx = math.max(1, math.min(S.cx, ll+1))
    else
        S.cx = math.max(1, math.min(S.cx, math.max(1, ll)))
    end
end

function M.adjustScroll()
    local cfg = require("vim.config").cfg
    local nw  = require("vim.config").numWidth()
    local so  = cfg.scrollOff
    local sr  = S.cy - S.scrollY
    if sr < 1 or sr > S.textH then
        S.scrollY = math.max(0, S.cy - math.floor(S.textH/2) - 1)
    else
        if S.cy-1 < S.scrollY+so          then S.scrollY = math.max(0, S.cy-1-so)       end
        if S.cy-1 >= S.scrollY+S.textH-so then S.scrollY = math.max(0, S.cy-S.textH+so) end
    end
    local tw = S.W - nw
    if S.cx <= S.scrollX    then S.scrollX = math.max(0, S.cx-1) end
    if S.cx > S.scrollX+tw  then S.scrollX = S.cx-tw              end
end

function M.scrollCenter()
    S.scrollY = math.max(0, S.cy - math.floor(S.textH/2) - 1)
end
function M.scrollTop()
    S.scrollY = math.max(0, S.cy - 1 - require("vim.config").cfg.scrollOff)
end
function M.scrollBottom()
    S.scrollY = math.max(0, S.cy - S.textH + require("vim.config").cfg.scrollOff)
end

-- -- Buffer editing primitives -------------------------------------------------

function M.insertChar(ch)
    S.buf[S.cy] = S.buf[S.cy]:sub(1,S.cx-1) .. ch .. S.buf[S.cy]:sub(S.cx)
    S.cx = S.cx+1
    S.modified = true
    syn.markBufDirty(S.cy)
end

function M.deleteCharAt(row, col)
    local line = S.buf[row]
    if col < 1 or col > #line then return end
    S.buf[row] = line:sub(1,col-1) .. line:sub(col+1)
    S.modified  = true
    syn.markBufDirty(row)
end

function M.breakLine()
    local line = S.buf[S.cy]
    local old  = S.cy
    S.buf[S.cy] = line:sub(1,S.cx-1)
    table.insert(S.buf, S.cy+1, line:sub(S.cx))
    S.cy = S.cy+1; S.cx = 1
    S.modified = true
    syn.markBufDirty(old)
end

function M.joinLines(row)
    if row >= #S.buf then return end
    S.buf[row] = S.buf[row] .. S.buf[row+1]
    table.remove(S.buf, row+1)
    S.modified = true
    syn.markBufDirty(row)
end

function M.deleteLine(row)
    if #S.buf == 1 then S.buf[1]=""; syn.markBufDirty(1); return end
    table.remove(S.buf, row)
    if S.cy > #S.buf then S.cy=#S.buf end
    S.modified = true
    syn.markBufDirty(row)
end

-- Delete character range: (r1,c1) inclusive to (r2,c2) exclusive.
function M.deleteCharRange(r1, c1, r2, c2)
    if r1 > r2 or (r1==r2 and c1>=c2) then return end
    if r1 == r2 then
        S.buf[r1] = S.buf[r1]:sub(1,c1-1) .. S.buf[r1]:sub(c2)
    else
        S.buf[r1] = S.buf[r1]:sub(1,c1-1) .. S.buf[r2]:sub(c2)
        for _ = r1+1, r2 do table.remove(S.buf, r1+1) end
    end
    if #S.buf == 0 then S.buf = {""} end
    if S.cy > #S.buf then S.cy = #S.buf end
    S.modified = true
    syn.markBufDirty(r1)
end

-- Yank character range into clipboard.
function M.yankCharRange(r1, c1, r2, c2)
    S.clipboard = {}
    S.clipboardLine = false
    if r1 == r2 then
        S.clipboard[1] = S.buf[r1]:sub(c1, c2-1)
    else
        S.clipboard[1] = S.buf[r1]:sub(c1)
        for i = r1+1, r2-1 do S.clipboard[#S.clipboard+1] = S.buf[i] end
        S.clipboard[#S.clipboard+1] = S.buf[r2]:sub(1, c2-1)
    end
end

-- Toggle case of n characters starting at (row, col).
function M.toggleCase(row, col, n)
    local line = S.buf[row]
    local res  = {}
    for i = 1, #line do
        local ch = line:sub(i,i)
        if i >= col and i < col+n then
            local lo = ch:lower()
            ch = (ch == lo) and ch:upper() or lo
        end
        res[#res+1] = ch
    end
    S.buf[row]  = table.concat(res)
    S.modified  = true
    syn.markBufDirty(row)
end

-- -- Clipboard paste -----------------------------------------------------------

function M.pasteAfter()
    if #S.clipboard == 0 then return end
    M.snapshot()
    if S.clipboardLine then
        for i,l in ipairs(S.clipboard) do table.insert(S.buf, S.cy+i, l) end
        S.cy = S.cy+1
    else
        -- character paste: insert after cursor on same line
        local line = S.buf[S.cy]
        local ins  = table.concat(S.clipboard, "\n")
        S.buf[S.cy] = line:sub(1,S.cx) .. ins .. line:sub(S.cx+1)
        S.cx = S.cx + #ins
        syn.markBufDirty(S.cy)
    end
    S.modified = true
    syn.markBufDirty()
end

function M.pasteBefore()
    if #S.clipboard == 0 then return end
    M.snapshot()
    if S.clipboardLine then
        for i,l in ipairs(S.clipboard) do table.insert(S.buf, S.cy+i-1, l) end
    else
        local line = S.buf[S.cy]
        local ins  = table.concat(S.clipboard, "\n")
        S.buf[S.cy] = line:sub(1,S.cx-1) .. ins .. line:sub(S.cx)
        S.cx = S.cx + #ins - 1
        syn.markBufDirty(S.cy)
    end
    S.modified = true
    syn.markBufDirty()
end

return M
