version = "1.0"

-- @formatter:on
function widget:GetInfo() return {
    name    = "Scythe Cloak Fire State Auto-Toggle",
    desc    = "[" .. version .. "]\n"
            .. "Makes Scythes automatically return fire when cloaked and fire at will when decloaked.",
    author  = "terve886, dahn",
    date    = "2020",
    license = "CC0",
    layer   = 10,
    enabled = false
} end
-- @formatter:off

VFS.Import("LuaUI/Widgets/Libs/unit_states.lua")

SCYTHE_DEF_ID = UnitDefNames["cloakheavyraid"].id

function widget:UnitDecloaked(unit_id, unit_def_id, team_id)
    if (unit_def_id == SCYTHE_DEF_ID) then
        set_fire_state(unit_id, 2)
    end
end

function widget:UnitCloaked(unit_id, unit_def_id, team_id)
    if (unit_def_id == SCYTHE_DEF_ID) then
        set_fire_state(unit_id, 1)
    end
end

local GetSpecState = Spring.GetSpectatingState

local function DisableForSpec()
    if GetSpecState() then
        widgetHandler:RemoveWidget()
    end
end

function widget:Initialize()
    DisableForSpec()
end

function widget:PlayerChanged(player_id)
    DisableForSpec()
end
