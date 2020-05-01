function widget:GetInfo()
  return {
    name      = "Cursor Lock",
    desc      = "Locks mouse cursor within game window",
    author    = "Teabag",
    date      = "Jan 12, 2018",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------

local lock = "grabinput"

function widget:Initialize()
   Spring.SendCommands(lock)
end