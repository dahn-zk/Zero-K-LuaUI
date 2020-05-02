--[[
TODO:
- Dont reset Idle State to Fly on any manual command except the first one after Land Assault.
]]

----------------------------------------------------------------------------------------------------------------------
-- Widget Config
----------------------------------------------------------------------------------------------------------------------
version = "1.0"
cmd_dsc = "Command Swift to land optimally to fire on target area."
is_debug = true

function widget:GetInfo()
    return {
        name    = "Swift Land Assault Command",
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

local land_attacker_controllers = {}
local selected_land_attackers = nil

----------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------

local LandAttackerController = {
    unit_id,
    selection_idx,
    pos,
    rotation,
    base_range,
    max_range,
    target_pos,
    is_activated,
    
    new = function(self, unit_id)
        self            = deepcopy(self)
        self.unit_id    = unit_id
        self.base_range = UNIT_BASE_RANGES[GetUnitDefID(self.unit_id)]
        self.max_range  = GetUnitMaxRange(self.unit_id)
        self.pos        = { GetUnitPosition(self.unit_id) }
        if is_debug then Echo("[LandAttackController] Added " .. self.unit_id) end
        return self
    end,
    
    unset = function(self)
        GiveOrderToUnit(self.unit_id, CMD.STOP, {}, { "" }, 1)
        if is_debug then Echo("[LandAttackController] Removed " .. self.unit_id) end
        return nil
    end,
    
    set_target_pos = function(self, pos)
        self.target_pos = pos
        local cluster_center = { 0, 0, 0 }
        for i = 1, #selected_land_attackers do
            cluster_center = v_add(cluster_center, land_attacker_controllers[selected_land_attackers[i]].pos)
        end
        cluster_center = v_div(cluster_center, #selected_land_attackers)
        self.rotation  = v_atan(cluster_center, self.target_pos)
    end,
    
    execute = function(self)
        self.pos = { GetUnitPosition(self.unit_id) }
        local rotation = self.rotation
        local rank_capacity = 18
        local dr = (math.pi / 4) / rank_capacity
        local inter_rank_spacing = 70
        --local phalanx_depth = #selected_land_attackers // rank_capacity
        local rank_idx = math.floor(self.selection_idx / rank_capacity)
        local base_rotation = rotation - (dr * (rank_capacity - 1)) / 2
        rotation = base_rotation + dr * (self.selection_idx % rank_capacity)
        local range = self.base_range + inter_rank_spacing * rank_idx
    
        local target_pos_relative = {
            sin(rotation) * range,
            nil,
            cos(rotation) * range,
        }
    
        local landing_pos = {
            self.target_pos[1] + target_pos_relative[1],
            nil,
            self.target_pos[3] + target_pos_relative[3],
        }
    
        landing_pos[2] = GetGroundHeight(landing_pos[1], landing_pos[3])
        
        GiveOrderToUnit(self.unit_id, CMD.IDLEMODE, 1, { "" }, 0)
        GiveOrderToUnit(self.unit_id, CMD.MOVE, { landing_pos[1], landing_pos[2], landing_pos[3] }, 0)
    
        self.is_activated = true
        
        if is_debug then Echo("[LandAttackController] " ..
                "\n Landing: " .. table_to_string(landing_pos) ..
                "\n Attacker: " .. table_to_string(self.pos) ..
        "") end
    end,
    
    cancel = function(self)
        if is_debug then Echo ("Cancelling " .. self.unit_id) end
        GiveOrderToUnit(self.unit_id, CMD.IDLEMODE, 0, { "" }, 0)
        self.is_activated = false
    end,
}

function find_land_attackers(units)
    local res = {}
    local n = 0
    for i = 1, #units do
        local unit_id = units[i]
        if (SWIFT_DEF_ID == GetUnitDefID(unit_id)) then
            n = n + 1
            res[n] = unit_id
        end
    end
    if n == 0 then
        return nil
    else
        return res
    end
end

function widget:UnitFinished(unit_id, unit_def_if, unit_team)
    if (UnitDefs[unit_def_if].name == SWIFT_NAME) and (unit_team == GetMyTeamID()) then
        land_attacker_controllers[unit_id] = LandAttackerController:new(unit_id);
    end
end

function widget:UnitDestroyed(unit_id)
    local land_attacker_controller = land_attacker_controllers[unit_id]
    if not (land_attacker_controller == nil) then
        land_attacker_controllers[unit_id] = land_attacker_controller:unset()
    end
end

function widget:UnitCommand(unit_id, unit_def_if, unit_team, cmd_id, cmd_params, cmd_opts, cmd_tag)
    if (cmd_id == CMD.RAW_MOVE and UnitDefs[unit_def_if].name == SWIFT_NAME) then
        local land_attacker_controller = land_attacker_controllers[unit_id]
        if (land_attacker_controller and land_attacker_controller.is_activated) then
            land_attacker_controller:cancel()
        end
    end
end

----------------------------------------------------------------------------------------------------------------------
-- Command Handling
----------------------------------------------------------------------------------------------------------------------

function widget:CommandNotify(cmd_id, params, options)
    if selected_land_attackers ~= nil then
        if is_debug then Echo("Command notify " .. cmd_id .. " " .. table_to_string(params)) end
        if (cmd_id == CMD_LAND_ATTACK and #params == 3) then
            for i = 1, #selected_land_attackers do
                local land_attacker_controller = land_attacker_controllers[selected_land_attackers[i]]
                if (land_attacker_controller) then
                    land_attacker_controller:set_target_pos(params)
                    land_attacker_controller:execute()
                end
            end
            return true
        else
            if is_debug then Echo("  selected_land_attackers " .. table_to_string(selected_land_attackers)) end
            for i = 1, #selected_land_attackers do
                local land_attacker_controller = land_attacker_controllers[selected_land_attackers[i]]
                if (land_attacker_controller and land_attacker_controller.is_activated) then
                    land_attacker_controller:cancel()
                end
            end
        end
    end
end

function widget:SelectionChanged(selected_units)
    selected_land_attackers = find_land_attackers(selected_units)
    if selected_land_attackers ~= nil then
        for i = 1, #selected_land_attackers do
            local land_attacker_controller = land_attacker_controllers[selected_land_attackers[i]]
            if (land_attacker_controller) then land_attacker_controller.selection_idx = i end
        end
    end
end

function widget:CommandsChanged()
    if selected_land_attackers then
        local customCommands = widgetHandler.customCommands
        customCommands[#customCommands + 1] = CMD_LAND_ATTACK_DEF
    end
end

----------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------

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
        unit_id = units[i]
        if (UnitDefs[GetUnitDefID(unit_id)].name == SWIFT_NAME) then
            if (land_attacker_controllers[unit_id] == nil) then
                land_attacker_controllers[unit_id] = LandAttackerController:new(unit_id)
            end
        end
    end
end
