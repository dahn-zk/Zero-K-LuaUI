--[[
TODO:
- Dont reset Idle State to Fly on any manual command except the first one after Land Assault.
]]

----------------------------------------------------------------------------------------------------------------------
-- Widget Config
----------------------------------------------------------------------------------------------------------------------
version = "1.0"
name = "Swift Land Assault Command"
cmd_dsc = "Command Swift to land optimally to fire on target area."
is_debug = true

function widget:GetInfo()
    return {
        name    = name,
        desc    = "[v" .. version .. "] " .. cmd_dsc,
        author  = "terve886, dahn",
        date    = "2020",
        license = "PD", -- should be compatible with Spring
        layer   = 2,
        handler = true, -- for adding customCommand into UI
        enabled = false, -- loaded by default?
    }
end

----------------------------------------------------------------------------------------------------------------------
-- Includes
----------------------------------------------------------------------------------------------------------------------

LIBS_PATH = "LuaUI/Widgets/Libs"
if is_debug then VFS.Include(LIBS_PATH .. "/TableToString.lua") end
VFS.Include(LIBS_PATH .. "/DeepCopy.lua")
VFS.Include(LIBS_PATH .. "/Trigonometry.lua")

----------------------------------------------------------------------------------------------------------------------
-- Speedups
----------------------------------------------------------------------------------------------------------------------

local sin  = math.sin
local cos  = math.cos

local GetUnitMaxRange     = Spring.GetUnitMaxRange
local GetUnitPosition     = Spring.GetUnitPosition
local GetMyAllyTeamID     = Spring.GetMyAllyTeamID
local GiveOrderToUnit     = Spring.GiveOrderToUnit
local GetGroundHeight     = Spring.GetGroundHeight
local GetTeamUnits        = Spring.GetTeamUnits
local GetMyTeamID         = Spring.GetMyTeamID
local GetUnitDefID        = Spring.GetUnitDefID
local GetSpecState        = Spring.GetSpectatingState
local Echo                = Spring.Echo

----------------------------------------------------------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------------------------------------------------------

local CMD_LAND_ATTACK = 19996
local SWIFT_NAME   = "planefighter"
local SWIFT_DEF_ID = UnitDefNames[SWIFT_NAME].id

local CMD_LAND_ATTACK_DEF = {
    id      = CMD_LAND_ATTACK,
    type    = CMDTYPE.ICON_MAP,
    tooltip = 'Makes Swift land optimally to fire at target area.',
    cursor  = 'Attack',
    action  = 'reclaim',
    params  = { },
    texture = 'LuaUI/Images/commands/Bold/dgun.png',
    pos     = {
        CMD.ONOFF,
        CMD.REPEAT,
        CMD.MOVE_STATE,
        CMD.FIRE_STATE,
        CMD.RETREAT,
    },
}

----------------------------------------------------------------------------------------------------------------------
-- Logic Config
----------------------------------------------------------------------------------------------------------------------

UNIT_BASE_RANGES = {
    [SWIFT_DEF_ID] = 600,
}

----------------------------------------------------------------------------------------------------------------------
-- Globals
----------------------------------------------------------------------------------------------------------------------

local land_attack_controllers = {}
local selected_land_attackers = nil

----------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------

