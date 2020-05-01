version = "1.0"
cmd_dsc = "Command Swift to land optimally to fire on target area."

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

--[[
TODO:
- Dont reset Idle State to Fly on any manual command except the first one after Land Assault.
]]

is_debug = true

LIBS_PATH = "LuaUI/Widgets/Libs"
if is_debug then VFS.Include(LIBS_PATH .. "/TableToString.lua") end
VFS.Include(LIBS_PATH .. "/DeepCopy.lua")

local pi   = math.pi
local sin  = math.sin
local cos  = math.cos
local atan = math.atan

local GetUnitMaxRange     = Spring.GetUnitMaxRange
local GetUnitPosition     = Spring.GetUnitPosition
local GetMyAllyTeamID     = Spring.GetMyAllyTeamID
local GiveOrderToUnit     = Spring.GiveOrderToUnit
local GetGroundHeight     = Spring.GetGroundHeight
local GetUnitsInSphere    = Spring.GetUnitsInSphere
local GetUnitAllyTeam     = Spring.GetUnitAllyTeam
local GetUnitIsDead       = Spring.GetUnitIsDead
local GetTeamUnits        = Spring.GetTeamUnits
local GetMyTeamID         = Spring.GetMyTeamID
local GetUnitDefID        = Spring.GetUnitDefID
local GetUnitHealth       = Spring.GetUnitHealth
local GetUnitStates       = Spring.GetUnitStates
local GetUnitMoveTypeData = Spring.GetUnitMoveTypeData
local GetSpecState        = Spring.GetSpectatingState
local Echo                = Spring.Echo

local ENEMY_DETECT_BUFFER = 74
local FULL_CIRCLE_RADIANT = 2 * pi

local CMD_UNIT_SET_TARGET    = 34923
local CMD_UNIT_CANCEL_TARGET = 34924
local CMD_STOP               = CMD.STOP
local CMD_OPT_SHIFT          = CMD.OPT_SHIFT
local CMD_INSERT             = CMD.INSERT
local CMD_ATTACK             = CMD.ATTACK
local CMD_MOVE               = CMD.MOVE
local CMD_RAW_MOVE           = 31109
local CMD_REMOVE             = CMD.REMOVE
local CMD_OPT_INTERNAL       = CMD.OPT_INTERNAL
local CMD_AP_FLY_STATE       = 34569
local CMD_TOGGLE_FLIGHT      = 145
local CMD_LAND_ATTACK        = 19996

local SWIFT_NAME   = "planefighter"
local SWIFT_DEF_ID = UnitDefNames[SWIFT_NAME].id

local swiftStack     = {}
local selectedSwifts = nil

local cmdLandAttack = {
    id      = CMD_LAND_ATTACK,
    type    = CMDTYPE.ICON_MAP,
    tooltip = 'Makes Swift land optimally to fire at target area.',
    cursor  = 'Attack',
    action  = 'reclaim',
    params  = { },
    texture = 'LuaUI/Images/commands/Bold/dgun.png',
    pos     = { CMD_ONOFF, CMD_REPEAT, CMD_MOVE_STATE, CMD_FIRE_STATE, CMD_RETREAT },
}

