function widget:GetInfo()
   return {
    name      = "SingleAttack",
    desc      = "Attempt to add SingleAttack command. Version 0,99",
    author    = "terve886",
    date      = "2019",
    license   = "PD", -- should be compatible with Spring
    layer     = 2,
	handler		= true, --for adding customCommand into UI
    enabled = false  --  loaded by default?
  }
end

local pi = math.pi
local sin = math.sin
local cos = math.cos
local atan = math.atan
local ceil = math.ceil
local abs = math.abs
local sqrt = math.sqrt
local UPDATE_FRAME=30
local currentFrame = 0
local UnitStack = {}
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
local GetUnitStates = Spring.GetUnitStates
local GetUnitWeaponState = Spring.GetUnitWeaponState
local ENEMY_DETECT_BUFFER  = 74
local Echo = Spring.Echo
local Impaler_NAME = "vehheavyarty"
local Emissary_NAME = "tankarty"
local Merlin_NAME = "striderarty"
local Firewalker_NAME = "jumparty"
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
local CMD_FIRE_STATE = CMD.FIRE_STATE
local CMD_UNIT_SET_TARGET = 34923
local CMD_UNIT_CANCEL_TARGET = 34924
local CMD_UNIT_AI = 36214


local CMD_SINGLE_ATTACK = 18976
local ImpalerUnitDefID = UnitDefNames["vehheavyarty"].id
local EmissaryUnitDefID = UnitDefNames["tankarty"].id
local MerlinUnitDefID = UnitDefNames["striderarty"].id
local FirewalkerUnitDefID = UnitDefNames["jumparty"].id
local selectedUnits = nil

local cmdSingleAttack = {
	id      = CMD_SINGLE_ATTACK,
	type    = CMDTYPE.ICON_UNIT_OR_MAP,
	tooltip = 'A single attack command',
	cursor  = 'Attack',
	action  = 'oneclickwep',
	params  = { }, 
	texture = 'LuaUI/Images/commands/Bold/dgun.png',
	pos     = {CMD_ONOFF,CMD_REPEAT,CMD_MOVE_STATE,CMD_FIRE_STATE, CMD_RETREAT},  
}