local LandAttackController    = {
    unit_ID,
    phalanx_id,
    pos,
    allyTeamID = GetMyAllyTeamID(),
    base_range,
    max_range,
    target_pos,
    is_activated = false,
    
    new = function(self, unit_ID)
        self            = deepcopy(self)
        self.unit_ID    = unit_ID
        self.base_range = UNIT_BASE_RANGES[GetUnitDefID(self.unit_ID)]
        self.max_range  = GetUnitMaxRange(self.unit_ID)
        self.pos        = { GetUnitPosition(self.unit_ID) }
        if is_debug then Echo("[LandAttackController] Added " .. self.unit_ID) end
        return self
    end,
    
    unset = function(self)
        GiveOrderToUnit(self.unit_ID, CMD.STOP, {}, { "" }, 1)
        if is_debug then Echo("[LandAttackController] Removed " .. self.unit_ID) end
        return nil
    end,
    
    set_target_pos = function(self, pos)
        self.target_pos = pos
    end,

    execute = function(self)
        if is_debug then Echo("[LandAttackController]") end
        self.pos                  = { GetUnitPosition(self.unit_ID) }
        local pos_delta           = v_sub(self.target_pos, self.pos)
        pos_delta[2]              = 0
        local pos_delta_norm      = v_norm(pos_delta)
        if is_debug then Echo("  ||self_to_target_dx||: " .. table_to_string(pos_delta_norm)) end
        local landing_pos_delta   = v_mul(pos_delta, self.base_range / pos_delta_norm)
        if is_debug then Echo("  landing_pos_delta: " .. table_to_string(landing_pos_delta)) end
        local phalanx_len         = #selected_land_attackers * 30
        local phalanx_dx          = v_normed_orth(landing_pos_delta)
        if is_debug then Echo("  phalanx_dx: " .. table_to_string(phalanx_dx)) end
        local phalanx_beg_dx      = v_mul(phalanx_dx, phalanx_len)
        phalanx_beg_dx            = v_sub(landing_pos_delta, v_div(phalanx_beg_dx, 2))
        if is_debug then Echo("  phalanx_beg_dx: " .. table_to_string(phalanx_beg_dx)) end
        local phalanx_beg         = v_sub(self.target_pos, phalanx_beg_dx)
        if is_debug then Echo("  phalanx_beg: " .. table_to_string(phalanx_beg)) end
        local phalanx_spacing
        if #selected_land_attackers > 1 then
            phalanx_spacing = phalanx_len / (#selected_land_attackers - 1)
        else
            phalanx_spacing = 0
        end
        if is_debug then Echo("  phalanx_spacing: " .. table_to_string(phalanx_spacing)) end
        local phalanx_dx_from_beg = v_mul(phalanx_dx, phalanx_spacing * (self.phalanx_id - 1))
        if is_debug then Echo("  phalanx_dx_from_beg: " .. table_to_string(phalanx_dx_from_beg)) end
        local landing_pos         = v_add(phalanx_beg, phalanx_dx_from_beg)
        landing_pos[2]            = GetGroundHeight(landing_pos[1], landing_pos[3])
        if is_debug then Echo("  landing_pos: " .. table_to_string(landing_pos)) end
        --if is_debug then Echo("[LandAttackController]" ..
        --        "\n  landing: " .. table_to_string(landing_pos) ..
        --        "\n  attacker: " .. table_to_string(self.pos) ..
        --        "\n  target: " .. table_to_string(self.target_pos) ..
        --        "\n  self_to_target_dx: " .. table_to_string(pos_delta) ..
        --        "\n  ||self_to_target_dx||: " .. table_to_string(pos_delta_norm) ..
        --        "\n  self_to_landing_dx: " .. table_to_string(landing_pos_delta) ..
        --        "") end
    
        GiveOrderToUnit(self.unit_ID, CMD.IDLEMODE, 1, { "" }, 0)
        GiveOrderToUnit(self.unit_ID, CMD.MOVE, { landing_pos[1], landing_pos[2], landing_pos[3] }, 0)
    
        self.is_activated = true
    end,
    
    cancel = function(self)
        self.is_activated = false
    end,
}

function find_land_attackers(units)
    local res = {}
    local n = 0
    for i = 1, #units do
        local unit_ID = units[i]
        if (SWIFT_DEF_ID == GetUnitDefID(unit_ID)) then
            n = n + 1
            res[n] = unit_ID
        end
    end
    if n == 0 then
        return nil
    else
        return res
    end
end

function widget:UnitFinished(unit_ID, unitDefID, unitTeam)
    if (UnitDefs[unitDefID].name == SWIFT_NAME) and (unitTeam == GetMyTeamID()) then
        land_attack_controllers[unit_ID] = LandAttackController:new(unit_ID);
    end
end

function widget:UnitDestroyed(unit_ID)
    landAttackController = land_attack_controllers[unit_ID]
    if not (landAttackController == nil) then
        land_attack_controllers[unit_ID] = landAttackController:unset()
    end
end

function widget:UnitCommand(unit_ID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
    if (cmdID == CMD.RAW_MOVE and UnitDefs[unitDefID].name == SWIFT_NAME) then
        landAttackController = land_attack_controllers[unit_ID]
        if (landAttackController and landAttackController.is_activated) then
            landAttackController:cancel()
        end
    end
end

----------------------------------------------------------------------------------------------------------------------
-- Command Handling
----------------------------------------------------------------------------------------------------------------------

function widget:CommandNotify(cmdID, params, options)
    if selected_land_attackers ~= nil then
        if (cmdID == CMD_LAND_ATTACK and #params == 3) then
            for i = 1, #selected_land_attackers do
                if (land_attack_controllers[selected_land_attackers[i]]) then
                    land_attack_controllers[selected_land_attackers[i]]:set_target_pos(params)
                    land_attack_controllers[selected_land_attackers[i]]:execute()
                end
            end
            return true
        else
            for i = 1, #selected_land_attackers do
                if (land_attack_controllers[selected_land_attackers[i]]) then
                    GiveOrderToUnit(selected_land_attackers[i], CMD.IDLEMODE, 0, { "" }, 0)
                end
            end
        end
    end
end

function widget:SelectionChanged(selected_units)
    selected_land_attackers = find_land_attackers(selected_units)
    if selected_land_attackers ~= nil then
        for i = 1, #selected_land_attackers do
            land_attack_controllers[selected_land_attackers[i]].phalanx_id = i
        end
    end
end

function widget:CommandsChanged()
    if selected_land_attackers then
        local customCommands = widgetHandler.customCommands
        customCommands[#customCommands + 1] = CMD_LAND_ATTACK_DEF
    end
end

---

local function DisableForSpec()
    if GetSpecState() then
        widgetHandler:RemoveWidget()
    end
end

function widget:PlayerChanged(playerID)
    DisableForSpec()
end

function widget:Initialize()
    DisableForSpec()
    local units = GetTeamUnits(GetMyTeamID())
    for i = 1, #units do
        unit_ID = units[i]
        DefID  = GetUnitDefID(unit_ID)
        if (UnitDefs[DefID].name == SWIFT_NAME) then
            if (land_attack_controllers[unit_ID] == nil) then
                land_attack_controllers[unit_ID] = LandAttackController:new(unit_ID)
            end
        end
    end
end
