local S   = require("vim.state")
local syn = require("vim.syntax")
local cfg = require("vim.config")

local gpu  = require("component").gpu
local term = require("term")

local M = {}

local function setColor(fg, bg)
    if fg ~= S._curFg then gpu.setForeground(fg); S._curFg=fg end
    if bg ~= S._curBg then gpu.setBackground(bg); S._curBg=bg end
end

local function invalidateColorCache() S._curFg=-1; S._curBg=-1 end

local function drawLineNum(row, bufRow, nw)
    if nw == 0 then return end
    local isCursor = cfg.cfg.cursorLine and (bufRow == S.cy)
    local rel      = (cfg.cfg.relativeNums and not isCursor) and math.abs(bufRow-S.cy) or bufRow
    setColor(
        isCursor and 0xffffff or 0x4a4a6a,
        isCursor and 0x1a1a2e or 0x000000
    )
    gpu.set(1, row, string.format("%"..(nw-1).."d ", rel))
end

local function redrawGutter(nw, startRow, endRow)
    if nw == 0 then return end
    local fmt    = "%"..(nw-1).."d "
    local curRow = S.cy - S.scrollY
    setColor(0x4a4a6a, 0x000000)
    for row = startRow, endRow do
        local br = row + S.scrollY
        if br <= #S.buf and row ~= curRow then
            local rel = cfg.cfg.relativeNums and math.abs(br-S.cy) or br
            gpu.set(1, row, string.format(fmt, rel))
        end
    end
    if curRow >= startRow and curRow <= endRow and curRow+S.scrollY <= #S.buf then
        setColor(0xffffff, 0x1a1a2e)
        gpu.set(1, curRow, string.format(fmt, S.cy))
    end
end

