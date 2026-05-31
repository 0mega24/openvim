local S = require("vim.state")
local M = {}

M.SYN = {
    normal  = 0xd4d4d4,
    keyword = 0x569cd6,
    string  = 0xce9178,
    comment = 0x6a9955,
    number  = 0xb5cea8,
    func    = 0xdcdcaa,
    builtin = 0x4ec9b0,
    ocapi   = 0x4fc1e8,
}

local function mkset(s)
    local t = {}
    for w in s:gmatch("%S+") do t[w] = true end
    return t
end

local luaKeywords = mkset(
    "and break do else elseif end false for function goto " ..
    "if in local nil not or repeat return then true until while"
)
local luaBuiltins = mkset(
    "print require ipairs pairs type tostring tonumber error assert " ..
    "pcall xpcall select unpack rawget rawset setmetatable getmetatable " ..
    "rawequal rawlen next math string table io os coroutine"
)
local ocApis = mkset(
    "component computer robot sides colors keyboard term event " ..
    "filesystem internet serialization text unicode thread process " ..
    "shell rc uuid buffer gpu screen modem redstone crafting " ..
    "inventory_controller tank_controller navigation geolyzer hologram " ..
    "experience tractor_beam chunkloader data debug leash sign transaction"
)

do
    local ok, comp = pcall(require, "component")
    if ok then
        for name in comp.list() do ocApis[name] = true end
    end
end

function M.detectSyntax()
    local cfg = require("vim.config").cfg
    if cfg.syntax then return cfg.syntax end
    if S.filename and S.filename:match("%.lua$") then return "lua" end
    return "text"
end

function M.tokenizeLua(line, ml)
    local segs = {}
    local i, len = 1, #line
    local SYN = M.SYN

    local function push(s, e, color)
        if s <= e then
            segs[#segs+1] = { col=s, text=line:sub(s,e), color=color }
        end
    end

    if ml == "comment" or ml == "string" then
        local color = (ml == "comment") and SYN.comment or SYN.string
        local e = line:find("]]", 1, true)
        if e then push(1, e+1, color); i = e+2; ml = nil
        else push(1, len, color); return segs, ml end
    end

    while i <= len do
        local ch = line:sub(i, i)
        if ch == "-" and line:sub(i+1,i+1) == "-" then
            if line:sub(i+2,i+3) == "[[" then
                local e = line:find("]]", i+4, true)
                if e then push(i,e+1,SYN.comment); i=e+2
                else push(i,len,SYN.comment); return segs,"comment" end
            else push(i,len,SYN.comment); return segs,ml end
        elseif ch == '"' or ch == "'" then
            local q, j = ch, i+1
            while j <= len do
                local c = line:sub(j,j)
                if c == "\\" then j=j+2
                elseif c == q then j=j+1; break
                else j=j+1 end
            end
            push(i,j-1,SYN.string); i=j
        elseif ch == "[" and line:sub(i+1,i+1) == "[" then
            local e = line:find("]]", i+2, true)
            if e then push(i,e+1,SYN.string); i=e+2
            else push(i,len,SYN.string); return segs,"string" end
        elseif ch:match("%d") or (ch=="." and line:sub(i+1,i+1):match("%d")) then
            local j = i
            if line:sub(i,i+1):match("^0[xX]") then
                j=j+2
                while j<=len and line:sub(j,j):match("[%da-fA-F_]") do j=j+1 end
            else
                while j<=len and line:sub(j,j):match("[%d%.eE_]") do j=j+1 end
                if line:sub(j-1,j-1):match("[eE]") and line:sub(j,j):match("[%+%-]") then
                    j=j+1
                    while j<=len and line:sub(j,j):match("%d") do j=j+1 end
                end
            end
            push(i,j-1,SYN.number); i=j
        elseif ch:match("[%a_]") then
            local j = i
            while j<=len and line:sub(j,j):match("[%w_]") do j=j+1 end
            local word  = line:sub(i,j-1)
            local color = luaKeywords[word] and SYN.keyword
                       or luaBuiltins[word] and SYN.builtin
                       or ocApis[word]      and SYN.ocapi
                       or (line:sub(j,j)=="(") and SYN.func
                       or SYN.normal
            push(i,j-1,color); i=j
        else
            push(i,i,SYN.normal); i=i+1
        end
    end
    return segs, ml
end

function M.markBufDirty(from)
    from = from or 1
    if from < S.dirtyFrom then S.dirtyFrom = from end
    S.bufDirty = true
end

function M.buildMlCache(syn)
    if syn ~= "lua" then
        S.mlCache = {}; S.segCache = {}; S.dirtyFrom = 1
        return
    end
    if S.dirtyFrom > #S.buf then return end
    local start = S.dirtyFrom
    local ml    = start > 1 and S.mlCache[start] or nil
    for i = start, #S.buf do
        S.mlCache[i] = ml
        local segs, nextMl = M.tokenizeLua(S.buf[i] or "", ml)
        S.segCache[i] = segs
        if start > 1 and nextMl == S.mlCache[i+1] then
            ml = nextMl; break
        end
        ml = nextMl
    end
    S.dirtyFrom = #S.buf + 1
end

return M
