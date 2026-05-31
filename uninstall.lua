-- openvim uninstaller for OpenComputers / OpenOS
-- Run:  openvim-uninstall

local filesystem = require("filesystem")
local component  = require("component")

local gpu
do
    local ok, g = pcall(function() return component.gpu end)
    if ok then gpu = g end
end

local function coloured(fg, text)
    local old = gpu and gpu.getForeground()
    if gpu then gpu.setForeground(fg) end
    io.write(text)
    if gpu and old then gpu.setForeground(old) end
end

local function confirm(prompt)
    io.write(prompt .. " [y/N] ")
    local answer = io.read()
    return answer and answer:lower():sub(1,1) == "y"
end

local function removeFile(path)
    io.write(string.format("  removing  %-40s  ", path))
    if not filesystem.exists(path) then
        coloured(0x888888, "already gone\n")
        return
    end
    local ok, err = filesystem.remove(path)
    if ok then
        coloured(0x44ff44, "OK\n")
    else
        coloured(0xff4444, "FAIL\n")
        io.stderr:write("    " .. (err or "unknown error") .. "\n")
    end
end

local function removeDir(path)
    if not filesystem.exists(path) then return end
    -- Only remove if empty.
    local empty = true
    for _ in filesystem.list(path) do empty = false; break end
    if empty then
        filesystem.remove(path)
    end
end

-- ── Files installed by the installer ─────────────────────────────────────────

local CORE_FILES = {
    "/usr/bin/openvim",
    "/usr/lib/vim/state.lua",
    "/usr/lib/vim/config.lua",
    "/usr/lib/vim/syntax.lua",
    "/usr/lib/vim/render.lua",
    "/usr/lib/vim/edit.lua",
    "/usr/lib/vim/motion.lua",
    "/usr/lib/vim/fileio.lua",
    "/usr/lib/vim/normal.lua",
    "/usr/lib/vim/insert.lua",
    "/usr/lib/vim/visual.lua",
    "/usr/lib/vim/command.lua",
    "/etc/openvim/vimrc.template",
}

-- ── Main ─────────────────────────────────────────────────────────────────────

print("openvim uninstaller")
print("")

if not confirm("Remove openvim and all its files?") then
    print("Aborted.")
    return
end

print("")

for _, path in ipairs(CORE_FILES) do
    removeFile(path)
end

-- Ask separately about /home/.vimrc since the user may have customised it.
print("")
if filesystem.exists("/home/.vimrc") then
    if confirm("Remove /home/.vimrc? (your personal config — skip if you want to keep it)") then
        removeFile("/home/.vimrc")
    else
        io.write("  keeping   /home/.vimrc\n")
    end
end

-- Remove this script last so it can finish cleanly.
removeFile("/usr/bin/openvim-uninstall")

-- Clean up now-empty directories.
removeDir("/usr/lib/vim")
removeDir("/etc/openvim")

print("")
coloured(0x44ff44, "Done. ")
print("openvim has been removed.")
