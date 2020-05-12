----------------------------------------------------------------------------------------------------------------------
-- Config
----------------------------------------------------------------------------------------------------------------------
local version = "2.0"
local cmd_dsc = "Command Swift to land optimally to fire on target area."
local is_debug = false

--- At which range away from target units should land
local BASE_RANGE = 600
local RANK_CAPACITY = 28
local INTER_RANK_SPACING = 50
--- Rotation between two neibor Swifts in a rank. Configures the distance between two neibors, ideally should be a
--- simple distance value, but currently the logic is based on circular formation.
local DR = math.pi / 80

-- @formatter:off
function widget:GetInfo() return {
    name    = "Swift Land Assault",
    desc    = "[v" .. version .. "] \n"
            .. " \n" -- at least one char to be included by parser as a separate line
            .. cmd_dsc .. "\n"
            .. " \n"
            .. "  The command is added with the same shortkey as for Reclaim command.\n"
    	    .. "The widget computes optimal positions for each Swift to attack an area around a selected point.\n"
            .. 'If the attack force is far enough, it also queues a set of \"correctional checkpoints\" Swifts have '
            .. "to pass through, which makes the final formation more focused at the center of attacking area.\n"
            .. "  It also automatically manages Fly/Land states unless a toggle was issued manually.\n"
            .. " \n"
            .. "  To achieve final optimal positioning Swifts land in a phalanx " .. RANK_CAPACITY .. " wide starting "
            .. "at " .. BASE_RANGE .. " elmos away from target. Distance between neiboring ranks = "
            .. INTER_RANK_SPACING .. ", and distance between neiboring Swifts within rank is as close as possible "
            .. "without them trying to overlap. Note that the logic is still not enough to achieve a perfect formation "
            .. "especially if the army will occupy more than a few ranks of a formation, so bigger your force is or "
            .. " more is it spread out - further away you need to issue the command.\n"
            .. " \n"
            .. "  Limitations: does not work with command queues; does not compute the shortest traversal paths like "
            .. "custom formations widget does; only works with single point; does not work with moving targets; still "
            .. "flaky with > 50 Swifts and not recommended to use for < 5 swifts - it's more optimal to issue manual "
            .. "line formation instead.",
    author  = "terve886, dahn",
    date    = "2020",
    license = "CC0",
    layer   = 2,
    handler = true,
    enabled = false,
} end
-- @formatter:on

----------------------------------------------------------------------------------------------------------------------
-- Includes
----------------------------------------------------------------------------------------------------------------------

local LIBS_PATH = "LuaUI/Widgets/Libs"

VFS.Include(LIBS_PATH .. "/speedups.lua")
VFS.Include(LIBS_PATH .. "/cmd.lua")
if is_debug then VFS.Include(LIBS_PATH .. "/table_to_string.lua") end
VFS.Include(LIBS_PATH .. "/deepcopy.lua")
VFS.Include(LIBS_PATH .. "/vector.lua")
VFS.Include(LIBS_PATH .. "/assignment_optimization.lua")

----------------------------------------------------------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------------------------------------------------------

-- @formatter:off
local CMD_LAND_ATTACK = 19996
local SWIFT_NAME      = "planefighter"
local SWIFT_DEF_ID    = UnitDefNames[SWIFT_NAME].id

local CMD_LAND_ATTACK_DEF = {
    id      = CMD_LAND_ATTACK,
    type    = CMDTYPE.ICON_MAP,
    tooltip = cmd_dsc,
    cursor  = 'Attack',
    action  = 'reclaim',
    params  = {},
    texture = 'LuaUI/Images/commands/Bold/dgun.png',
    pos     = {
        CMD.ONOFF,
        CMD.REPEAT,
        CMD.MOVE_STATE,
        CMD.FIRE_STATE,
        CMD.RETREAT,
    },
}
-- @formatter:on

----------------------------------------------------------------------------------------------------------------------
-- Globals
----------------------------------------------------------------------------------------------------------------------

local land_attacker_controllers = {}
local SSIDs = nil

----------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------

