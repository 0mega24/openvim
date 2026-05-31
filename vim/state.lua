-- Shared mutable state for openvim; all modules require this table.
local S = {}

S.buf      = { "" }
S.cx       = 1
S.cy       = 1
S.mode     = "normal"   -- normal | insert | command | visual | search
S.filename = nil
S.message  = ""
S.cmdline  = ""
S.scrollY  = 0
S.scrollX  = 0
S.running  = true
S.modified = false

S.undoStack = {}
S.redoStack = {}
S.MAX_UNDO  = 100

S.vx = 1
S.vy = 1

S.W     = 1
S.H     = 1
S.textH = 1

S.clipboard     = {}
S.clipboardLine = true   -- true = linewise yank/paste

-- normal-mode pending-operator state
S.pendingG  = false
S.pendingZ  = false   -- z prefix (zz/zt/zb)
S.pendingZ2 = false   -- Z prefix (ZZ/ZQ)
S.pendingD  = false
S.pendingY  = false
S.pendingC  = false
S.count     = ""

-- last f/t/F/T for ; and , repeat
S.lastFt = nil   -- { ftype="f"|"t"|"F"|"T", ch="x" }

-- search
S.lastSearch    = nil
S.lastSearchDir = "/"   -- '/' forward, '?' backward
S.searchDir     = "/"   -- dir being entered right now

-- render bookkeeping
S.prevScrollY = -1
S.prevScrollX = 0
S.prevCy      = 0
S.prevNw      = -1
S.prevMode    = "normal"
S.bufDirty    = true
S.mlCache     = {}
S.segCache    = {}
S.dirtyFrom   = 1

-- GPU color cache
S._curFg = -1
S._curBg = -1

-- Reset all fields to initial values.
-- Called at the start of every main() invocation because OC caches
-- require() results -- without this, S.running stays false after the
-- first run and the editor soft-locks on every subsequent open.
function S.reset()
    S.buf           = { "" }
    S.cx            = 1
    S.cy            = 1
    S.mode          = "normal"
    S.filename      = nil
    S.message       = ""
    S.cmdline       = ""
    S.scrollY       = 0
    S.scrollX       = 0
    S.running       = true
    S.modified      = false
    S.undoStack     = {}
    S.redoStack     = {}
    S.vx            = 1
    S.vy            = 1
    S.W             = 1
    S.H             = 1
    S.textH         = 1
    S.clipboard     = {}
    S.clipboardLine = true
    S.pendingG      = false
    S.pendingZ      = false
    S.pendingZ2     = false
    S.pendingD      = false
    S.pendingY      = false
    S.pendingC      = false
    S.count         = ""
    S.lastFt        = nil
    S.lastSearch    = nil
    S.lastSearchDir = "/"
    S.searchDir     = "/"
    S.prevScrollY   = -1
    S.prevScrollX   = 0
    S.prevCy        = 0
    S.prevNw        = -1
    S.prevMode      = "normal"
    S.bufDirty      = true
    S.mlCache       = {}
    S.segCache      = {}
    S.dirtyFrom     = 1
    S._curFg        = -1
    S._curBg        = -1
end

return S
