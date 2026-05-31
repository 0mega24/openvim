local S        = require("vim.state")
local edit     = require("vim.edit")
local syn      = require("vim.syntax")
local motion   = require("vim.motion")
local keyboard = require("keyboard")
local event    = require("event")

local M = {}

local function getCount(default)
    local n = tonumber(S.count) or default
    S.count = ""
    return n
end

-- Apply a pending d/y/c operator over the range from (ocy,ocx) to current (S.cy,S.cx).
-- For 'c' also enters insert mode.
local function applyOp(op, ocy, ocx)
    local r1,c1,r2,c2 = ocy,ocx,S.cy,S.cx
    if r1>r2 or (r1==r2 and c1>c2) then r1,c1,r2,c2=r2,c2,r1,c1 end
    if op=="d" then
        edit.yankCharRange(r1,c1,r2,c2)
        edit.deleteCharRange(r1,c1,r2,c2)
        S.cx,S.cy = c1,r1
    elseif op=="y" then
        edit.yankCharRange(r1,c1,r2,c2)
        S.cx,S.cy = ocy,ocx
    elseif op=="c" then
        edit.yankCharRange(r1,c1,r2,c2)
        edit.deleteCharRange(r1,c1,r2,c2)
        S.cx,S.cy = c1,r1
        S.mode = "insert"
    end
end

local function readNextChar()
    local _, _, code = event.pull("key_down")
    if type(code)=="number" and code>=32 then return string.char(code) end
    return nil
end