--- Collective brain
local mission_control = {
    --- An average of all selected Swifts positions.
    cluster_center,
    --- A point the command was issued to.
    target_pos,
    --- An angle between the target position and the cluster center.
    rotation,
    --- Where the phalanx starts.
    base_rotation,
    ---
    landing_x_a,
    
    --- Sets `target_pos`, computes and sets `cluster_pos` and `rotation`.
    process_target = function(self, target_pos)
        if SSIDs == nil then return end
        
        self.target_pos = target_pos
    
        self:_comp_cluster_center()
    
        self.rotation = v_atan(self.cluster_center, target_pos)
    
        local phalanx_length = RANK_CAPACITY -- avoiding `math.min`. see https://springrts.com/wiki/Lua_Performance
        if (#SSIDs < phalanx_length) then phalanx_length = #SSIDs end
        self.base_rotation = self.rotation - (DR * (phalanx_length - 1)) / 2
    
        if is_debug then
            MarkerAddPoint(self.target_pos[1], self.target_pos[2], self.target_pos[3], "target", false)
            MarkerAddPoint(self.cluster_center[1], self.cluster_center[2], self.cluster_center[3],
                    "cluster center\nswifts: " .. #SSIDs, false)
            Echo("rotation: " .. self.rotation)
        end
    
        self:_comp_landing_x_a()
    
        local distances = {}
        for i = 1, #SSIDs do
            distances[i] = {}
            local swift_x = { GetUnitPosition(SSIDs[i]) }
            for j = 1, #SSIDs do
                local landing_x = self.landing_x_a[j]
                distances[i][j] = (landing_x[1] - swift_x[1])^2 + (landing_x[3] - swift_x[3])^2
            end
        end
        
        self.landing_x_assignments = assign(distances)
        for i = 1, #self.landing_x_assignments do
            self.landing_x_assignments[i] = self.landing_x_a[self.landing_x_assignments[i]]
        end
        if is_debug then Echo("landing_x_assignments: " .. table_to_string(self.landing_x_assignments)) end
    end,
    
    _comp_landing_x_a = function(self)
        self.landing_x_a = {}
        for i = 0, #SSIDs - 1 do
            local rotation = self.base_rotation + DR * (i % RANK_CAPACITY)
        
            local rank_idx = floor(i / RANK_CAPACITY)
            local range = BASE_RANGE + INTER_RANK_SPACING * rank_idx
        
            local target_to_landing_dx = v_mul({ sin(rotation), 0, cos(rotation) }, range)
        
            local landing_x = v_add(self.target_pos, target_to_landing_dx)
            landing_x[2] = GetGroundHeight(landing_x[1], landing_x[3])
        
            self.landing_x_a[i + 1] = landing_x
            
            if is_debug then Echo("MissionControl | _comp_landing_x_a | " .. table_to_string(landing_x)) end
        end
    end,
    
    _comp_cluster_center = function(self)
        self.cluster_center = { 0, 0, 0 }
        for i = 1, #SSIDs do
            local controller = land_attacker_controllers[SSIDs[i]]
            local pos = { GetUnitPosition(controller.unit_id) }
            self.cluster_center = v_add(self.cluster_center, pos)
        end
        self.cluster_center = v_div(self.cluster_center, #SSIDs)
    end
}

--- Individual Swift controller. May use data from `mission_control`
local LandAttackerController = {
    unit_id,
    selection_idx,
    rotation,
    max_range,
    target_pos,
    is_activated,
    
    new = function(self, unit_id)
        self = deepcopy(self)
        self.unit_id = unit_id
        self.max_range = GetUnitMaxRange(self.unit_id)
        self.is_activated = false
        if is_debug then Echo("LandAttackController | added unit: " .. self.unit_id) end
        return self
    end,
    
    unset = function(self)
        GiveOrderToUnit(self.unit_id, CMD_STOP, {}, {}, 1)
        if is_debug then Echo("LandAttackController | removed unit: " .. self.unit_id) end
        return nil
    end,
    
    --- Executes a Land Attack order based on data in `mission_control`
    execute = function(self)
        local pos = { GetUnitPosition(self.unit_id) }
    
        -- this is weird and looks suboptimal
        -- but checkpoint orders do not work without this queue emptying for some reason even if we issue the first
        -- order directly not with insertion in hope to empty the queue.
        -- should be gone with command queue support implementation
        local cmds = GetUnitCommands(self.unit_id, -1)
        for i = 0, #cmds do
            if cmds[i] and cmds[i].id ~= nil then
                GiveOrderToUnit(self.unit_id, CMD_REMOVE, { cmds[i].id }, CMD_OPT_ALT)
            end
        end
    
        local x = mission_control.landing_x_assignments[self.selection_idx]
        GiveOrderToUnit(self.unit_id, CMD_INSERT,
                { 0, CMD_MOVE, CMD_OPT_INTERNAL, x[1], x[2], x[3] },
                CMD_OPT_ALT
        )
        
        GiveOrderToUnit(self.unit_id, CMD_IDLEMODE, 1, {}, CMD_OPT_ALT)
        
        self.is_activated = true
        
        if is_debug then Echo("LandAttackController"
                .. " | landing: " .. table_to_string(landing_x)
                .. " | attacker: " .. table_to_string(pos)
        ) end
    end,
    
    --- Processes any other non Land Attack order to manage Fly/Land state
    process_cmd = function(self)
        local is_autoland = GetUnitStates(self.unit_id).autoland
        if is_debug then Echo("LandAttackController | process_cmd | is_autoland = " .. tostring(is_autoland)
                .. " | is_activated = " .. tostring(self.is_activated)
                .. " | unit: " .. self.unit_id
        ) end
        if (is_autoland and self.is_activated) then
            self:_cancel()
        end
    end,
    
    _cancel = function(self)
        if is_debug then Echo("LandAttackController | cancel | unit: " .. self.unit_id) end
        GiveOrderToUnit(self.unit_id, CMD_IDLEMODE, 0, {}, 0)
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
    if (unit_def_if == SWIFT_DEF_ID and unit_team == GetMyTeamID()) then
        land_attacker_controllers[unit_id] = LandAttackerController:new(unit_id);
    end
end

function widget:UnitDestroyed(unit_id)
    local land_attacker_controller = land_attacker_controllers[unit_id]
    if (land_attacker_controller ~= nil) then
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
    if is_debug then Echo(callin_name
            .. " | " .. cmd
            .. " | params: " .. table_to_string(cmd_params)
            .. " | opts: " .. table_to_string(cmd_opts)
            .. " | unit: " .. unit_id
    ) end
end

--- FIGHT, PATROL, GUARD, LOOPBACKATTACK, etc are processed here
---
--- From https://springrts.com/wiki/Lua:Callins :
--- Called after when a unit accepts a command, after AllowCommand returns true.
--- (Synced/Unsynced shared)
function widget:UnitCommand(unit_id, unit_def_if, unit_team, cmd_id, cmd_params, cmd_opts, cmd_tag)
    if is_debug then debug_cmd("UnitCommand", unit_id, cmd_id, cmd_params, cmd_opts) end
    if (unit_def_if == SWIFT_DEF_ID) then
        local ctrl = land_attacker_controllers[unit_id]
        if (ctrl) then ctrl:process_cmd(cmd_id) end
    end
end

--- Called for newly introduced CMD_LAND_ATTACK
---
--- From https://springrts.com/wiki/Lua:Callins :
--- Called when a command is issued. Returning true deletes the command and does not send it through the network.
--- (Unsynced only)
function widget:CommandNotify(cmd_id, cmd_params, cmd_opts)
    if SSIDs ~= nil then
        if is_debug then debug_cmd("CommandNotify", unit_id, cmd_id, cmd_params, cmd_opts) end
        if (cmd_id == CMD_LAND_ATTACK and #cmd_params == 3) then
            local target_pos = cmd_params
            mission_control:process_target(target_pos)
            for i = 1, #SSIDs do
                land_attacker_controllers[SSIDs[i]]:execute(target_pos)
            end
            return true
        else
            for i = 1, #SSIDs do
                local land_attacker_controller = land_attacker_controllers[SSIDs[i]]
                if (land_attacker_controller) then land_attacker_controller:process_cmd(cmd_id) end
            end
        end
    end
end

function widget:SelectionChanged(selected_units)
    SSIDs = find_land_attackers(selected_units)
    if SSIDs ~= nil then
        for i = 1, #SSIDs do
            local land_attacker_controller = land_attacker_controllers[SSIDs[i]]
            if (land_attacker_controller) then land_attacker_controller.selection_idx = i end
        end
    end
end

function widget:CommandsChanged()
    if SSIDs then
        local customCommands = widgetHandler.customCommands
        customCommands[#customCommands + 1] = CMD_LAND_ATTACK_DEF
    end
end

----------------------------------------------------------------------------------------------------------------------
-- Disable for spec
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

----------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------
