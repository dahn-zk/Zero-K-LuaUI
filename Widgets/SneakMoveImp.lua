function widget:GetInfo()
   return {
    name      = "SneakMoveImp",
    desc      = "Attempt to make Imp sneak. Version 0,5",
    author    = "terve886",
    date      = "2019",
    license   = "PD", -- should be compatible with Spring
    layer     = 2,
	handler		= true, --for adding customCommand into UI
    enabled   = true  --  loaded by default?
  }
end

local pi = math.pi
local sin = math.sin
local cos = math.cos
local atan = math.atan
local ceil = math.ceil
local UPDATE_FRAME=30
local SneakerStack = {}
local GetUnitMaxRange = Spring.GetUnitMaxRange
local GetUnitPosition = Spring.GetUnitPosition
local GetMyAllyTeamID = Spring.GetMyAllyTeamID
local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetGroundHeight = Spring.GetGroundHeight
local GetUnitsInSphere = Spring.GetUnitsInSphere
local GetUnitAllyTeam = Spring.GetUnitAllyTeam
local GetUnitIsDead = Spring.GetUnitIsDead
local GetTeamUnits = Spring.GetTeamUnits
local GetMyTeamID = Spring.GetMyTeamID
local GetUnitDefID = Spring.GetUnitDefID
local GetUnitHealth = Spring.GetUnitHealth
local SetUnitMoveGoal = Spring.SetUnitMoveGoal
local ENEMY_DETECT_BUFFER  = 74
local Echo = Spring.Echo
local initDone = false
local Imp_NAME = "cloakbomb"
local GetSpecState = Spring.GetSpectatingState
local FULL_CIRCLE_RADIANT = 2 * pi
local CMD_UNIT_SET_TARGET = 34923
local CMD_UNIT_CANCEL_TARGET = 34924
local CMD_STOP = CMD.STOP
local CMD_OPT_SHIFT = CMD.OPT_SHIFT
local CMD_INSERT = CMD.INSERT
local CMD_ATTACK = CMD.ATTACK
local CMD_MOVE = CMD.MOVE
local CMD_REMOVE = CMD.REMOVE
local CMD_RAW_MOVE  = 31109
local CMD_OPT_INTERNAL = CMD.OPT_INTERNAL
local CMD_WANTED_SPEED = 38825


local CMD_SNEAK = 19996
local ImpUnitDefID = UnitDefNames["cloakbomb"].id
local selectedSneakers = nil

local cmdSneak = {
	id      = CMD_SNEAK,
	type    = CMDTYPE.ICON_MAP,
	tooltip = 'Makes Imp sneak slowly to target location.',
	cursor  = 'Attack',
	action  = 'reclaim',
	params  = { }, 
	texture = 'LuaUI/Images/commands/Bold/dgun.png',
	pos     = {CMD_ONOFF,CMD_REPEAT,CMD_MOVE_STATE,CMD_FIRE_STATE, CMD_RETREAT},  
}


local SneakController = {
	unitID,
	pos,
	allyTeamID = GetMyAllyTeamID(),
	range,
	alive = false,
	targetParams,
	
	
	new = function(self, unitID)
		Echo("sneakController added:" .. unitID)
		self = deepcopy(self)
		self.unitID = unitID
		self.alive = true
		self.range = GetUnitMaxRange(self.unitID)
		self.pos = {GetUnitPosition(self.unitID)}
		return self
	end,

	unset = function(self)
		Echo("SneakController removed:" .. self.unitID)
		self.alive = false
		GiveOrderToUnit(self.unitID,CMD_STOP, {}, {""},1)
		return self
	end,
	
	setTargetParams = function (self, params)
		self.targetParams = params
	end,
	
	
	sneak = function(self)
		GiveOrderToUnit(self.unitID,CMD_RAW_MOVE, self.targetParams, CMD_OPT_INTERNAL)
	end
}

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if (cmdID == CMD_SNEAK) then
		for _,Imp in pairs(SneakerStack) do
			if(Imp.unitID == unitID)then
				GiveOrderToUnit(unitID, CMD_WANTED_SPEED, 1.4, 0)
			end
		end
	end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
		if (UnitDefs[unitDefID].name==Imp_NAME)
		and (unitTeam==GetMyTeamID()) then
			SneakerStack[unitID] = SneakController:new(unitID);
		end
end

function widget:UnitDestroyed(unitID) 
	if not (SneakerStack[unitID]==nil) then
		SneakerStack[unitID]=SneakerStack[unitID]:unset();
	end
end


function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

--- COMMAND HANDLING

function widget:CommandNotify(cmdID, params, options)
	if selectedSneakers ~= nil then
		if (cmdID == CMD_SNEAK and #params == 3)then
			for i=1, #selectedSneakers do
				for _,Imp in pairs(SneakerStack) do
					if (selectedSneakers[i] == Imp.unitID)then
						Imp:setTargetParams(params)
						Imp:sneak()
					end
				end
			end
		end
	end
end

function widget:SelectionChanged(selectedUnits)
	selectedSneakers = filterSneakers(selectedUnits)
end

function filterSneakers(units)
	local filtered = {}
	local n = 0
	for i = 1, #units do
		local unitID = units[i]
		if (ImpUnitDefID == GetUnitDefID(unitID)) then
			n = n + 1
			filtered[n] = unitID
		end
	end
	if n == 0 then
		return nil
	else
		return filtered
	end
end

function widget:CommandsChanged()
	if selectedSneakers then
		local customCommands = widgetHandler.customCommands
		customCommands[#customCommands+1] = cmdSneak
	end
end



-- The rest of the code is there to disable the widget for spectators
local function DisableForSpec()
	if GetSpecState() then
		widgetHandler:RemoveWidget()
	end
end


function widget:Initialize()
	DisableForSpec()
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end