local LandAttackController = {
    unitID,
    pos,
    allyTeamID = GetMyAllyTeamID(),
    range,
    targetParams,
    is_activated = false,
    
    new = function(self, unitID)
        self        = deepcopy(self)
        self.unitID = unitID
        self.range  = GetUnitMaxRange(self.unitID)
        self.pos    = { GetUnitPosition(self.unitID) }
        if is_debug then Echo("[LandAttackController] Added " .. unitID) end
        return self
    end,
    
    unset = function(self)
        GiveOrderToUnit(self.unitID, CMD_STOP, {}, { "" }, 1)
        if is_debug then Echo("[LandAttackController] Removed " .. self.unitID) end
        return nil
    end,
    
    setTargetParams = function(self, params)
        self.targetParams = params
    end,
    
    landAttack = function(self)
        self.pos = { GetUnitPosition(self.unitID) }
        local rotation = atan((self.pos[1] - self.targetParams[1]) / (self.pos[3] - self.targetParams[3]))
        local targetPosRelative = {
            sin(rotation) * (self.range - 40),
            nil,
            cos(rotation) * (self.range - 40),
        }
    
        local targetPosAbsolute = {}
    
        if (self.pos[3] <= self.targetParams[3]) then
            targetPosAbsolute = {
                self.targetParams[1] - targetPosRelative[1],
                nil,
                self.targetParams[3] - targetPosRelative[3],
            }
        else
            targetPosAbsolute = {
                self.targetParams[1] + targetPosRelative[1],
                nil,
                self.targetParams[3] + targetPosRelative[3],
            }
        end
    
        targetPosAbsolute[2] = GetGroundHeight(targetPosAbsolute[1], targetPosAbsolute[3])
        if is_debug then Echo("[LandAttackController] Attacking " .. table_to_string(targetPosAbsolute) .. ", attacker pos: " .. table_to_string(self.pos)) end
        GiveOrderToUnit(self.unitID, CMD_TOGGLE_FLIGHT, 1, { "" }, 0)
        GiveOrderToUnit(self.unitID, CMD_MOVE, { targetPosAbsolute[1], targetPosAbsolute[2], targetPosAbsolute[3] }, 0)
        
        self.is_activated = true
    end,
    
    cancel = function(self)
        self.is_activated = false
    end,
}

function widget:UnitFinished(unitID, unitDefID, unitTeam)
    if (UnitDefs[unitDefID].name == SWIFT_NAME) and (unitTeam == GetMyTeamID()) then
        swiftStack[unitID] = LandAttackController:new(unitID);
    end
end

function widget:UnitDestroyed(unitID)
    landAttackController = swiftStack[unitID]
    if not (landAttackController == nil) then
        swiftStack[unitID] = landAttackController:unset()
    end
end

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
    if (cmdID == CMD_RAW_MOVE and UnitDefs[unitDefID].name == SWIFT_NAME) then
        landAttackController = swiftStack[unitID]
        if (landAttackController and landAttackController.is_activated) then
            landAttackController:cancel()
        end
    end
end

--- COMMAND HANDLING

function widget:CommandNotify(cmdID, params, options)
    if selectedSwifts ~= nil then
        if (cmdID == CMD_LAND_ATTACK and #params == 3) then
            for i = 1, #selectedSwifts do
                if (swiftStack[selectedSwifts[i]]) then
                    swiftStack[selectedSwifts[i]]:setTargetParams(params)
                    swiftStack[selectedSwifts[i]]:landAttack()
                end
            end
            return true
        else
            for i = 1, #selectedSwifts do
                if (swiftStack[selectedSwifts[i]]) then
                    GiveOrderToUnit(selectedSwifts[i], CMD_TOGGLE_FLIGHT, 0, { "" }, 0)
                end
            end
        end
    end
end

function widget:SelectionChanged(selectedUnits)
    selectedSwifts = findSwifts(selectedUnits)
end

function findSwifts(units)
    local res = {}
    local n = 0
    for i = 1, #units do
        local unitID = units[i]
        if (SWIFT_DEF_ID == GetUnitDefID(unitID)) then
            n = n + 1
            res[n] = unitID
        end
    end
    if n == 0 then
        return nil
    else
        return res
    end
end

function widget:CommandsChanged()
    if selectedSwifts then
        local customCommands = widgetHandler.customCommands
        customCommands[#customCommands + 1] = cmdLandAttack
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
        unitID = units[i]
        DefID  = GetUnitDefID(unitID)
        if (UnitDefs[DefID].name == SWIFT_NAME) then
            if (swiftStack[unitID] == nil) then
                swiftStack[unitID] = LandAttackController:new(unitID)
            end
        end
    end
end