local SingleAttackController = {
	unitID,
	pos,
	allyTeamID = GetMyAllyTeamID(),
	range,
	targetParams = {},
	fireState,
	fireStateGot = false,
	shotFired = true,
	reloadState,
	reloading = false,
	pointer = 1,
	AiState,
	
	
	new = function(self, unitID)
		Echo("singleAttackController added:" .. unitID)
		self = deepcopy(self)
		self.unitID = unitID
		self.range = GetUnitMaxRange(self.unitID)
		self.pos = {GetUnitPosition(self.unitID)}
		local unitStates = {GetUnitStates(unitID)}
		self.fireState = unitStates[1]
		return self
	end,

	unset = function(self)
		Echo("SingleAttackController removed:" .. self.unitID)
		GiveOrderToUnit(self.unitID,CMD_STOP, {}, {""},1)
		return nil
	end,
	
	setTargetParams = function (self, params)
		self.targetParams[#self.targetParams+1] = params
	end,
	
	cancelSingleAttack = function(self)
		GiveOrderToUnit(self.unitID, CMD_UNIT_CANCEL_TARGET,0,0)
		self.pointer = 1
		self.targetParams = {}
		GiveOrderToUnit(self.unitID,CMD_FIRE_STATE, self.fireState, 0)
		GiveOrderToUnit(self.unitID,CMD_UNIT_AI, 1, 0)
		Echo("SingleAttack cancelled.")
	end,
	
	singleAttack = function(self)
		if (#self.targetParams==1) then
			if(self.fireStateGot == false)then
				local unitStates = GetUnitStates(self.unitID)
				self.fireState = unitStates.firestate
				self.fireStateGot = true
			end
			
			self.reloadState = GetUnitWeaponState(self.unitID, 1, "reloadState")
			if(currentFrame >= self.reloadState)then
				self.reloading = false
			else
				self.reloading = true
			end
			GiveOrderToUnit(self.unitID,CMD_UNIT_AI, 0, 0)
			GiveOrderToUnit(self.unitID,CMD_FIRE_STATE, 0, 0)
			if(#self.targetParams[self.pointer] == 1)then
				GiveOrderToUnit(self.unitID,CMD_UNIT_SET_TARGET, {self.targetParams[self.pointer][1]}, 0)
				self.pos = {GetUnitPosition(self.unitID)}
				local enemyPosition = {GetUnitPosition(self.targetParams[self.pointer][1])}
				if(distance ( self.pos[1], self.pos[3], enemyPosition[1], enemyPosition[3] )>self.range-20 )then
					local rotation = atan((self.pos[1]-enemyPosition[1])/(self.pos[3]-enemyPosition[3]))
					local targetPosRelative={
						sin(rotation) * (self.range-50),
						nil,
						cos(rotation) * (self.range-50),
					}

					local targetPosAbsolute = {}
					if (self.pos[3]<=enemyPosition[3]) then
						targetPosAbsolute = {
							enemyPosition[1]-targetPosRelative[1],
							nil,
							enemyPosition[3]-targetPosRelative[3],
						}
					else
							targetPosAbsolute = {
							enemyPosition[1]+targetPosRelative[1],
							nil,
							enemyPosition[3]+targetPosRelative[3],
						}
					end
					targetPosAbsolute[2]= GetGroundHeight(targetPosAbsolute[1],targetPosAbsolute[3])
					GiveOrderToUnit(self.unitID, CMD_INSERT, {0, CMD_MOVE, CMD_OPT_SHIFT, targetPosAbsolute[1], targetPosAbsolute[2], targetPosAbsolute[3]}, {"alt"})
				end	
				
			else
				GiveOrderToUnit(self.unitID,CMD_UNIT_SET_TARGET, {self.targetParams[self.pointer][1], self.targetParams[self.pointer][2], self.targetParams[self.pointer][3]}, {"alt"})
				self.pos = {GetUnitPosition(self.unitID)}
				if(distance ( self.pos[1], self.pos[3], self.targetParams[self.pointer][1], self.targetParams[self.pointer][3] )>self.range-20 )then
					local rotation = atan((self.pos[1]-self.targetParams[self.pointer][1])/(self.pos[3]-self.targetParams[self.pointer][3]))
					local targetPosRelative={
						sin(rotation) * (self.range-50),
						nil,
						cos(rotation) * (self.range-50),
					}

					local targetPosAbsolute = {}
					if (self.pos[3]<=self.targetParams[self.pointer][3]) then
						targetPosAbsolute = {
							self.targetParams[self.pointer][1]-targetPosRelative[1],
							nil,
							self.targetParams[self.pointer][3]-targetPosRelative[3],
						}
					else
							targetPosAbsolute = {
							self.targetParams[self.pointer][1]+targetPosRelative[1],
							nil,
							self.targetParams[self.pointer][3]+targetPosRelative[3],
						}
					end
					targetPosAbsolute[2]= GetGroundHeight(targetPosAbsolute[1],targetPosAbsolute[3])
					GiveOrderToUnit(self.unitID, CMD_INSERT, {0, CMD_MOVE, CMD_OPT_SHIFT, targetPosAbsolute[1], targetPosAbsolute[2], targetPosAbsolute[3]}, {"alt"})
				end	
			end
			self.shotFired = false
		end
	end,
	
	
	singleAttack2 = function(self, params)	
		self.reloadState = GetUnitWeaponState(self.unitID, 1, "reloadState")
		if(currentFrame >= self.reloadState)then
			self.reloading = false
		else
			self.reloading = true
		end

		if(#params == 1)then
			GiveOrderToUnit(self.unitID,CMD_UNIT_SET_TARGET, {params[1]}, 0)
			self.pos = {GetUnitPosition(self.unitID)}
			local enemyPosition = {GetUnitPosition(params[1])}
			if(distance ( self.pos[1], self.pos[3], enemyPosition[1], enemyPosition[3] )>self.range-20 )then
				local rotation = atan((self.pos[1]-enemyPosition[1])/(self.pos[3]-enemyPosition[3]))
				local targetPosRelative={
					sin(rotation) * (self.range-50),
					nil,
					cos(rotation) * (self.range-50),
				}

				local targetPosAbsolute = {}
				if (self.pos[3]<=enemyPosition[3]) then
					targetPosAbsolute = {
						enemyPosition[1]-targetPosRelative[1],
						nil,
						enemyPosition[3]-targetPosRelative[3],
					}
				else
						targetPosAbsolute = {
						enemyPosition[1]+targetPosRelative[1],
						nil,
						enemyPosition[3]+targetPosRelative[3],
					}
				end
				targetPosAbsolute[2]= GetGroundHeight(targetPosAbsolute[1],targetPosAbsolute[3])
				GiveOrderToUnit(self.unitID, CMD_INSERT, {0, CMD_MOVE, CMD_OPT_SHIFT, targetPosAbsolute[1], targetPosAbsolute[2], targetPosAbsolute[3]}, {"alt"})
			end	
			
		else
			GiveOrderToUnit(self.unitID,CMD_UNIT_SET_TARGET, {params[1], params[2], params[3]}, {"alt"})
			self.pos = {GetUnitPosition(self.unitID)}
			if(distance ( self.pos[1], self.pos[3], params[1], params[3] )>self.range-20 )then
				local rotation = atan((self.pos[1]-params[1])/(self.pos[3]-params[3]))
				local targetPosRelative={
					sin(rotation) * (self.range-50),
					nil,
					cos(rotation) * (self.range-50),
				}

				local targetPosAbsolute = {}
				if (self.pos[3]<=params[3]) then
					targetPosAbsolute = {
						self.targetParams[self.pointer][1]-targetPosRelative[1],
						nil,
						self.targetParams[self.pointer][3]-targetPosRelative[3],
					}
				else
						targetPosAbsolute = {
						self.targetParams[self.pointer][1]+targetPosRelative[1],
						nil,
						self.targetParams[self.pointer][3]+targetPosRelative[3],
					}
				end
				targetPosAbsolute[2]= GetGroundHeight(targetPosAbsolute[1],targetPosAbsolute[3])
				GiveOrderToUnit(self.unitID, CMD_INSERT, {0, CMD_MOVE, CMD_OPT_SHIFT, targetPosAbsolute[1], targetPosAbsolute[2], targetPosAbsolute[3]}, {"alt"})
			end	
		end
		self.shotFired = false
	end,
	
	handle = function(self, frame)
		if (#self.targetParams > 0) then
			local reload = GetUnitWeaponState(self.unitID, 1, "reloadState")
			if(self.reloading and reload > self.reloadState)then
				self.reloadState = reload-1
				self.reloading = false
				return
			end
			
			if (reload > self.reloadState)then
				if(reload <= frame+180)then
					self.shotFired = true
					GiveOrderToUnit(self.unitID, CMD_UNIT_CANCEL_TARGET,0,0)

					if(#self.targetParams<=self.pointer)then
						self.fireStateGot = false
						self.pointer = 1
						self.targetParams = {}
						GiveOrderToUnit(self.unitID,CMD_FIRE_STATE, self.fireState, 0)
						GiveOrderToUnit(self.unitID,CMD_UNIT_AI, 1, 0)
					else
						self.pointer = self.pointer+1
						self:singleAttack2(self.targetParams[self.pointer])
					end
					
				end
			end

		end
	end
}

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if (not(cmdID==CMD_MOVE_ID or cmdID==2 or cmdID==1 or cmdID==CMD_SINGLE_ATTACK or cmdID==CMD_UNIT_AI or cmdID==16 or cmdID==CMD_UNIT_CANCEL_TARGET or cmdID==CMD_FIRE_STATE) 
	and (UnitDefs[unitDefID].name==Impaler_NAME 
	or UnitDefs[unitDefID].name==Firewalker_NAME 
	or UnitDefs[unitDefID].name==Merlin_NAME 
	or UnitDefs[unitDefID].name==Emissary_NAME)) then
		for _,Unit in pairs(UnitStack) do
			if(Unit.unitID == unitID)then
				Unit:cancelSingleAttack()
			end
		end
	end
end

function distance ( x1, y1, x2, y2 )
  local dx = (x1 - x2)
  local dy = (y1 - y2)
  return sqrt ( dx * dx + dy * dy )
end

function widget:GameFrame(n)
	currentFrame = n
	if (n%UPDATE_FRAME==0) then
		for _,unit in pairs(UnitStack) do
			unit:handle(n)
		end
	end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
		if (UnitDefs[unitDefID].name==Impaler_NAME 
		or UnitDefs[unitDefID].name==Emissary_NAME 
		or UnitDefs[unitDefID].name==Merlin_NAME 
		or UnitDefs[unitDefID].name==Firewalker_NAME)
		and (unitTeam==GetMyTeamID()) then
			UnitStack[unitID] = SingleAttackController:new(unitID);
		end
end

function widget:UnitDestroyed(unitID) 
	if not (UnitStack[unitID]==nil) then
		UnitStack[unitID]=UnitStack[unitID]:unset();
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
	if selectedUnits ~= nil then
		if (cmdID == CMD_SINGLE_ATTACK and (#params == 3 or #params == 1))then
			for i=1, #selectedUnits do
				if (UnitStack[selectedUnits[i]])then
					UnitStack[selectedUnits[i]]:setTargetParams(params)
					UnitStack[selectedUnits[i]]:singleAttack()
				end
			end
		end
	end
end

function widget:SelectionChanged(selectedUnitz)
	selectedUnits = filterUnits(selectedUnitz)
end

function filterUnits(units)
	local filtered = {}
	local n = 0
	for i = 1, #units do
		local unitID = units[i]
		if (ImpalerUnitDefID == GetUnitDefID(unitID) 
		or EmissaryUnitDefID == GetUnitDefID(unitID) 
		or MerlinUnitDefID == GetUnitDefID(unitID) 
		or FirewalkerUnitDefID == GetUnitDefID(unitID)) then
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
	if selectedUnits then
		local customCommands = widgetHandler.customCommands
		customCommands[#customCommands+1] = cmdSingleAttack
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
	local units = GetTeamUnits(Spring.GetMyTeamID())
	for i=1, #units do
		DefID = GetUnitDefID(units[i])
		if (UnitDefs[DefID].name==Impaler_NAME 
		or UnitDefs[DefID].name==Emissary_NAME 
		or UnitDefs[DefID].name==Merlin_NAME 
		or UnitDefs[DefID].name==Firewalker_NAME)  then
			if  (UnitStack[units[i]]==nil) then
				UnitStack[units[i]]=SingleAttackController:new(units[i])
			end
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end