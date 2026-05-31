-- openvim installer for OpenComputers / OpenOS
-- Run from the OC shell:  lua install.lua  (or paste into pastebin + run)
-- Optional argument overrides the git branch/tag: lua install.lua dev

local component  = require("component")
local filesystem = require("filesystem")

-- ── Preflight ─────────────────────────────────────────────────────────────────

if not component.isAvailable("internet") then
    io.stderr:write("Error: an internet card is required to install openvim.\n")
    return
end

local internet = component.internet
local computer = require("computer")

local args   = { ... }
local branch = args[1] or "main"
local REPO   = "https://raw.githubusercontent.com/0mega24/openvim/" .. branch .. "/"

-- Files to download: { source path in repo, destination on OC filesystem }
local FILES = {
    { "openvim.lua",     "/usr/bin/openvim"          },
    { "vim/state.lua",   "/usr/lib/vim/state.lua"    },
    { "vim/config.lua",  "/usr/lib/vim/config.lua"   },
    { "vim/syntax.lua",  "/usr/lib/vim/syntax.lua"   },
    { "vim/render.lua",  "/usr/lib/vim/render.lua"   },
    { "vim/edit.lua",    "/usr/lib/vim/edit.lua"     },
    { "vim/motion.lua",  "/usr/lib/vim/motion.lua"   },
    { "vim/fileio.lua",  "/usr/lib/vim/fileio.lua"   },
    { "vim/normal.lua",  "/usr/lib/vim/normal.lua"   },
    { "vim/insert.lua",  "/usr/lib/vim/insert.lua"   },
    { "vim/visual.lua",  "/usr/lib/vim/visual.lua"   },
    { "vim/command.lua", "/usr/lib/vim/command.lua"  },
}

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function fetch(url)
    local req, err = internet.request(url)
    if not req then return nil, "request failed: " .. (err or "unknown") end

    -- Poll until data arrives or timeout (10 s).
    local deadline = computer.uptime() + 10
    local chunks   = {}
    while true do
        local chunk, reason = req.read(8192)
        if chunk == nil then
            if reason then return nil, reason end
            break  -- EOF
        end
        if chunk == "" then
            if computer.uptime() > deadline then
                return nil, "timed out"
            end
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

local function coloured(gpu, fg, text)
    local old = gpu and gpu.getForeground()
    if gpu then gpu.setForeground(fg) end
    io.write(text)
    if gpu and old then gpu.setForeground(old) end
end

-- ── Main ─────────────────────────────────────────────────────────────────────

local gpu
do
    local ok, g = pcall(function() return component.gpu end)
    if ok then gpu = g end
end

print("openvim installer")
print("  repo:   github.com/0mega24/openvim")
print("  branch: " .. branch)
print("")

local ok_count  = 0
local fail_count = 0

for _, entry in ipairs(FILES) do
    local src, dst = entry[1], entry[2]
    local url      = REPO .. src

    io.write(string.format("  %-28s -> %-30s  ", src, dst))

    local data, err = fetch(url)
    if not data then
        coloured(gpu, 0xff4444, "FAIL\n")
        io.stderr:write("    " .. err .. "\n")
        fail_count = fail_count + 1
    else
        local wrote, werr = writeFile(dst, data)
        if not wrote then
            coloured(gpu, 0xff4444, "FAIL\n")
            io.stderr:write("    " .. (werr or "write error") .. "\n")
            fail_count = fail_count + 1
        else
            coloured(gpu, 0x44ff44, "OK\n")
            ok_count = ok_count + 1
        end
    end
end

print("")
if fail_count == 0 then
    coloured(gpu, 0x44ff44, "Done! ")
    print(ok_count .. " file(s) installed.")
    print("Run:  openvim <file>")
else
    coloured(gpu, 0xffaa00, "Partial install: ")
    print(ok_count .. " OK, " .. fail_count .. " failed.")
    print("Check your internet card and try again.")
end
