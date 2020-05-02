--[[
TODO:
- Reset Idle State to Fly first manual command after Land Assault.
]]

----------------------------------------------------------------------------------------------------------------------
-- Widget Config
----------------------------------------------------------------------------------------------------------------------
version = "1.0"
cmd_dsc = "Command Swift to land optimally to fire on target area."
is_debug = true

function widget:GetInfo()
    return {
        name    = "Land Assault Command",
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

--VFS.Include(LIBS_PATH .. "/cmd.lua")
if is_debug then VFS.Include(LIBS_PATH .. "/TableToString.lua") end
VFS.Include(LIBS_PATH .. "/DeepCopy.lua")
VFS.Include(LIBS_PATH .. "/Algebra.lua")

----------------------------------------------------------------------------------------------------------------------
-- Speedups
----------------------------------------------------------------------------------------------------------------------

local sin  = math.sin
local cos  = math.cos

local GetUnitMaxRange     = Spring.GetUnitMaxRange
local GetUnitPosition     = Spring.GetUnitPosition
local GiveOrderToUnit     = Spring.GiveOrderToUnit
local GetGroundHeight     = Spring.GetGroundHeight
local GetTeamUnits        = Spring.GetTeamUnits
local GetMyTeamID         = Spring.GetMyTeamID
local GetUnitDefID        = Spring.GetUnitDefID
local GetSpecState        = Spring.GetSpectatingState
local MarkerAddPoint      = Spring.MarkerAddPoint
local Echo                = Spring.Echo

----------------------------------------------------------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------------------------------------------------------

local CMD_LAND_ATTACK = 19996
local SWIFT_NAME      = "planefighter"
local SWIFT_DEF_ID    = UnitDefNames[SWIFT_NAME].id

local CMD_LAND_ATTACK_DEF = {
    id      = CMD_LAND_ATTACK,
    type    = CMDTYPE.ICON_MAP,
    tooltip = cmd_dsc,
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
-- Globals
----------------------------------------------------------------------------------------------------------------------

--- At which range away from target units should land
UNIT_BASE_RANGES = {
    [SWIFT_DEF_ID] = 600,
}

local land_attacker_controllers = {}
local selected_land_attackers = nil

----------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------

function is_move_type_cmd(cmd_id)
    -- @formatter:off
    return cmd_id == CMD.AREA_ATTACK
        or cmd_id == CMD.ATTACK
        or cmd_id == CMD.CAPTURE
        or cmd_id == CMD.FIGHT
        or cmd_id == CMD.GUARD
        or cmd_id == CMD.LOAD_UNITS
        or cmd_id == CMD.MANUALFIRE
        or cmd_id == CMD.MOVE
        or cmd_id == CMD.PATROL
        or cmd_id == CMD.RECLAIM
        or cmd_id == CMD.REPAIR
        or cmd_id == CMD.RESTORE
        or cmd_id == CMD.RESURRECT
        or cmd_id == CMD.UNLOAD_UNIT
        or cmd_id == CMD.UNLOAD_UNITS
    -- @formatter:on
end

function find_latest_positional_cmd(cmd_queue)
    for i = #cmd_queue, 1, -1 do
        local cmd = cmd_queue[i]
        if is_debug then Echo("find_latest_positional_cmd" .. table_to_string(cmd)) end
        if is_move_type_cmd(cmd.id) then
           return cmd
        end
    end
    return nil
end

local mission_control = {
    cluster_center,
    cluster_center_2,
    target_pos,
    rotation,
    
    process_target = function(self, target_pos)
        self.target_pos = target_pos
        self:comp_cluster_center()
        self.rotation = v_atan(self.cluster_center, target_pos)
        if is_debug then
            MarkerAddPoint(self.target_pos[1], self.target_pos[2], self.target_pos[3], "target", false)
            MarkerAddPoint(self.cluster_center[1], self.cluster_center[2], self.cluster_center[3], "cluster center", false)
            Echo("rotation: " .. self.rotation)
        end
    end,
    
    comp_cluster_center = function(self)
        self.cluster_center = { 0, 0, 0 }
        for i = 1, #selected_land_attackers do
            local land_attacker_controller = land_attacker_controllers[selected_land_attackers[i]]
            local cmds = Spring.GetUnitCommands(land_attacker_controller.unit_id, -1)
            local latest_positional_cmd = find_latest_positional_cmd(cmds)
            if is_debug then Echo("MissionControl | unit: " .. land_attacker_controller.unit_id
                .. " | latest_positional_cmd: " .. table_to_string(latest_positional_cmd)) end
            local pos
            -- @formatter:off
            if latest_positional_cmd == nil
            then pos = { GetUnitPosition(land_attacker_controller.unit_id) }
            else pos = { latest_positional_cmd.params[1],
                         latest_positional_cmd.params[2],
                         latest_positional_cmd.params[3] } end
            -- @formatter:on
            self.cluster_center = v_add(self.cluster_center, pos)
        end
        self.cluster_center = v_div(self.cluster_center, #selected_land_attackers)
    end
}

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
        self.is_activated = false
        if is_debug then Echo("LandAttackController | Added unit: " .. self.unit_id) end
        return self
    end,
    
    unset = function(self)
        GiveOrderToUnit(self.unit_id, CMD.STOP, {}, { "" }, 1)
        if is_debug then Echo("LandAttackController | Removed unit: " .. self.unit_id) end
        return nil
    end,
    
    execute = function(self)
        self.pos = { GetUnitPosition(self.unit_id) }
        local rotation = mission_control.rotation
        local rank_capacity = 28
        --local rank_capacity = math.floor(#selected_land_attackers / 1.2)
        --local dr = (4/7) * math.pi / rank_capacity
        local dr = math.pi / 90
        local inter_rank_spacing = 50
        --local phalanx_depth = #selected_land_attackers // rank_capacity
        local rank_idx = math.floor(self.selection_idx / rank_capacity)
        local base_rotation = rotation - (dr * (math.min(rank_capacity, #selected_land_attackers) - 1)) / 2
        rotation = base_rotation + dr * (self.selection_idx % rank_capacity)
        local range = self.base_range + inter_rank_spacing * rank_idx
    
        local target_pos_relative = v_mul({ sin(rotation), 0, cos(rotation) }, range)
    
        local landing_pos = v_add(mission_control.target_pos, target_pos_relative)
        landing_pos[2] = GetGroundHeight(landing_pos[1], landing_pos[3])
    
        local cmds = Spring.GetUnitCommands(self.unit_id, -1)
        for i = 0, #cmds do
            if cmds[i] and cmds[i].id ~= nil then
                GiveOrderToUnit(self.unit_id, CMD.REMOVE, {cmds[i].id}, CMD.OPT_ALT)
            end
        end
        local final_pos = nil
        --for i = #cmds, 1, -1 do
        --    --if cmds[i] and cmds[i].id and (cmds[i].id == CMD.MOVE or cmds[i].id == CMD.RAW_MOVE) then
        --    if cmds[i] and cmds[i].id and #cmds[i].params == 3 then
        --        local cmd_pos = cmds[i].params
        --        final_pos = cmd_pos
        --        break
        --    end
        --end
        if final_pos == nil then final_pos = self.pos end
    
        local STEP_DX_0_NORM = 800
        --local STEP_POW       = 1.2
    
        local step_dx = v_mul(v_normalize(target_pos_relative), STEP_DX_0_NORM)
        --local step_dx = v_mul(v_normalize(v_sub(self.pos, landing_pos)), STEP_DX_0_NORM)
        local i = -1
        local x = landing_pos
        local dst = v_norm(v_sub(x, self.pos))
        while dst > STEP_DX_0_NORM do
            GiveOrderToUnit(self.unit_id, CMD.INSERT,
                    { i, CMD.MOVE, CMD.OPT_INTERNAL, x[1], x[2], x[3] },
                    CMD.OPT_ALT
            )
            i = i - 1
            step_dx = v_mul(2, step_dx)
            dst = dst - v_norm(step_dx)
            x = v_add(x, step_dx); x[2] = nil --GetGroundHeight(x[1], x[3])
        end
    
        local cmd_id, _, cmd_tag = Spring.GetUnitCurrentCommand(self.unit_id)
        --GiveOrderToUnit(self.unit_id, CMD.MOVE, { landing_pos[1], landing_pos[2], landing_pos[3] }, 0)
        --if cmd_tag ~= nil then GiveOrderToUnit(self.unit_id, CMD.REMOVE, cmd_tag, CMD.OPT_ALT) end
        --if cmd_id ~= nil then GiveOrderToUnit(self.unit_id, CMD.REMOVE, cmd_id, CMD.OPT_ALT) end
        GiveOrderToUnit(self.unit_id, CMD.IDLEMODE, 1, { "" }, CMD.OPT_ALT)
    
        self.is_activated = true
    
        if is_debug then Echo("[LandAttackController] " ..
                "\n Landing: " .. table_to_string(landing_pos) ..
                "\n Attacker: " .. table_to_string(self.pos) ..
                "") end
    end,
    
    process_cmd = function(self)
        local is_autoland = Spring.GetUnitStates(self.unit_id).autoland
        if is_debug then Echo("LandAttackController | process_cmd | is_autoland = " .. tostring(is_autoland)
                .. " | is_activated = " .. tostring(self.is_activated)
                .. " | unit: " .. self.unit_id
        ) end
        if (is_autoland and self.is_activated) then
            self:cancel()
        end
    end,
    
    cancel = function(self)
        if is_debug then Echo ("LandAttackController | cancel | unit: " .. self.unit_id) end
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

----------------------------------------------------------------------------------------------------------------------
-- Command Handling
----------------------------------------------------------------------------------------------------------------------

function debug_cmd(callin_name, unit_id, cmd_id, cmd_params, cmd_opts)
    local cmd
    if cmd_id == CMD_LAND_ATTACK then cmd = "LAND_ATTACK" else cmd = CMD[cmd_id] end
    if cmd == nil then cmd = cmd_id .. "(?)" end
    Echo(callin_name
            .. " | " .. cmd
            .. " | params: " .. table_to_string(cmd_params)
            .. " | opts: " .. table_to_string(cmd_opts)
            .. " | unit: " .. unit_id
    )
end

--- FIGHT, PATROL, GUARD, LOOPBACKATTACK, etc are processed here
---
--- From https://springrts.com/wiki/Lua:Callins :
--- Called after when a unit accepts a command, after AllowCommand returns true.
--- (Synced/Unsynced shared)
function widget:UnitCommand(unit_id, unit_def_if, unit_team, cmd_id, cmd_params, cmd_opts, cmd_tag)
    if is_debug then debug_cmd("UnitCommand", unit_id, cmd_id, cmd_params, cmd_opts) end
    --if (cmd_id ~= CMD.RAW_MOVE and unit_def_if == SWIFT_DEF_ID) then
    if (cmd_id ~= CMD_LAND_ATTACK and unit_def_if == SWIFT_DEF_ID) then
        land_attacker_controllers[unit_id]:process_cmd(cmd_id)
    end
end

--- Called for newly introduced CMD_LAND_ATTACK
---
--- From https://springrts.com/wiki/Lua:Callins :
--- Called when a command is issued. Returning true deletes the command and does not send it through the network.
--- (Unsynced only)
function widget:CommandNotify(cmd_id, cmd_params, cmd_opts)
    if selected_land_attackers ~= nil then
        if is_debug then debug_cmd("CommandNotify", unit_id, cmd_id, cmd_params, cmd_opts) end
        if (cmd_id == CMD_LAND_ATTACK and #cmd_params == 3) then
            local target_pos = cmd_params
            mission_control:process_target(target_pos)
            for i = 1, #selected_land_attackers do
                local land_attacker_controller = land_attacker_controllers[selected_land_attackers[i]]
                if (land_attacker_controller) then land_attacker_controller:execute(target_pos) end
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
