-- openvim installer for OpenComputers / OpenOS
--
-- Usage:
--   lua install.lua                   fresh install from main branch
--   lua install.lua update            update core files, keep your .vimrc
--   lua install.lua replace           update everything, overwrite .vimrc too
--   lua install.lua <branch>          fresh install from a specific branch
--   lua install.lua update <branch>   update from a specific branch
--   lua install.lua replace <branch>  replace everything from a specific branch

local component  = require("component")
local filesystem = require("filesystem")

-- ── Preflight ─────────────────────────────────────────────────────────────────

if not component.isAvailable("internet") then
    io.stderr:write("Error: an internet card is required to install openvim.\n")
    return
end

local internet = component.internet
local computer = require("computer")

-- ── Argument parsing ──────────────────────────────────────────────────────────

local args    = { ... }
local MODE    = "install"   -- install | update | replace
local branch  = "main"

for _, a in ipairs(args) do
    if a == "update" or a == "replace" then
        MODE = a
    else
        branch = a
    end
end

local REPO = "https://raw.githubusercontent.com/0mega24/openvim/" .. branch .. "/"

-- ── File lists ────────────────────────────────────────────────────────────────

-- Core files: always downloaded and overwritten.
local FILES = {
    { "openvim.lua",        "/usr/bin/openvim"               },
    { "vim/state.lua",      "/usr/lib/vim/state.lua"         },
    { "vim/config.lua",     "/usr/lib/vim/config.lua"        },
    { "vim/syntax.lua",     "/usr/lib/vim/syntax.lua"        },
    { "vim/render.lua",     "/usr/lib/vim/render.lua"        },
    { "vim/edit.lua",       "/usr/lib/vim/edit.lua"          },
    { "vim/motion.lua",     "/usr/lib/vim/motion.lua"        },
    { "vim/fileio.lua",     "/usr/lib/vim/fileio.lua"        },
    { "vim/normal.lua",     "/usr/lib/vim/normal.lua"        },
    { "vim/insert.lua",     "/usr/lib/vim/insert.lua"        },
    { "vim/visual.lua",     "/usr/lib/vim/visual.lua"        },
    { "vim/command.lua",    "/usr/lib/vim/command.lua"       },
    { "vimrc.template",     "/etc/openvim/vimrc.template"    },
    { "uninstall.lua",      "/usr/bin/openvim-uninstall"     },
}

local VIMRC_SRC = "vimrc.template"
local VIMRC_DST = "/home/.vimrc"

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function fetch(url)
    local req, err = internet.request(url)
    if not req then return nil, "request failed: " .. (err or "unknown") end

    local deadline = computer.uptime() + 10
    local chunks   = {}
    while true do
        local chunk, reason = req.read(8192)
        if chunk == nil then
            if reason then return nil, reason end
            break
        end
        if chunk == "" then
            if computer.uptime() > deadline then return nil, "timed out" end
            os.sleep(0.05)
        else
            chunks[#chunks + 1] = chunk
        end
    end

    return table.concat(chunks)
end

local function writeFile(path, data)
    local dir = filesystem.path(path)
    if not filesystem.isDirectory(dir) then
        local ok, err = filesystem.makeDirectory(dir)
        if not ok then return false, "cannot create " .. dir .. ": " .. (err or "?") end
    end
    local f, err = io.open(path, "w")
    if not f then return false, err end
    f:write(data)
    f:close()
    return true
end

local function coloured(fg, text)
    local old = gpu and gpu.getForeground()
    if gpu then gpu.setForeground(fg) end
    io.write(text)
    if gpu and old then gpu.setForeground(old) end
end

local function downloadAndWrite(src, dst)
    io.write(string.format("  %-28s -> %-30s  ", src, dst))
    local data, err = fetch(REPO .. src)
    if not data then
        coloured(0xff4444, "FAIL\n")
        io.stderr:write("    " .. err .. "\n")
        return false
    end
    local wrote, werr = writeFile(dst, data)
    if not wrote then
        coloured(0xff4444, "FAIL\n")
        io.stderr:write("    " .. (werr or "write error") .. "\n")
        return false
    end
    coloured(0x44ff44, "OK\n")
    return true
end

-- ── Main ─────────────────────────────────────────────────────────────────────

gpu = nil
do
    local ok, g = pcall(function() return component.gpu end)
    if ok then gpu = g end
end

local modeLabel = ({ install="Installing", update="Updating", replace="Replacing" })[MODE]

print("openvim " .. MODE)
print("  repo:   github.com/0mega24/openvim")
print("  branch: " .. branch)
if MODE == "replace" then
    print("  note:   /home/.vimrc will be overwritten")
end
print("")

local ok_count   = 0
local fail_count = 0

-- Core files.
for _, entry in ipairs(FILES) do
    local ok = downloadAndWrite(entry[1], entry[2])
    if ok then ok_count = ok_count + 1 else fail_count = fail_count + 1 end
end

-- .vimrc handling depends on mode.
io.write(string.format("  %-28s -> %-30s  ", VIMRC_SRC, VIMRC_DST))
if MODE == "replace" then
    -- Overwrite unconditionally.
    local data, err = fetch(REPO .. VIMRC_SRC)
    if not data then
        coloured(0xff4444, "FAIL\n")
        io.stderr:write("    " .. err .. "\n")
        fail_count = fail_count + 1
    else
        local wrote, werr = writeFile(VIMRC_DST, data)
        if not wrote then
            coloured(0xff4444, "FAIL\n")
            io.stderr:write("    " .. (werr or "write error") .. "\n")
            fail_count = fail_count + 1
        else
            coloured(0x44ff44, "OK (replaced)\n")
            ok_count = ok_count + 1
        end
    end
elseif filesystem.exists(VIMRC_DST) then
    -- install / update: leave existing config alone.
    coloured(0x888888, "skipped (already exists)\n")
else
    -- No config yet: write it regardless of mode.
    local data, err = fetch(REPO .. VIMRC_SRC)
    if not data then
        coloured(0xff4444, "FAIL\n")
        io.stderr:write("    " .. err .. "\n")
        fail_count = fail_count + 1
    else
        local wrote, werr = writeFile(VIMRC_DST, data)
        if not wrote then
            coloured(0xff4444, "FAIL\n")
            io.stderr:write("    " .. (werr or "write error") .. "\n")
            fail_count = fail_count + 1
        else
            coloured(0x44ff44, "OK\n")
            ok_count = ok_count + 1
        end
    end
end

-- ── Summary ───────────────────────────────────────────────────────────────────

print("")
if fail_count == 0 then
    coloured(0x44ff44, "Done! ")
    print(ok_count .. " file(s) " .. MODE .. "d.")
    print("Run:    openvim <file>")
    print("Config: /home/.vimrc  (reference copy at /etc/openvim/vimrc.template)")
else
    coloured(0xffaa00, "Partial " .. MODE .. ": ")
    print(ok_count .. " OK, " .. fail_count .. " failed.")
    print("Check your internet card and try again.")
end
