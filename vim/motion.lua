local S = require("vim.state")
local M = {}

local function isWord(ch)  return ch:match("[%w_]") ~= nil end
local function isSpace(ch) return ch == " " or ch == "\t"  end

-- ── Small-word motions ────────────────────────────────────────────────────────

function M.wordForward()
    local line = S.buf[S.cy]
    local i    = S.cx
    if i <= #line then
        local ch = line:sub(i,i)
        if isWord(ch) then
            while i <= #line and isWord(line:sub(i,i)) do i=i+1 end
        elseif not isSpace(ch) then
            while i <= #line and not isWord(line:sub(i,i)) and not isSpace(line:sub(i,i)) do
                i=i+1
            end
        end
        while i <= #line and isSpace(line:sub(i,i)) do i=i+1 end
    end
    if i > #line and S.cy < #S.buf then
        S.cy=S.cy+1; S.cx=1
    else
        S.cx = math.min(i, math.max(1,#line))
    end
end

function M.wordBack()
    local line = S.buf[S.cy]
    local i    = S.cx-1
    while i>=1 and isSpace(line:sub(i,i)) do i=i-1 end
    if i>=1 then
        if isWord(line:sub(i,i)) then
            while i>=1 and isWord(line:sub(i,i)) do i=i-1 end
        else
            while i>=1 and not isWord(line:sub(i,i)) and not isSpace(line:sub(i,i)) do
                i=i-1
            end
        end
    end
    if i<1 and S.cy>1 then S.cy=S.cy-1; S.cx=#S.buf[S.cy]
    else S.cx=math.max(1,i+1) end
end

function M.wordEnd()
    local line = S.buf[S.cy]
    local i    = S.cx+1
    while i <= #line and isSpace(line:sub(i,i)) do i=i+1 end
    while i < #line do
        local cur  = isWord(line:sub(i,i))
        local next = isWord(line:sub(i+1,i+1))
        if cur ~= next or isSpace(line:sub(i+1,i+1)) then break end
        i=i+1
    end
    S.cx = math.min(i, math.max(1,#line))
end

-- ── WORD motions (whitespace-delimited) ───────────────────────────────────────

function M.WORDForward()
    local line = S.buf[S.cy]
    local i    = S.cx
    while i <= #line and not isSpace(line:sub(i,i)) do i=i+1 end
    while i <= #line and     isSpace(line:sub(i,i)) do i=i+1 end
    if i > #line and S.cy < #S.buf then
        S.cy=S.cy+1; S.cx=1
    else
        S.cx = math.min(i, math.max(1,#line))
    end
end

function M.WORDBack()
    local line = S.buf[S.cy]
    local i    = S.cx-1
    while i>=1 and     isSpace(line:sub(i,i)) do i=i-1 end
    while i>=1 and not isSpace(line:sub(i,i)) do i=i-1 end
    if i<1 and S.cy>1 then S.cy=S.cy-1; S.cx=#S.buf[S.cy]
    else S.cx=math.max(1,i+1) end
end

function M.WORDEnd()
    local line = S.buf[S.cy]
    local i    = S.cx+1
    while i <= #line and isSpace(line:sub(i,i))     do i=i+1 end
    while i <  #line and not isSpace(line:sub(i+1,i+1)) do i=i+1 end
    S.cx = math.min(i, math.max(1,#line))
end

-- ── First non-blank ───────────────────────────────────────────────────────────

function M.firstNonBlank()
    local line = S.buf[S.cy]
    local i = 1
    while i <= #line and isSpace(line:sub(i,i)) do i=i+1 end
    S.cx = math.min(i, math.max(1,#line))
end

-- ── Find char on line (f/t/F/T) ───────────────────────────────────────────────

function M.findChar(ftype, ch)
    local line = S.buf[S.cy]
    if ftype == "f" then
        local i = S.cx+1
        while i <= #line do
            if line:sub(i,i) == ch then S.cx=i; return true end
            i=i+1
        end
    elseif ftype == "t" then
        local i = S.cx+1
        while i <= #line do
            if line:sub(i,i) == ch then S.cx=i-1; return true end
            i=i+1
        end
    elseif ftype == "F" then
        local i = S.cx-1
        while i >= 1 do
            if line:sub(i,i) == ch then S.cx=i; return true end
            i=i-1
        end
    elseif ftype == "T" then
        local i = S.cx-1
        while i >= 1 do
            if line:sub(i,i) == ch then S.cx=i+1; return true end
            i=i-1
        end
    end
    return false
end

-- ── Bracket matching (%) ──────────────────────────────────────────────────────

local PAIRS_FWD = { ["("]=")", ["["]="]", ["{"]="}" }
local PAIRS_BWD = { [")"]="(", ["]"]="[", ["}"]= "{" }

function M.matchBracket()
    local line = S.buf[S.cy]
    local ch   = line:sub(S.cx,S.cx)
    if PAIRS_FWD[ch] then
        local close, depth = PAIRS_FWD[ch], 1
        local r, c = S.cy, S.cx+1
        while r <= #S.buf do
            local l = S.buf[r]
            while c <= #l do
                local lc = l:sub(c,c)
                if lc == ch    then depth=depth+1
                elseif lc==close then depth=depth-1
                    if depth==0 then S.cx=c; S.cy=r; return end
                end
                c=c+1
            end
            r=r+1; c=1
        end
    elseif PAIRS_BWD[ch] then
        local open, depth = PAIRS_BWD[ch], 1
        local r, c = S.cy, S.cx-1
        while r >= 1 do
            local l = S.buf[r]
            while c >= 1 do
                local lc = l:sub(c,c)
                if lc == ch   then depth=depth+1
                elseif lc==open then depth=depth-1
                    if depth==0 then S.cx=c; S.cy=r; return end
                end
                c=c-1
            end
            r=r-1
            if r >= 1 then c=#S.buf[r] end
        end
    end
end

-- ── Search ───────────────────────────────────────────────────────────────────

-- Find pattern in given direction from (r,c), wrapping around.
-- Returns (row, col) on match or nil.
local function searchFrom(pat, r, c, dir)
    local plain = not pat:match("[%(%)%.%%%+%-%*%?%[%^%$]")
    local function tryFind(line, from)
        local ok, s = pcall(string.find, line, pat, from, plain)
        return ok and s or nil
    end

    if dir == "/" then
        for i = r, #S.buf do
            local s = tryFind(S.buf[i], i==r and c+1 or 1)
            if s then return i, s end
        end
        for i = 1, r do
            local s = tryFind(S.buf[i], 1)
            if s and (i < r or s <= c) then return i, s end
        end
    else
        for i = r, 1, -1 do
            local line  = S.buf[i]
            local limit = i==r and c-1 or #line
            local best  = nil
            local j     = 1
            while j <= limit do
                local ok, s, e = pcall(string.find, line, pat, j, plain)
                if ok and s and s <= limit then best=s; j=(e or s)+1
                else break end
            end
            if best then return i, best end
        end
        for i = #S.buf, r, -1 do
            local line = S.buf[i]
            local best = nil; local j = 1
            while j <= #line do
                local ok, s, e = pcall(string.find, line, pat, j, plain)
                if ok and s then best=s; j=(e or s)+1
                else break end
            end
            if best and (i > r or best > c) then return i, best end
        end
    end
    return nil
end

function M.searchNext(dir)
    if not S.lastSearch then S.message="No previous search"; return end
    dir = dir or S.lastSearchDir
    local r, c = searchFrom(S.lastSearch, S.cy, S.cx, dir)
    if r then
        S.cy=r; S.cx=c
        S.message = dir..S.lastSearch
    else
        S.message = "Pattern not found: "..S.lastSearch
    end
end

function M.searchWord(forward)
    local line = S.buf[S.cy]
    local s, j = S.cx, S.cx
    while s > 1 and line:sub(s-1,s-1):match("[%w_]") do s=s-1 end
    while j <= #line and line:sub(j,j):match("[%w_]") do j=j+1 end
    local word = line:sub(s, j-1)
    if word == "" then S.message="No word under cursor"; return end
    S.lastSearch    = word
    S.lastSearchDir = forward and "/" or "?"
    M.searchNext(S.lastSearchDir)
    S.message = (forward and "/" or "?")..word
end

return M
