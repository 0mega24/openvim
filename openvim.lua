-- openvim: a vim-like text editor for OpenComputers (Lua 5.2)
-- Entry point. Libraries live in vim/ (installed to /usr/lib/vim/ on OC).

local term  = require("term")
local event = require("event")

local S      = require("vim.state")
local cfg    = require("vim.config")
local render = require("vim.render")
local fio    = require("vim.fileio")
local normal = require("vim.normal")
local insert = require("vim.insert")
local visual = require("vim.visual")
local cmd    = require("vim.command")

local function main(args)
    -- Try to load user vimrc on startup.
    pcall(cfg.loadVimrc, "/home/.vimrc")
    pcall(cfg.loadVimrc, "/etc/vim/vimrc")

    if args and args[1] then
        fio.cmdOpen(args[1])
    else
        S.message = "openvim  :e <file> open  :q quit  /pat search  Ctrl+[ normal"
    end

    term.clear()

    while S.running do
        render.render()

        local evType, _, a1, a2, a3 = term.pull()

        if evType == "key_down" then
            local char
            if type(a1)=="number" and a1>=32 then char=string.char(a1) end

            -- For insert mode, try unicode.char for high codepoints.
            local uchar = char
            if S.mode == "insert" and type(a1)=="number" and a1>127 then
                local ok, unicode = pcall(require,"unicode")
                if ok then uchar = unicode.char(a1) end
            end

            S.message = ""

            local ok, err = pcall(function()
                if     S.mode=="normal"  then normal.normalKey(char, a2)
                elseif S.mode=="insert"  then insert.insertKey(uchar or char, a2)
                elseif S.mode=="command" then cmd.commandKey(char, a2)
                elseif S.mode=="visual"  then visual.visualKey(char, a2)
                elseif S.mode=="search"  then cmd.searchKey(char, a2)
                end
                require("vim.edit").clampCursor()
            end)

            if not ok then S.message = tostring(err) end

        elseif evType == "scroll" then
            -- a3: +1 scroll up (cursor up), -1 scroll down (cursor down)
            local n = 3
            S.cy = math.max(1, math.min(#S.buf, S.cy - a3*n))
            require("vim.edit").clampCursor()
        end
    end

    term.clear()
    term.setCursor(1,1)
end

local args = { ... }
main(args)
