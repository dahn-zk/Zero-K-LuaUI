function widget:GetInfo()
  return {
    name      = "Athena Rallypoints 3",
    desc      = "Rally points! /facs to toggle facs (default off), /athenas to toggle more waypoints",
    author    = "sprang, Sprung, CarRepairer, TheFatController",
    date      = "",
    license   = "GNU GPL, v2 or later",
    handler   = true,
    layer     = 0,
    enabled = false
  }
end

-- speed-ups
local glDepthTest      = gl.DepthTest
local glAlphaTest      = gl.AlphaTest
local glTexture        = gl.Texture
local glTexRect        = gl.TexRect
local glTranslate      = gl.Translate
local glBillboard      = gl.Billboard
local glDrawFuncAtUnit = gl.DrawFuncAtUnit
local glColor          = gl.Color
local GL_GREATER       = GL.GREATER

local CMD_WAIT          = CMD.WAIT
local CMD_MOVE          = CMD.MOVE
local CMD_PATROL        = CMD.PATROL
local CMD_REPAIR        = CMD.REPAIR

local CMD_CLOAK         = CMD.CLOAK
local CMD_ONOFF         = CMD.ONOFF
local CMD_REPEAT        = CMD.REPEAT
local CMD_MOVE_STATE    = CMD.MOVE_STATE
local CMD_FIRE_STATE    = CMD.FIRE_STATE

local CMD_INSERT        = CMD.INSERT
local CMD_REMOVE        = CMD.REMOVE
local CMD_SET_WANTED_MAX_SPEED = CMD.SET_WANTED_MAX_SPEED

local CMD_SETPLACE      = 10002


local GetGameFrame     = Spring.GetGameFrame
local GetLocalTeamID   = Spring.GetLocalTeamID
local GetUnitHealth    = Spring.GetUnitHealth
local GetUnitCommands  = Spring.GetUnitCommands
local GetUnitPosition  = Spring.GetUnitPosition
local GetUnitDefID     = Spring.GetUnitDefID
local GetSelectedUnits = Spring.GetSelectedUnits
local GetUnitStates    = Spring.GetUnitStates

local AreTeamsAllied   = Spring.AreTeamsAllied
local GiveOrderToUnit  = Spring.GiveOrderToUnit
local IsGuiHidden		=	Spring.IsGUIHidden

local abs, rand       = math.abs, math.random

local iconsize   = 30
local iconhsize  = iconsize * 0.5
local dist = 160
local maxDistSqr = dist * dist
local myTeamID
local tooltips = {}
local mobileUnits, cancelRetreatCommands, Places = {}, {}, {}
local PlaceCount = 0


-----

local GetCommandQueue = Spring.GetCommandQueue
local GetPlayerInfo = Spring.GetPlayerInfo
local GetUnitPosition = Spring.GetUnitPosition
local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetMyTeamID = Spring.GetMyTeamID

local fac = 0 -- by sprung!
local moar_athenas = 0

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


local function removePlace(PlaceID) -- moved by sprung (used in text command)
	if Places[PlaceID] then
		Places[PlaceID] = Places[PlaceCount]
		PlaceCount = PlaceCount - 1
	end
	Places[PlaceCount+1] = nil
end


local echo = Spring.Echo
-- sprung's code again, ugly ifs but i had syntax errors
function widget:TextCommand(command)
  if (string.find(command, 'facs') == 1) then
	if(fac == 0) then
		fac = 1
		echo('Facs enabled!')
	else
		fac = 0
		echo('Facs disabled!')
	end
  end
  if (string.find(command, 'athenas') == 1) then
	if(moar_athenas == 0) then
		moar_athenas = 1
		echo('More rally points!')
	else
		while(PlaceCount > 1) do
			removePlace(2)
		end
		moar_athenas = 0
		echo('One rally point!')
	end
  end
end
--

local function FindClosestPlace(sx, _, sz)
  local closestDistSqr = math.huge
  local cx, cy, cz  --  closest coordinates
  for PlaceID, PlacePosition in pairs(Places) do
    local hx, hy, hz = PlacePosition[1], PlacePosition[2], PlacePosition[3]
    if hx then 
      local dSquared = (hx - sx)^2 + (hz - sz)^2
      if (dSquared < closestDistSqr) then
        closestDistSqr = dSquared
        cx = hx; cy = hy; cz = hz
	cPlaceID = PlaceID
      end
    end
  end
  if (not cx) then return -1, -1, -1, -1 end  -- should not happen
  return cx, cy, cz, closestDistSqr, cPlaceID
end

local function FindClosestPlaceToUnit(unitID)
  local x, y, z = GetUnitPosition(unitID)
  return FindClosestPlace(x, y, z)
