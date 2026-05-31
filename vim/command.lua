local S        = require("vim.state")
local syn      = require("vim.syntax")
local keyboard = require("keyboard")

local M = {}

-- -- Ex command execution ------------------------------------------------------

function M.execCommand(cmd)
    cmd = cmd:match("^%s*(.-)%s*$")
    local fio = require("vim.fileio")
    local cfg = require("vim.config")

    if cmd == "w" then
        fio.cmdSave()
    elseif cmd:match("^w%s") then
        fio.cmdSave(cmd:match("^w%s+(.+)"))
    elseif cmd == "q" then
        if S.modified then S.message="Unsaved changes -- use :q! to force quit"
        else S.running=false end
    elseif cmd == "q!" then
        S.running = false
    elseif cmd == "wq" or cmd == "x" then
        if fio.cmdSave() then S.running=false end
    elseif cmd:match("^e%s") then
        fio.cmdOpen(cmd:match("^e%s+(.+)"))
    elseif cmd == "e" then
        if S.filename then fio.cmdOpen(S.filename) else S.message="No filename" end
    elseif cmd:match("^so%s") or cmd:match("^source%s") then
        local path = cmd:match("%s+(.+)$")
        cfg.loadVimrc(path)
    elseif cmd == "set number" or cmd == "set nu" then
        cfg.cfg.showNumbers=true;  S.message="numbers on"
    elseif cmd == "set nonumber" or cmd == "set nonu" then
        cfg.cfg.showNumbers=false; S.message="numbers off"
    elseif cmd == "set rnu" or cmd == "set relativenumber" then
        cfg.cfg.relativeNums=true;  S.message="relative numbers on"
    elseif cmd == "set nornu" or cmd == "set norelativenumber" then
        cfg.cfg.relativeNums=false; S.message="relative numbers off"
    elseif cmd == "set cul" or cmd == "set cursorline" then
        cfg.cfg.cursorLine=true;  S.message="cursorline on"
    elseif cmd == "set nocul" or cmd == "set nocursorline" then
        cfg.cfg.cursorLine=false; S.message="cursorline off"
    elseif cmd:match("^set syntax=") then
        local s = cmd:match("^set syntax=(.+)")
        cfg.cfg.syntax = (s=="lua" or s=="text") and s or nil
        syn.markBufDirty(1); S.message="syntax: "..(cfg.cfg.syntax or "auto")
    elseif cmd:match("^set colorcolumn=(%d+)$") then
        cfg.cfg.colorColumn = tonumber(cmd:match("(%d+)$"))
        S.message = "colorcolumn="..cfg.cfg.colorColumn
    elseif cmd:match("^set tabstop=(%d+)$") or cmd:match("^set ts=(%d+)$") then
        cfg.cfg.tabWidth = tonumber(cmd:match("(%d+)$"))
        S.message = "tabwidth="..cfg.cfg.tabWidth
    elseif cmd:match("^set scrolloff=(%d+)$") or cmd:match("^set so=(%d+)$") then
        cfg.cfg.scrollOff = tonumber(cmd:match("(%d+)$"))
        S.message = "scrolloff="..cfg.cfg.scrollOff
    elseif cmd:match("^%d+$") then
        S.cy = math.max(1, math.min(#S.buf, tonumber(cmd))); S.cx=1
    elseif cmd:match("^[%+%-]%d+$") then
        S.cy = math.max(1, math.min(#S.buf, S.cy+tonumber(cmd))); S.cx=1
    elseif cmd:match("^%%%s*s/") or cmd:match("^s/") then
        -- :s/pat/repl/[g] or :%s/pat/repl/[g]
        local global = cmd:sub(1,1) == "%"
        local rest   = global and cmd:match("^%%%s*s/(.+)") or cmd:match("^s/(.+)")
        if rest then
            -- Split on unescaped /
            local parts = {}
            local i, len = 1, #rest
            local cur = {}
            while i <= len do
                local ch = rest:sub(i,i)
                if ch == "\\" and i < len then
                    cur[#cur+1] = rest:sub(i+1,i+1); i=i+2
                elseif ch == "/" then
                    parts[#parts+1] = table.concat(cur); cur={}; i=i+1
                else
                    cur[#cur+1] = ch; i=i+1
                end
            end
            if #cur > 0 then parts[#parts+1] = table.concat(cur) end
            local pat  = parts[1] or ""
            local repl = parts[2] or ""
            local flags= parts[3] or ""
            local allg = flags:find("g") ~= nil
            local plain = not pat:match("[%(%)%.%%%+%-%*%?%[%^%$]")
            local count = 0
            local r1 = global and 1 or S.cy
            local r2 = global and #S.buf or S.cy
            for row = r1, r2 do
                if allg then
                    local new, n = S.buf[row]:gsub(pat, repl)
                    if n > 0 then S.buf[row]=new; count=count+n; syn.markBufDirty(row) end
                else
                    local new, n = S.buf[row]:gsub(pat, repl, 1)
                    if n > 0 then S.buf[row]=new; count=count+1; syn.markBufDirty(row) end
                end
            end
            S.modified = count > 0 or S.modified
            S.message = count.." substitution(s)"
        end
    else
        S.message = "Unknown command: "..cmd
    end
end

-- -- Command mode key handler --------------------------------------------------

function M.commandKey(char, code)
    local kb = keyboard
    if kb.isControlDown() and code == kb.keys.lbracket then
        S.mode="normal"; S.cmdline=""; S.message=""
    elseif code == kb.keys.enter then
        local cmd = S.cmdline
        S.mode="normal"; S.cmdline=""
        M.execCommand(cmd)
    elseif code == kb.keys.back then
        if #S.cmdline > 0 then S.cmdline=S.cmdline:sub(1,-2)
        else S.mode="normal"; S.message="" end
    elseif char and #char==1 and char:byte()>=32 then
        S.cmdline = S.cmdline..char
    end
end

-- -- Search mode key handler ---------------------------------------------------

function M.searchKey(char, code)
    local kb     = keyboard
    local motion = require("vim.motion")
    if kb.isControlDown() and code == kb.keys.lbracket then
        S.mode="normal"; S.cmdline=""; S.message=""
    elseif code == kb.keys.enter then
        local pat = S.cmdline
        S.mode="normal"; S.cmdline=""
        if pat ~= "" then
            S.lastSearch    = pat
            S.lastSearchDir = S.searchDir
            motion.searchNext(S.searchDir)
        end
    elseif code == kb.keys.back then
        if #S.cmdline > 0 then S.cmdline=S.cmdline:sub(1,-2)
        else S.mode="normal"; S.message="" end
    elseif char and #char==1 and char:byte()>=32 then
        S.cmdline = S.cmdline..char
    end
end

return M