local function drawLineContent(row, bufRow, nw, tw, synType)
    if bufRow > #S.buf then
        setColor(0x3a3a6a, 0x000000)
        gpu.set(1, row, "~"..string.rep(" ", S.W-1))
        return
    end
    local SYN      = syn.SYN
    local isCursor = cfg.cfg.cursorLine and (bufRow == S.cy)
    local lineBg   = isCursor and 0x1a1a2e or 0x000000
    local line     = S.buf[bufRow]

    if synType == "lua" then
        local segs = S.segCache[bufRow] or {}
        setColor(SYN.normal, lineBg)
        local raw = line:sub(S.scrollX+1, S.scrollX+tw)
        gpu.set(nw+1, row, raw..string.rep(" ", tw-#raw))
        for _, seg in ipairs(segs) do
            local vbs = math.max(seg.col, S.scrollX+1)
            local vbe = math.min(seg.col+#seg.text-1, S.scrollX+tw)
            if vbs <= vbe then
                setColor(seg.color, lineBg)
                gpu.set(nw+vbs-S.scrollX, row, seg.text:sub(vbs-seg.col+1, vbe-seg.col+1))
            end
        end
    else
        setColor(0xffffff, lineBg)
        local raw = line:sub(S.scrollX+1, S.scrollX+tw)
        gpu.set(nw+1, row, raw..string.rep(" ", tw-#raw))
    end

    local cc = cfg.cfg.colorColumn
    if cc and cc > 0 and cc > S.scrollX and cc <= S.scrollX+tw then
        local cch = cc <= #line and line:sub(cc,cc) or " "
        setColor(isCursor and 0xdddddd or 0x888888, isCursor and 0x2d1030 or 0x1a0020)
        gpu.set(nw+cc-S.scrollX, row, cch)
    end

    if S.mode == "visual" then
        local r1 = math.min(S.vy, S.cy)
        local r2 = math.max(S.vy, S.cy)
        local anchorFirst = S.vy < S.cy or (S.vy==S.cy and S.vx<=S.cx)
        local c1 = anchorFirst and S.vx or S.cx
        local c2 = anchorFirst and S.cx or S.vx
        if bufRow >= r1 and bufRow <= r2 then
            local ss, se
            if r1==r2 then ss,se=math.min(c1,c2),math.max(c1,c2)
            elseif bufRow==r1 then ss,se=c1,math.max(c1,#line)
            elseif bufRow==r2 then ss,se=1,c2
            else ss,se=1,math.max(1,#line) end
            local vss = math.max(ss, S.scrollX+1)
            local vse = math.min(se, S.scrollX+tw)
            if vss <= vse then
                local sel = line:sub(vss,vse)
                if sel=="" then sel=" " end
                setColor(0xddddff, 0x3333aa)
                gpu.set(nw+vss-S.scrollX, row, sel)
            end
        end
    end

    if isCursor and S.mode ~= "visual" then
        local cch  = S.cx <= #line and line:sub(S.cx,S.cx) or " "
        local scrx = S.cx - S.scrollX
        if scrx >= 1 and scrx <= tw then
            setColor(0x000000, 0x7777bb)
            gpu.set(nw+scrx, row, cch)
        end
    end
end

local function drawLineStrip(row, bufRow, nw, fromBufCol, toBufCol, synType)
    local scrX = nw + fromBufCol - S.scrollX
    local strW = toBufCol - fromBufCol + 1
    local SYN  = syn.SYN

    if bufRow > #S.buf then
        setColor(0x3a3a6a, 0x000000)
        gpu.set(scrX, row, string.rep(" ", strW))
        return
    end

    local isCursor = cfg.cfg.cursorLine and (bufRow == S.cy)
    local lineBg   = isCursor and 0x1a1a2e or 0x000000
    local line     = S.buf[bufRow]

    local raw = line:sub(fromBufCol, toBufCol)
    setColor(synType=="lua" and SYN.normal or 0xffffff, lineBg)
    gpu.set(scrX, row, raw..string.rep(" ", strW-#raw))

    if synType == "lua" then
        local segs = S.segCache[bufRow] or {}
        for _, seg in ipairs(segs) do
            local vbs = math.max(seg.col, fromBufCol)
            local vbe = math.min(seg.col+#seg.text-1, toBufCol)
            if vbs <= vbe then
                setColor(seg.color, lineBg)
                gpu.set(nw+vbs-S.scrollX, row, seg.text:sub(vbs-seg.col+1, vbe-seg.col+1))
            end
        end
    end

    local cc = cfg.cfg.colorColumn
    if cc and cc > 0 and cc >= fromBufCol and cc <= toBufCol then
        local cch = cc <= #line and line:sub(cc,cc) or " "
        setColor(isCursor and 0xdddddd or 0x888888, isCursor and 0x2d1030 or 0x1a0020)
        gpu.set(nw+cc-S.scrollX, row, cch)
    end

    if S.mode == "visual" then
        local r1 = math.min(S.vy, S.cy)
        local r2 = math.max(S.vy, S.cy)
        local anchorFirst = S.vy < S.cy or (S.vy==S.cy and S.vx<=S.cx)
        local c1 = anchorFirst and S.vx or S.cx
        local c2 = anchorFirst and S.cx or S.vx
        if bufRow >= r1 and bufRow <= r2 then
            local ss, se
            if r1==r2 then ss,se=math.min(c1,c2),math.max(c1,c2)
            elseif bufRow==r1 then ss,se=c1,math.max(c1,#line)
            elseif bufRow==r2 then ss,se=1,c2
            else ss,se=1,math.max(1,#line) end
            local vss = math.max(ss, fromBufCol)
            local vse = math.min(se, toBufCol)
            if vss <= vse then
                local sel = line:sub(vss,vse)
                if sel=="" then sel=" " end
                setColor(0xddddff, 0x3333aa)
                gpu.set(nw+vss-S.scrollX, row, sel)
            end
        end
    end

    if isCursor and S.mode ~= "visual" then
        if S.cx >= fromBufCol and S.cx <= toBufCol then
            local cch = S.cx <= #line and line:sub(S.cx,S.cx) or " "
            setColor(0x000000, 0x7777bb)
            gpu.set(nw+S.cx-S.scrollX, row, cch)
        end
    end
end

local function drawStatusBar(nw, synType)
    setColor(0x000000, 0xcccccc)
    gpu.fill(1, S.H, S.W, 1, " ")
    local modeLabel = ({ normal="NORMAL", insert="INSERT",
                         command="COMMAND", visual="VISUAL",
                         search="SEARCH" })[S.mode] or S.mode:upper()
    local left  = string.format(" %s  %s%s ", modeLabel,
                                S.filename or "[No Name]",
                                S.modified and " [+]" or "")
    local right = string.format(" %s  %d:%d ", synType, S.cy, S.cx)
    gpu.set(1, S.H, left)
    if #S.message > 0 then
        local mx = math.floor((S.W-#S.message)/2)+1
        if mx > #left+1 then gpu.set(mx, S.H, S.message) end
    end
    if S.W-#right+1 > #left then gpu.set(S.W-#right+1, S.H, right) end
    setColor(0xffffff, 0x000000)
end

-- ── Main render ───────────────────────────────────────────────────────────────

function M.render()
    local edit = require("vim.edit")
    S.W, S.H  = gpu.getResolution()
    S.textH   = S.H - 1
    edit.adjustScroll()

    local nw      = cfg.numWidth()
    local tw      = S.W - nw
    local synType = syn.detectSyntax()

    local delta       = S.scrollY - S.prevScrollY
    local first       = S.prevScrollY < 0
    local modeChanged = S.mode ~= S.prevMode
    local xChanged    = S.scrollX ~= S.prevScrollX
    local cdF         = S.dirtyFrom

    if S.bufDirty then syn.buildMlCache(synType) end

    local full = nw ~= S.prevNw or first or modeChanged
                 or math.abs(delta) >= S.textH
                 or (xChanged and delta ~= 0)
                 or math.abs(S.scrollX - S.prevScrollX) >= tw

    local function addDirty(d, r)
        if r >= 1 and r <= S.textH then d[r]=true end
    end
    local function markVisDirty(d)
        if S.mode ~= "visual" then return end
        local loOld = math.min(S.vy, S.prevCy)
        local loNew = math.min(S.vy, S.cy)
        local hiOld = math.max(S.vy, S.prevCy)
        local hiNew = math.max(S.vy, S.cy)
        local loMin = math.min(loOld,loNew) - S.scrollY
        local loMax = math.max(loOld,loNew) - S.scrollY
        local hiMin = math.min(hiOld,hiNew) - S.scrollY
        local hiMax = math.max(hiOld,hiNew) - S.scrollY
        for r = math.max(1,loMin), math.min(S.textH,loMax) do d[r]=true end
        for r = math.max(1,hiMin), math.min(S.textH,hiMax) do d[r]=true end
    end
    local function markBufRows(d)
        if not S.bufDirty then return end
        for r = math.max(1,cdF-S.scrollY), S.textH do d[r]=true end
    end

    if full then
        for row = 1, S.textH do
            drawLineNum(row, row+S.scrollY, nw)
            drawLineContent(row, row+S.scrollY, nw, tw, synType)
        end

    elseif delta ~= 0 then
        local abs  = math.abs(delta)
        local down = delta > 0
        gpu.copy(1, down and 1+abs or 1, S.W, S.textH-abs, 0, down and -abs or abs)
        invalidateColorCache()

        local dirty = {}
        local newLo = down and S.textH-abs+1 or 1
        local newHi = down and S.textH        or abs
        for row = newLo, newHi do dirty[row]=true end
        addDirty(dirty, S.prevCy-S.scrollY)
        addDirty(dirty, S.cy-S.scrollY)
        markBufRows(dirty)
        markVisDirty(dirty)

        if cfg.cfg.relativeNums then
            redrawGutter(nw, 1, S.textH)
        else
            for row = newLo, newHi do
                local br = row+S.scrollY
                if br <= #S.buf then drawLineNum(row, br, nw) end
            end
            drawLineNum(S.prevCy-S.scrollY, S.prevCy, nw)
            drawLineNum(S.cy-S.scrollY, S.cy, nw)
        end

        for row = 1, S.textH do
            if dirty[row] then drawLineContent(row, row+S.scrollY, nw, tw, synType) end
        end

    elseif xChanged then
        local deltaX = S.scrollX - S.prevScrollX
        local absX   = math.abs(deltaX)
        local right  = deltaX > 0
        gpu.copy(nw+1, 1, tw-absX, S.textH, right and -absX or absX, 0)
        invalidateColorCache()

        local stripFrom = right and (S.scrollX+tw-absX+1) or (S.scrollX+1)
        local stripTo   = right and (S.scrollX+tw)         or (S.scrollX+absX)

        local dirty = {}
        addDirty(dirty, S.cy-S.scrollY)
        if S.prevCy ~= S.cy then addDirty(dirty, S.prevCy-S.scrollY) end
        markBufRows(dirty)
        markVisDirty(dirty)

        if cfg.cfg.relativeNums and S.prevCy ~= S.cy then
            redrawGutter(nw, 1, S.textH)
        elseif S.prevCy ~= S.cy then
            drawLineNum(S.prevCy-S.scrollY, S.prevCy, nw)
            drawLineNum(S.cy-S.scrollY, S.cy, nw)
        end

        for row = 1, S.textH do
            local bufRow = row+S.scrollY
            if dirty[row] then drawLineContent(row, bufRow, nw, tw, synType)
            else drawLineStrip(row, bufRow, nw, stripFrom, stripTo, synType) end
        end

    else
        local dirty = {}
        addDirty(dirty, S.cy-S.scrollY)
        if S.prevCy ~= S.cy then addDirty(dirty, S.prevCy-S.scrollY) end
        markBufRows(dirty)
        markVisDirty(dirty)

        if cfg.cfg.relativeNums and S.prevCy ~= S.cy then
            redrawGutter(nw, 1, S.textH)
        elseif S.prevCy ~= S.cy then
            drawLineNum(S.prevCy-S.scrollY, S.prevCy, nw)
            drawLineNum(S.cy-S.scrollY, S.cy, nw)
        end

        for row = 1, S.textH do
            if dirty[row] then drawLineContent(row, row+S.scrollY, nw, tw, synType) end
        end
    end

    if S.mode == "command" then
        setColor(0xffffff, 0x000000)
        gpu.fill(1, S.H, S.W, 1, " ")
        gpu.set(1, S.H, ":"..S.cmdline)
    elseif S.mode == "search" then
        setColor(0xffffff, 0x000000)
        gpu.fill(1, S.H, S.W, 1, " ")
        gpu.set(1, S.H, S.searchDir..S.cmdline)
    else
        drawStatusBar(nw, synType)
    end

    if S.mode == "command" or S.mode == "search" then
        term.setCursor(2+#S.cmdline, S.H)
    else
        term.setCursor(nw+S.cx-S.scrollX, S.cy-S.scrollY)
    end

    S.prevScrollY = S.scrollY
    S.prevScrollX = S.scrollX
    S.prevCy      = S.cy
    S.prevNw      = nw
    S.prevMode    = S.mode
    S.bufDirty    = false
end

return M