function M.normalKey(char, code)
    local kb = keyboard

    -- Numeric count accumulation (but not while in pending-operator state)
    if char and char:match("[1-9]") and
       not S.pendingD and not S.pendingY and not S.pendingC then
        S.count = S.count..char; return
    elseif char=="0" and S.count~="" and
           not S.pendingD and not S.pendingY and not S.pendingC then
        S.count = S.count.."0"; return
    end

    -- ── Z prefix (ZZ / ZQ) ───────────────────────────────────────────────────
    if S.pendingZ2 then
        S.pendingZ2 = false
        local fio = require("vim.fileio")
        if char=="Z" then if fio.cmdSave() then S.running=false end
        elseif char=="Q" then S.running=false end
        return
    end

    -- ── z prefix (zz / zt / zb) ──────────────────────────────────────────────
    if S.pendingZ then
        S.pendingZ = false
        if     char=="z" then edit.scrollCenter()
        elseif char=="t" then edit.scrollTop()
        elseif char=="b" then edit.scrollBottom()
        end
        return
    end

    -- ── g prefix (gg / gI) ───────────────────────────────────────────────────
    if S.pendingG then
        S.pendingG = false
        local n = getCount(1)
        if char=="g" then
            S.cy = (n > 1) and math.max(1,math.min(#S.buf,n)) or 1
            S.cx = 1
        elseif char=="I" then
            edit.snapshot(); S.cx=1; S.mode="insert"; S.message=""
        elseif char=="~" then
            -- g~ toggles case of entire line
            edit.snapshot(); edit.toggleCase(S.cy, 1, #S.buf[S.cy])
        end
        edit.clampCursor(); return
    end

    -- ── d operator ───────────────────────────────────────────────────────────
    if S.pendingD then
        S.pendingD = false
        local n = getCount(1)
        if char=="d" then
            edit.snapshot()
            S.clipboard = {}; S.clipboardLine = true
            for _ = 1, n do
                S.clipboard[#S.clipboard+1] = S.buf[S.cy]
                edit.deleteLine(S.cy)
            end
            edit.clampCursor()
            S.message = n.." line(s) deleted"
        elseif char=="w" then
            edit.snapshot(); local ocy,ocx=S.cy,S.cx
            for _=1,n do motion.wordForward() end
            applyOp("d",ocy,ocx)
        elseif char=="W" then
            edit.snapshot(); local ocy,ocx=S.cy,S.cx
            for _=1,n do motion.WORDForward() end
            applyOp("d",ocy,ocx)
        elseif char=="b" then
            edit.snapshot(); local ocy,ocx=S.cy,S.cx
            for _=1,n do motion.wordBack() end
            applyOp("d",ocy,ocx)
        elseif char=="B" then
            edit.snapshot(); local ocy,ocx=S.cy,S.cx
            for _=1,n do motion.WORDBack() end
            applyOp("d",ocy,ocx)
        elseif char=="e" then
            edit.snapshot(); local ocy,ocx=S.cy,S.cx
            for _=1,n do motion.wordEnd() end
            -- de includes the char under cursor at end position
            local nc2 = math.min(S.cx+1, #S.buf[S.cy]+1)
            edit.deleteCharRange(ocy,ocx,S.cy,nc2)
            S.cx,S.cy = ocx,ocy
        elseif char=="$" then
            edit.snapshot()
            local line = S.buf[S.cy]
            S.clipboard = { line:sub(S.cx) }; S.clipboardLine = false
            S.buf[S.cy] = line:sub(1,S.cx-1)
            if S.cx>1 then S.cx=S.cx-1 end
            S.modified=true; syn.markBufDirty(S.cy)
        elseif char=="0" then
            edit.snapshot()
            edit.yankCharRange(S.cy,1,S.cy,S.cx)
            edit.deleteCharRange(S.cy,1,S.cy,S.cx)
            S.cx=1
        elseif char=="^" then
            edit.snapshot()
            local old=S.cx; motion.firstNonBlank()
            local col=math.min(S.cx,old)
            local col2=math.max(S.cx,old)+1
            edit.yankCharRange(S.cy,col,S.cy,col2)
            edit.deleteCharRange(S.cy,col,S.cy,col2)
            S.cx=col
        elseif char=="f" or char=="t" or char=="F" or char=="T" then
            local ch2 = readNextChar()
            if ch2 then
                edit.snapshot(); local ocy,ocx=S.cy,S.cx
                for _=1,n do motion.findChar(char,ch2) end
                applyOp("d",ocy,ocx)
            end
        end
        edit.clampCursor(); return
    end

    -- ── y operator ───────────────────────────────────────────────────────────
    if S.pendingY then
        S.pendingY = false
        local n = getCount(1)
        if char=="y" then
            S.clipboard={}; S.clipboardLine=true
            for i=S.cy, math.min(S.cy+n-1,#S.buf) do
                S.clipboard[#S.clipboard+1]=S.buf[i]
            end
            S.message=#S.clipboard.." line(s) yanked"
        elseif char=="w" then
            local ocy,ocx=S.cy,S.cx
            for _=1,n do motion.wordForward() end
            applyOp("y",ocy,ocx); S.cx,S.cy=ocx,ocy
        elseif char=="W" then
            local ocy,ocx=S.cy,S.cx
            for _=1,n do motion.WORDForward() end
            applyOp("y",ocy,ocx); S.cx,S.cy=ocx,ocy
        elseif char=="$" then
            S.clipboard={S.buf[S.cy]:sub(S.cx)}; S.clipboardLine=false
            S.message="1 line yanked"
        end
        return
    end

    -- ── c operator ───────────────────────────────────────────────────────────
    if S.pendingC then
        S.pendingC = false
        local n = getCount(1)
        edit.snapshot()
        if char=="c" then
            S.clipboard={}; S.clipboardLine=true
            for _ = 1, n do
                S.clipboard[#S.clipboard+1]=S.buf[S.cy]
                if _ < n and #S.buf > 1 then edit.deleteLine(S.cy+1) end
            end
            S.buf[S.cy]=""; S.cx=1
            S.modified=true; syn.markBufDirty(S.cy)
            S.mode="insert"
        elseif char=="w" then
            local ocy,ocx=S.cy,S.cx
            for _=1,n do motion.wordForward() end
            applyOp("c",ocy,ocx)
        elseif char=="W" then
            local ocy,ocx=S.cy,S.cx
            for _=1,n do motion.WORDForward() end
            applyOp("c",ocy,ocx)
        elseif char=="b" then
            local ocy,ocx=S.cy,S.cx
            for _=1,n do motion.wordBack() end
            applyOp("c",ocy,ocx)
        elseif char=="$" then
            S.clipboard={S.buf[S.cy]:sub(S.cx)}; S.clipboardLine=false
            S.buf[S.cy]=S.buf[S.cy]:sub(1,S.cx-1)
            S.modified=true; syn.markBufDirty(S.cy)
            S.mode="insert"
        elseif char=="0" then
            local ocy,ocx=S.cy,S.cx; S.cx=1
            applyOp("c",ocy,ocx)
        elseif char=="^" then
            local ocy,ocx=S.cy,S.cx; motion.firstNonBlank()
            applyOp("c",ocy,ocx)
        elseif char=="f" or char=="t" or char=="F" or char=="T" then
            local ch2 = readNextChar()
            if ch2 then
                local ocy,ocx=S.cy,S.cx
                for _=1,n do motion.findChar(char,ch2) end
                applyOp("c",ocy,ocx)
            end
        end
        edit.clampCursor(); return
    end

    -- ── Standard normal mode ──────────────────────────────────────────────────
    local hadCount = S.count ~= ""
    local n = getCount(1)

    -- Motions
    if char=="h" or code==kb.keys.left then
        for _=1,n do S.cx=math.max(1,S.cx-1) end
    elseif char=="l" or code==kb.keys.right then
        for _=1,n do S.cx=math.min(math.max(1,#S.buf[S.cy]),S.cx+1) end
    elseif char=="k" or code==kb.keys.up then
        for _=1,n do S.cy=math.max(1,S.cy-1) end; edit.clampCursor()
    elseif char=="j" or code==kb.keys.down then
        for _=1,n do S.cy=math.min(#S.buf,S.cy+1) end; edit.clampCursor()
    elseif char=="w" then for _=1,n do motion.wordForward()  end; edit.clampCursor()
    elseif char=="W" then for _=1,n do motion.WORDForward()  end; edit.clampCursor()
    elseif char=="b" then for _=1,n do motion.wordBack()     end; edit.clampCursor()
    elseif char=="B" then for _=1,n do motion.WORDBack()     end; edit.clampCursor()
    elseif char=="e" then for _=1,n do motion.wordEnd()      end; edit.clampCursor()
    elseif char=="E" then for _=1,n do motion.WORDEnd()      end; edit.clampCursor()
    elseif char=="0" then S.cx=1
    elseif char=="^" then motion.firstNonBlank()
    elseif char=="$" then S.cx=math.max(1,#S.buf[S.cy])
    elseif char=="G" then
        S.cy = hadCount and math.max(1,math.min(#S.buf,n)) or #S.buf
        S.cx=1
    elseif char=="g" then S.pendingG=true; return
    elseif char=="z" then S.pendingZ=true; return
    elseif char=="Z" then S.pendingZ2=true; return
    elseif char=="%" then motion.matchBracket()

    elseif char=="f" or char=="t" or char=="F" or char=="T" then
        local ch2 = readNextChar()
        if ch2 then
            S.lastFt = { ftype=char, ch=ch2 }
            for _=1,n do motion.findChar(char,ch2) end
        end
    elseif char==";" then
        if S.lastFt then for _=1,n do motion.findChar(S.lastFt.ftype,S.lastFt.ch) end end
    elseif char=="," then
        if S.lastFt then
            local rev={f="F",t="T",F="f",T="t"}
            for _=1,n do motion.findChar(rev[S.lastFt.ftype],S.lastFt.ch) end
        end

    -- Page / half-page scroll
    elseif code==kb.keys.pageUp or (kb.isControlDown() and code==kb.keys.b) then
        S.cy=math.max(1,S.cy-S.textH); edit.clampCursor()
    elseif code==kb.keys.pageDown or (kb.isControlDown() and code==kb.keys.f) then
        S.cy=math.min(#S.buf,S.cy+S.textH); edit.clampCursor()
    elseif kb.isControlDown() and code==kb.keys.d then
        S.cy=math.min(#S.buf,S.cy+math.floor(S.textH/2)); edit.clampCursor()
    elseif kb.isControlDown() and code==kb.keys.u then
        S.cy=math.max(1,S.cy-math.floor(S.textH/2)); edit.clampCursor()

    -- Mode switches
    elseif char=="i" then edit.snapshot(); S.mode="insert"; S.message=""
    elseif char=="a" then edit.snapshot(); S.cx=math.min(S.cx+1,#S.buf[S.cy]+1); S.mode="insert"; S.message=""
    elseif char=="A" then edit.snapshot(); S.cx=#S.buf[S.cy]+1; S.mode="insert"; S.message=""
    elseif char=="I" then edit.snapshot(); S.cx=1; S.mode="insert"; S.message=""
    elseif char=="o" then
        edit.snapshot()
        table.insert(S.buf, S.cy+1, "")
        S.cy=S.cy+1; S.cx=1
        S.mode="insert"; S.modified=true; syn.markBufDirty(); S.message=""
    elseif char=="O" then
        edit.snapshot()
        table.insert(S.buf, S.cy, "")
        S.cx=1
        S.mode="insert"; S.modified=true; syn.markBufDirty(); S.message=""
    elseif char=="v" then
        S.mode="visual"; S.vx,S.vy=S.cx,S.cy; S.message="-- VISUAL --"
    elseif char==":" then
        S.mode="command"; S.cmdline=""; S.message=""

    -- Search
    elseif char=="/" or char=="?" then
        S.mode="search"; S.searchDir=char; S.cmdline=""; S.message=""
    elseif char=="n" then motion.searchNext(S.lastSearchDir)
    elseif char=="N" then
        motion.searchNext(S.lastSearchDir=="/" and "?" or "/")
    elseif char=="*" then motion.searchWord(true)
    elseif char=="#" then motion.searchWord(false)

    -- Editing
    elseif char=="x" then
        if #S.buf[S.cy]>0 then
            edit.snapshot()
            for _=1,n do
                if S.cx<=#S.buf[S.cy] then edit.deleteCharAt(S.cy,S.cx) end
            end
            edit.clampCursor()
        end
    elseif char=="X" then
        if S.cx>1 then
            edit.snapshot()
            for _=1,n do
                if S.cx>1 then S.cx=S.cx-1; edit.deleteCharAt(S.cy,S.cx) end
            end
            edit.clampCursor()
        end
    elseif char=="d" then
        S.pendingD=true
        if n~=1 then S.count=tostring(n) end; return
    elseif char=="y" then
        S.pendingY=true
        if n~=1 then S.count=tostring(n) end; return
    elseif char=="c" then
        S.pendingC=true
        if n~=1 then S.count=tostring(n) end; return

    elseif char=="D" then
        edit.snapshot()
        S.clipboard={S.buf[S.cy]:sub(S.cx)}; S.clipboardLine=false
        S.buf[S.cy]=S.buf[S.cy]:sub(1,S.cx-1)
        if S.cx>1 then S.cx=S.cx-1 end
        S.modified=true; syn.markBufDirty(S.cy)
    elseif char=="C" then
        edit.snapshot()
        S.clipboard={S.buf[S.cy]:sub(S.cx)}; S.clipboardLine=false
        S.buf[S.cy]=S.buf[S.cy]:sub(1,S.cx-1)
        S.modified=true; syn.markBufDirty(S.cy)
        S.mode="insert"
    elseif char=="s" then
        edit.snapshot()
        for _=1,n do
            if S.cx<=#S.buf[S.cy] then edit.deleteCharAt(S.cy,S.cx) end
        end
        S.mode="insert"
    elseif char=="S" then
        edit.snapshot()
        S.buf[S.cy]=""; S.cx=1
        S.modified=true; syn.markBufDirty(S.cy)
        S.mode="insert"
    elseif char=="~" then
        if #S.buf[S.cy]>0 then
            edit.snapshot(); edit.toggleCase(S.cy,S.cx,n)
            S.cx=math.min(S.cx+n, math.max(1,#S.buf[S.cy]))
        end
    elseif char=="p" then edit.pasteAfter()
    elseif char=="P" then edit.pasteBefore()
    elseif char=="J" then
        edit.snapshot()
        for _=1,n do edit.joinLines(S.cy) end
        edit.clampCursor()
    elseif char=="u" then edit.undo()
    elseif kb.isControlDown() and code==kb.keys.r then edit.redo()

    elseif char=="r" then
        local ch2 = readNextChar()
        if ch2 then
            edit.snapshot()
            for i=0,n-1 do
                local col=S.cx+i
                if col<=#S.buf[S.cy] then
                    S.buf[S.cy]=S.buf[S.cy]:sub(1,col-1)..ch2..S.buf[S.cy]:sub(col+1)
                end
            end
            S.modified=true; syn.markBufDirty(S.cy)
        end

    -- Indent / dedent
    elseif char==">" then
        edit.snapshot()
        local ind = string.rep(" ", require("vim.config").cfg.tabWidth)
        for _=1,n do S.buf[S.cy]=ind..S.buf[S.cy] end
        S.modified=true; syn.markBufDirty(S.cy)
    elseif char=="<" then
        edit.snapshot()
        local tw = require("vim.config").cfg.tabWidth
        for _=1,n do
            S.buf[S.cy]=S.buf[S.cy]:gsub("^"..string.rep(" ",tw),"",1)
        end
        S.modified=true; syn.markBufDirty(S.cy)
    end
end

return M