end

local function addPlace(x, y, z) -- modifications by sprung
	if(moar_athenas == 1) then
		PlaceCount = PlaceCount + 1
	else
		PlaceCount = 1
	end
	Places[PlaceCount] = {x, y, z}
end

function widget:CommandNotify(cmdID, cmdParams, cmdOptions)
	if cmdID == CMD_SETPLACE then
		local x,y,z = cmdParams[1], cmdParams[2], cmdParams[3]
		local _, _, _, dSquared, closestPlaceID = FindClosestPlace(x,y,z)
		if dSquared ~= -1 and dSquared < dist*dist then
			removePlace(closestPlaceID)
		else
			addPlace(x,y,z)
		end
		return true
	end
end

function widget:CommandsChanged()
	local selectedUnits = GetSelectedUnits()
	local foundRetreatable = false
	local customCommands = widgetHandler.customCommands

	table.insert(customCommands, {
		id      = CMD_SETPLACE,
		type    = CMDTYPE.ICON_MAP,
		tooltip = 'Athena rallypoint.',
		cursor  = 'Repair',
		action  = 'setPlace',
		params  = { }, 
		texture = 'LuaUI/Images/friendly.png',

		pos = {CMD_CLOAK,CMD_ONOFF,CMD_REPEAT,CMD_MOVE_STATE,CMD_FIRE_STATE, CMD_RETREAT}, 
	})
end

function widget:DrawWorld()
	local gameFrame = GetGameFrame()

	local frame32 = (gameFrame+1) % 32
	local frame160 = frame32 % 5

	local fade = abs((gameFrame % 40) - 20) / 20


	--Draw ambulance on Places.
	if (Places) then

		glDepthTest(true)
		gl.LineWidth(2)

		for PlaceID, PlacePosition in pairs(Places) do
			local x, y, z = PlacePosition[1], PlacePosition[2], PlacePosition[3]

			gl.LineWidth(4)
			glColor(1, 1, 1, 0.5)
			gl.DrawGroundCircle(x, y, z, dist, 32)

			gl.LineWidth(2)
			glColor(1, 0.1, 0.1, 0.8)
			gl.DrawGroundCircle(x, y, z, dist, 32)

		end --for
		glAlphaTest(GL_GREATER, 0)
		glColor(1,fade,fade,fade+0.1)
		glTexture('LuaUI/Images/friendly.png')
		
		for unitID, PlacePosition in pairs(Places) do
			local x, y, z = PlacePosition[1], PlacePosition[2], PlacePosition[3]
			gl.PushMatrix()
			glTranslate(x, y, z)
			glBillboard()
			glTexRect(-10, 0, 10, 20)
			gl.PopMatrix()
		end --for
		
		glTexture(false)
		glAlphaTest(false)
		glDepthTest(false)
	end --if Places
end --DrawWorld


---------------------------------------

local countDown = -1
local DELAY = 0.2
local moveUnits = {}
local myID = 0

local function checkSpec()
  local _, _, spec = GetPlayerInfo(myID)
  if spec then
    widgetHandler:RemoveWidget()
  end
end

function widget:Initialize()
 myID = Spring.GetMyPlayerID()
 checkSpec()
end

function widget:Update(deltaTime)
 if (countDown == -1) then
   return
 else
   countDown = countDown + deltaTime
 end

 if (countDown > DELAY) then
   for unitID,_ in pairs(moveUnits) do
		-- fixes for fac units by sprung
		if(fac == 0) then
			local cQueue = GetCommandQueue(unitID)
			if (table.getn(cQueue) == 0) then
				local x, y, z = FindClosestPlaceToUnit(unitID)
				GiveOrderToUnit(unitID, CMD.FIGHT,  { x, y, z}, { "" })
			end
		else
			local x, y, z = FindClosestPlaceToUnit(unitID)
			GiveOrderToUnit(unitID, CMD.FIGHT,  { x, y, z}, { "" })
		end
   end
   moveUnits = {}
   countDown = -1
 end
end

function widget:UnitFromFactory(unitID, unitDefID, unitTeam, factID, factDefID, userOrders)                          
  if(fac == 0) then -- sprung
	  for uID,_ in pairs(moveUnits) do
		if (uID == unitID) then
		  table.remove(moveUnits,uID)
		  break
		end
	  end
	end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
 if (unitTeam ~= GetMyTeamID()) then
   return
 end
   
 local ud = UnitDefs[unitDefID]
 if (ud and (ud.isCommander == false) and (ud.speed > 0)) then
   checkSpec()
   moveUnits[unitID] = true
   countDown = 0
 end
end


