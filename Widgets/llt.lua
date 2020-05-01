--v1.42
function widget:GetInfo()
   return {
      name         = "AutoLLT",
      desc         = "",
      author       = "snoke",
      date         = "now",
      license 	   = "GNU GPL, v2 or later",
      layer        = 0,
      enabled      = true
   }
end
---------------------Speedups---------------------
local Echo = Spring.Echo
local GetMyAllyTeamID = Spring.GetMyAllyTeamID
local GetUnitMaxRange = Spring.GetUnitMaxRange
local GetUnitPosition = Spring.GetUnitPosition
local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetGroundHeight = Spring.GetGroundHeight
local GetUnitsInSphere = Spring.GetUnitsInSphere
local GetUnitAllyTeam = Spring.GetUnitAllyTeam
local GetUnitIsDead = Spring.GetUnitIsDead
local GetMouseState = Spring.GetMouseState
local TraceScreenRay = Spring.TraceScreenRay
local GetUnitWeaponTestRange = Spring.GetUnitWeaponTestRange
local GetMyTeamID = Spring.GetMyTeamID
local GetSelectedUnits = Spring.GetSelectedUnits
local GetUnitDefID = Spring.GetUnitDefID
local GetSpectatingState = Spring.GetSpectatingState
local WorldToScreenCoords = Spring.WorldToScreenCoords
local GetCameraPosition = Spring.GetCameraPosition
local glText = gl.Texts
local glColor = gl.Color
---------------------CFG---------------------
--options
--local SHOW_GUI = true
local DISPLAY_INFOBOX = false
--local AUTO_ADD = true
local USE_KEYS = true
--keymaps
include("keysym.h.lua")

local keypressmem = {}
local initDone = false
--initial settings

local RANDOM_ROTATION_WAY_SWITCH = true
local RANDOM_ROTATION_WAY_CHANCE_PERCENTAGE = 8
local RADIANT_TO_DEGREES_FACTOR = 57.2958
local FULL_CIRCLE_RADIANT = 2 * math.pi
local LLT_NAME = "turretlaser"
local WINDOW_COLOR = {1, 1, 1, 0.7}
local WINDOW_FONT_SIZE = 12
local WINDOW_B_SIZE = 12
local WINDOW_LINE_PADDING = 3
local WINDOW_CELL_PADDING = 1
local INFOBOX_POSX_BUFFER = 0
local INFOBOX_POSY_BUFFER = 0
local INFOBOX_COLOR = {1,1,1,0.9}
local INFOBOX_FONT_SIZE = 10
local START_ROTATION = 22
local ENEMY_DETECT_BUFFER  = 5
local NAX_RANGE_BUFFER  = 20
local MIN_RANGE_BUFFER = 50	
local RADIUS_CHANGE_STEP = 10
local RADIUS_INCREASE_STEP = RADIUS_CHANGE_STEP
local RADIUS_DECREASE_STEP = RADIUS_CHANGE_STEP
local UPDATE_FRAME=1
local ROTATION_PER_FRAME = 0.15
local DRAW_CIRCLE_LIMIT = 100
local GROUND_CIRCLE_COLOR = {1,0,0,0.1}
local GROUND_CIRCLE_LINE_WIDTH = 3
local TARGET_DOT_COLOR = {0,1,1,0.1}
local TARGET_DOT_SIZE = 10
local TARGET_DOT_LINE_WIDTH = 10
local MAX_RANGE_DEFAULT = 450
local MIN_RANGE_DEFAULT = 300
--------------------------------------------------------------------------------
-- Epic Menu Options
--------------------------------------------------------------------------------
local window
options_path = 'Settings/Unit Behaviour/LLT Controller'
options_order = { 'show_gui','auto_add',
	--'default_max_range',
	--'default_min_range',
	'hotkey_add_llt','hotkey_increase_max_range','hotkey_decrease_max_range','hotkey_increase_min_range','hotkey_decrease_min_range','hotkey_clockwise','hotkey_draw_mode','hotkey_random_rotation' }
options = {
	show_gui = {
		name = 'Show LLT Controller Window',
		type = 'bool',
		value = true,
		noHotkey = true,
		OnChange= function(a)
			window:SetVisibility(a.value)
		end
	},
	auto_add = {
		name = 'Automatic start PartyMode',
		type = 'bool',
		value = true,
		noHotkey = true,
	},
	default_max_range = {
		name = "Default Max Range",
		desc = "Default Max Range",
		type = "number",
		value = 450,
		min = 50,
		max = 450,
		step = 10,
	},
	default_min_range = {
		name = "Default Min Range",
		desc = "Default Min Range",
		type = "number",
		value = 80,
		min = 50,
		max = 440,
		step = 10,
	},
	hotkey_add_llt = {
		name = 'Toggle Party Mode',
		type = 'button',
		noHotkey = false,
		action = 'add_llt_action',
	},
	hotkey_increase_max_range = {
		name = 'Increase Max Range Hotkey',
		type = 'button',
		noHotkey = false,
		action = 'increase_max_range_action',
	},
	hotkey_decrease_max_range = {
		name = 'Decrease Max Range Hotkey',
		type = 'button',
		noHotkey = false,
		action = 'decrease_max_range_action',
	},
	hotkey_increase_min_range = {
		name = 'Increase Min Range Hotkey',
		type = 'button',
		noHotkey = false,
		action = 'increase_min_range_action',
	},
	hotkey_decrease_min_range = {
		name = 'Decrease Min Range Hotkey',
		type = 'button',
		noHotkey = false,
		action = 'decrease_min_range_action',
	},
	hotkey_clockwise = {
		name = 'Toggle Clockwise',
		type = 'button',
		noHotkey = false,
		action = 'toggle_clockwise_action',
	},
	hotkey_draw_mode = {
		name = 'Start Drawmode',
		type = 'button',
		noHotkey = false,
		action = 'start_draw_mode_action',
	},
	hotkey_random_rotation = {
		name = 'Toggle RandomRotationWay',
		type = 'button',
		noHotkey = false,
		action = 'random_rotation_way_toggle_action',
	},
}
---------------------autoLLT Class---------------------
local autoLltStack = {}
local autoLLT = {
	LatestRandomRotationWaySwitch=nil,
	randomRotationWaySwitch = RANDOM_ROTATION_WAY_SWITCH,
	partyMode = true,
	unitID,
	pos,
	rotation = START_ROTATION,
	rotate = ROTATION_PER_FRAME,
	attacking=false,
	allyTeamID = GetMyAllyTeamID(),
	range,
	maxRange,
	minRange = options.default_min_range.value or MIN_RANGE_DEFAULT,
	clockwise = true,
	drawMode = false,
	targetDots = {},
	targetDotCounter = 1,
	drawInfobox = function (self)
		local WeaponVectors = {Spring.GetUnitWeaponVectors(self.unitID,1)} 
		glColor(INFOBOX_COLOR)
		local mode = "rotating"
		local clockwise = "yes"
		local maxRange = self.range
		local minRange = self.minRange
		local screenpos = {WorldToScreenCoords(self.pos[1],self.pos[2],self.pos[3])}
		screenpos[1] = screenpos[1] + INFOBOX_POSX_BUFFER
		screenpos[2] = screenpos[2] - INFOBOX_POSY_BUFFER
		screenpos[2] = screenpos[2] - INFOBOX_FONT_SIZE
		if not (#self.targetDots==0) then
			mode = "targetDots"
		end
		glText("mode : " ..mode,screenpos[1],screenpos[2],INFOBOX_FONT_SIZE)
		screenpos[2] = screenpos[2] - INFOBOX_FONT_SIZE
		glText("maxRange : " ..maxRange,screenpos[1],screenpos[2],INFOBOX_FONT_SIZE)
		screenpos[2] = screenpos[2] - INFOBOX_FONT_SIZE
		glText("minRange : " ..minRange,screenpos[1],screenpos[2],INFOBOX_FONT_SIZE)
		screenpos[2] = screenpos[2] - INFOBOX_FONT_SIZE
		if not (self.clockwise==true) then
			clockwise = "no"
		end
		glText("clockwise : " ..clockwise,screenpos[1],screenpos[2],INFOBOX_FONT_SIZE)
		screenpos[2] = screenpos[2] - INFOBOX_FONT_SIZE
		glText("WeaponVectors : " ..WeaponVectors[1] .. " " .. WeaponVectors[2] .. " " .. WeaponVectors[3],screenpos[1],screenpos[2],INFOBOX_FONT_SIZE)
		screenpos[2] = screenpos[2] - INFOBOX_FONT_SIZE
		local partyMode="off"
		if (self.partyMode==true) then
			partyMode="on"
		end
		glText("PartyMode : "  .. partyMode,screenpos[1],screenpos[2],INFOBOX_FONT_SIZE)
		screenpos[2] = screenpos[2] - INFOBOX_FONT_SIZE
		
	end,
	drawTargetDots = function (self) 
		for _,targetDot in pairs(self.targetDots) do
			gl.LineWidth(TARGET_DOT_LINE_WIDTH)
			gl.Color(TARGET_DOT_COLOR[1], TARGET_DOT_COLOR[2], TARGET_DOT_COLOR[3], TARGET_DOT_COLOR[4])
			gl.DrawGroundCircle(  targetDot[1],  targetDot[2],  targetDot[3],  TARGET_DOT_SIZE, TARGET_DOT_SIZE  )
		end
	end,
	
	drawOuterCircle = function(self)
		gl.LineWidth(GROUND_CIRCLE_LINE_WIDTH)
		gl.Color(GROUND_CIRCLE_COLOR[1], GROUND_CIRCLE_COLOR[2], GROUND_CIRCLE_COLOR[3], GROUND_CIRCLE_COLOR[4])
		gl.DrawGroundCircle(  self.pos[1],  self.pos[2],  self.pos[3],  self.maxRange, self.maxRange/3.14  )
	end,

	startDrawMode = function(self)
		self.targetDots={}
		Echo("drawMode started")
		self.drawMode = true
	end,
	
	stopDrawMode = function(self)
		Echo("drawMode stopped")
		self.drawMode = false
	end,
	
	new = function(self,unitID)
		Echo("autoLLT added:" .. unitID)
		self = deepcopy(self)
		if (options.auto_add.value==true) then
			self.partyMode=true
		else
			self.partyMode=false
		end
		self.unitID = unitID
		self.maxRange = GetUnitMaxRange(self.unitID)
		self.range = options.default_max_range.value or MAX_RANGE_DEFAULT
		self.minRange = options.default_min_range.value or MIN_RANGE_DEFAULT
		self.pos = {GetUnitPosition(self.unitID)}
		return self
	end,
	
	unset = function(self)
		Echo("autoLLT removed:" .. self.unitID)
		self.partyMode= false
		self.targetDots = {}
		GiveOrderToUnit(self.unitID,CMD.STOP, {}, {""},1)
		return self
	end,
	
	targetDotFireLoop = function (self)
		if (self.partyMode==true) then
			local targetPosAbsolute = self.targetDots[self.targetDotCounter]
			if not (targetPosAbsolute==nil) then
				GiveOrderToUnit(self.unitID,CMD.ATTACK, targetPosAbsolute, {""},1)
				if (self.clockwise==true) then
					self.targetDotCounter = self.targetDotCounter  + 1
					if (self.targetDotCounter>#self.targetDots) then
						self.targetDotCounter = 1
					end
				else
					self.targetDotCounter = self.targetDotCounter  - 1
					if (1>self.targetDotCounter) then
						self.targetDotCounter = #self.targetDots
					end
				end
			end
		end
	end,
	
	fireLoop=function(self)
		if (self.partyMode==true) then
			local distance = math.random(self.minRange, self.range)
			if (self.clockwise==true) then
				self.rotation = self.rotation - (self.rotate * UPDATE_FRAME)
				if (0>=self.rotation) then
					self.rotation = FULL_CIRCLE_RADIANT
				end
			else
				self.rotation = self.rotation + (self.rotate * UPDATE_FRAME)
				if (self.rotation>=FULL_CIRCLE_RADIANT) then
					self.rotation = self.rotation - FULL_CIRCLE_RADIANT
				end
			end
			local targetPosRelative={
				math.sin(self.rotation) * distance,
				nil,
				math.cos(self.rotation) * distance,
			}
			local targetPosAbsolute = {
				targetPosRelative[1] + self.pos[1],
				nil,
				targetPosRelative[3] + self.pos[3],
			}
			targetPosAbsolute[2]= GetGroundHeight(targetPosAbsolute[1],targetPosAbsolute[3])
			GiveOrderToUnit(self.unitID,CMD.ATTACK, targetPosAbsolute, {""},1)
			if(self.randomRotationWaySwitch==true) then
				local rand = math.random(100)
				if (rand>(100-RANDOM_ROTATION_WAY_CHANCE_PERCENTAGE)) then
					self:changeRotationWay()
				end
			end
		end
	end,
	
	changeRotationWay = function (self)
		--Spring.Echo(self.clockwise)
		if (self.clockwise == true) then
			self.clockwise = false
		else
			self.clockwise = true
		end
	end,
	
	toggleRandomRotation = function (self)
		if (self.randomRotationWaySwitch==true) then
			self.randomRotationWaySwitch=false
		else
			self.randomRotationWaySwitch=true
		end
	end,
	
	increaseMinRange = function (self)
		if (self.maxRange - NAX_RANGE_BUFFER >=self.minRange + RADIUS_INCREASE_STEP) 
		and (self.range>=self.minRange + RADIUS_INCREASE_STEP) then
			self.minRange = self.minRange + RADIUS_INCREASE_STEP
		end
		if not (self.range>=self.minRange + RADIUS_INCREASE_STEP) 
		and  (self.maxRange- NAX_RANGE_BUFFER>=self.minRange + RADIUS_INCREASE_STEP) then
			self:increaseMaxRange()
		end
	end,
	
	decreaseMinRange = function (self)
		if not (MIN_RANGE_BUFFER>=self.minRange - RADIUS_DECREASE_STEP) then
			self.minRange = self.minRange - RADIUS_DECREASE_STEP
		end
	end,
	
	increaseMaxRange = function (self)
		if (self.maxRange- NAX_RANGE_BUFFER>=self.range + RADIUS_INCREASE_STEP)then
			self.range = self.range + RADIUS_INCREASE_STEP
		end
	end,
	
	decreaseMaxRange = function (self)
		if (self.range - RADIUS_DECREASE_STEP>=self.minRange) 
		and (self.range - RADIUS_DECREASE_STEP>=MIN_RANGE_BUFFER) then
			self.range = self.range - RADIUS_DECREASE_STEP
		end
		if not (self.range - RADIUS_DECREASE_STEP>=self.minRange) 
		and  (self.range - RADIUS_DECREASE_STEP>=MIN_RANGE_BUFFER) then
			self:decreaseMinRange()
		end
	end,
	
	isEnemyInRange = function (self)
		for _,unitID in pairs(GetUnitsInSphere(self.pos[1], self.pos[2], self.pos[3], self.maxRange+ENEMY_DETECT_BUFFER)) do
			if not (GetUnitAllyTeam(unitID) == self.allyTeamID) then
				if  (GetUnitIsDead(unitID) == false) then
					return true
				end
			end
		end
		return false
	end,
	
	handle = function(self) 
	
		if (self.drawMode==true) then
			local mouseState = {GetMouseState()}
			if (mouseState[3] == true) then
				local ScreenRay = {TraceScreenRay(mouseState[1],mouseState[2],true)}
				local mouseGroundPos = ScreenRay[2]
				if not (mouseGroundPos==nil) then
					if  (GetUnitWeaponTestRange (self.unitID,1,mouseGroundPos[1],mouseGroundPos[2],mouseGroundPos[3]) ==true)  then
						self.targetDots[#self.targetDots+1] = mouseGroundPos
					end
				end
			end
		end
		
		if (self.attacking==false) then
			if (self:isEnemyInRange()==true) then
				GiveOrderToUnit(self.unitID,CMD.STOP, {}, {""},1)
				self.attacking=true;
			end
		else
			if (self:isEnemyInRange()==false) then
				self.attacking=false;
			end
		end
		if (self.attacking==false) then
			if (#self.targetDots==0) then
				self:fireLoop()
			else 
				self:targetDotFireLoop()
			end
		end
	end
}
---------------UI Functions----------------------
function widget:UiDisplay()
	window:SetVisibility(false)
	if (options.show_gui.value==true) then
		local partyMode
		local maxRange
		local minRange
		local clockwise
		local nTargetDots
		local randomRotationWay
		
		local lltSelected = false
		for k,unitID in pairs(GetSelectedUnits()) do
			DefID = GetUnitDefID(unitID)
			if (UnitDefs[DefID].name==LLT_NAME)  then
				if not (autoLltStack[unitID]==nil) then
					lltSelected = true
					if (randomRotationWay==nil) then randomRotationWay=autoLltStack[unitID].randomRotationWaySwitch end
					if not (randomRotationWay==autoLltStack[unitID].randomRotationWaySwitch) then
						randomRotationWay = "mixed"
					end
					if (partyMode==nil) then partyMode=autoLltStack[unitID].partyMode end
					if not (partyMode==autoLltStack[unitID].partyMode) then
						partyMode = "mixed"
					end
					if (clockwise==nil) then clockwise=autoLltStack[unitID].clockwise end
					if not (clockwise==autoLltStack[unitID].clockwise) then
						clockwise = "mixed"
					end
					if (maxRange==nil) then maxRange= autoLltStack[unitID].range end
					if not (maxRange==autoLltStack[unitID].range) then
						maxRange = "mixed"
					end
					if (minRange==nil) then minRange= autoLltStack[unitID].minRange end
					if not (minRange==autoLltStack[unitID].minRange) then
						minRange = "mixed"
					end
					
					if (nTargetDots==nil) then nTargetDots=#autoLltStack[unitID].targetDots end
					if not (nTargetDots==#autoLltStack[unitID].targetDots) then
						nTargetDots = "mixed"
					end
				end
			end
		end
		
		if (lltSelected==true) then
		
			window:SetVisibility(true)
			
			if (partyMode==true) then partyMode = "ON" elseif (partyMode==false) then partyMode="OFF" end
			if (clockwise==true) then clockwise = "ON" elseif (clockwise==false) then clockwise="OFF" end
			if (randomRotationWay==true) then randomRotationWay = "ON" elseif (randomRotationWay==false) then randomRotationWay="OFF" end
			
			window.children[3]:SetCaption(partyMode)
			window.children[6]:SetCaption(maxRange)
			window.children[10]:SetCaption(minRange)
			window.children[14]:SetCaption(clockwise)
			window.children[17]:SetCaption(nTargetDots)
			window.children[20]:SetCaption(randomRotationWay)
		end
	end
end
-----------------------Init----------------------
function widget:firstFrameInit()
	if (initDone==false) then
		for k,unitID in pairs(Spring.GetTeamUnits(Spring.GetMyTeamID())) do
			DefID = GetUnitDefID(unitID)
			if (UnitDefs[DefID].name==LLT_NAME)  then
				if  (autoLltStack[unitID]==nil) then
					autoLltStack[unitID]=autoLLT:new(unitID)
				end
			end
		end
		initDone=true
	end
end

function widget:initHotkeyActions()
	widgetHandler:AddAction("increase_max_range_action", IncreaseMaxRangeAction, nil, 'tp')
	widgetHandler:AddAction("decrease_max_range_action", DecreaseMaxRangeAction, nil, 'tp')
	widgetHandler:AddAction("increase_min_range_action", IncreaseMinRangeAction, nil, 'tp')
	widgetHandler:AddAction("decrease_min_range_action", DecreaseMinRangeAction, nil, 'tp')
	widgetHandler:AddAction("toggle_clockwise_action", ToggleClockwiseAction, nil, 'tp')
	widgetHandler:AddAction("add_llt_action", AddLltAction, nil, 'tp')
	widgetHandler:AddAction("start_draw_mode_action", StartDrawModeAction, nil, 'tp')
	widgetHandler:AddAction("random_rotation_way_toggle_action", ToggleRandomRotationAction, nil, 'tp')
end

function widget:initGUI()
    if (GetSpectatingState()) then
        widgetHandler:RemoveWidget()
    end
	window = WG.Chili.Window:New{
		name = "AutoLLT Window",
		x = 0,
		y = 250,
		savespace = false,
		resizable = false,
		draggable = true,
		autosize  = false,
		color = WINDOW_COLOR,
		parent = WG.Chili.Screen0,
		mainHeight=150,
		maxHeight=150,
		maxWidth=225,
		minWidth=225,
		children = {
			WG.Chili.Label:New{
				x=0,
				right=50,
				y = 0,
				height = WINDOW_FONT_SIZE,
				align = "center",
				font = {size = 12, outline = true, color = {1,1,0,1}},
				caption = "- LLT Controller -",
				fontSize = WINDOW_FONT_SIZE,
			},
			WG.Chili.Label:New{
				x = 0,
				y = (WINDOW_FONT_SIZE + WINDOW_LINE_PADDING) * 2,
				right = 0,
				height = WINDOW_FONT_SIZE,
				caption = "PartyMode",
				fontSize = WINDOW_FONT_SIZE,
			},
			WG.Chili.Label:New{
				x = 100,
				y = (WINDOW_FONT_SIZE + WINDOW_LINE_PADDING) * 2,
				height = WINDOW_FONT_SIZE,
				caption = "OFF",
				fontSize = WINDOW_FONT_SIZE,
			},
			WG.Chili.Button:New{
				x = 150,
				y = (WINDOW_FONT_SIZE + WINDOW_LINE_PADDING) * 2,
				height = WINDOW_FONT_SIZE,
				minWidth = 50,
				maxWidth = 50,
				name = "PartyMode",
				fontSize = WINDOW_FONT_SIZE,
				caption = "Toggle",
				OnClick  = {
					function()
						AddLltAction()
					end
				},
			},
			WG.Chili.Label:New{
				x = 0,
				y = (WINDOW_FONT_SIZE + WINDOW_LINE_PADDING) * 3,
				right = 0,
				height = WINDOW_FONT_SIZE,
				caption = "Max Range:",
				fontSize = WINDOW_FONT_SIZE,
			},
			WG.Chili.Label:New{
				name = "maxRange",
				x = 100,
				y = (WINDOW_FONT_SIZE + WINDOW_LINE_PADDING) * 3,
				height = WINDOW_FONT_SIZE,
				caption = options.default_max_range.value or MAX_RANGE_DEFAULT,
				fontSize = WINDOW_FONT_SIZE,
			},
			WG.Chili.Button:New{
				x = 150,
				y = (WINDOW_FONT_SIZE + WINDOW_LINE_PADDING) * 3,
				minWidth = 24.5,
				maxWidth = 24.5,
				height = WINDOW_FONT_SIZE,
				name = "Decrease Max Range",
				fontSize = WINDOW_FONT_SIZE,
				caption = "-",
				OnClick  = {
					function()
						widget:DecreaseMaxRangeAction()
					end
				},
			},
			WG.Chili.Button:New{
				x = 175.5,
				y = (WINDOW_FONT_SIZE + WINDOW_LINE_PADDING) * 3,
				minWidth = 24.5,
				maxWidth = 24.5,
				height = WINDOW_FONT_SIZE,
				name = "Increase Max Range",
				fontSize = WINDOW_FONT_SIZE,
				caption = "+",
				OnClick = {
					function()
						widget:IncreaseMaxRangeAction()
					end
				},
			},
			WG.Chili.Label:New{
				x = 0,
				y = (WINDOW_FONT_SIZE + WINDOW_LINE_PADDING) * 4,
				right = 0,
				height = WINDOW_FONT_SIZE,
				caption = "Min Range:",
				fontSize = WINDOW_FONT_SIZE,
			},
			WG.Chili.Label:New{
				name = "MinRange",
				x = 100,
				y = (WINDOW_FONT_SIZE + WINDOW_LINE_PADDING) * 4,
				height = WINDOW_FONT_SIZE,
				caption = MIN_RANGE_DEFAULT,
				fontSize = WINDOW_FONT_SIZE,
			},
			WG.Chili.Button:New{
				x = 150,
				y = (WINDOW_FONT_SIZE + WINDOW_LINE_PADDING) * 4,
				minWidth = 24.5,
				maxWidth = 24.5,
				height = WINDOW_FONT_SIZE,
				name = "Decrease Min Range",
				fontSize = WINDOW_FONT_SIZE,
				caption = "-",
				OnClick = {
					function()
						widget:DecreaseMinRangeAction()
					end
				},
			},
			WG.Chili.Button:New{
				x = 175.5,
				y = (WINDOW_FONT_SIZE + WINDOW_LINE_PADDING) * 4,
				minWidth = 24.5,
				maxWidth = 24.5,
				height = WINDOW_FONT_SIZE,
				name = "Increase Min Range",
				fontSize = WINDOW_FONT_SIZE,
				caption = "+",
				OnClick = {
					function()
						widget:IncreaseMinRangeAction()
					end
				},
			},
			WG.Chili.Label:New{
				x = 0,
				y = (WINDOW_FONT_SIZE + WINDOW_LINE_PADDING) * 5,
				right = 0,
				height = WINDOW_FONT_SIZE,
				caption = "Clockwise:",
				fontSize = WINDOW_FONT_SIZE,
			},
			WG.Chili.Label:New{
				x = 100,
				y = (WINDOW_FONT_SIZE + WINDOW_LINE_PADDING) * 5,
				right = 0,
				height = WINDOW_FONT_SIZE,
				caption = "YES",
				fontSize = WINDOW_FONT_SIZE,
			},
			WG.Chili.Button:New{
				x = 150,
				y = (WINDOW_FONT_SIZE + WINDOW_LINE_PADDING) * 5,
				minWidth = 50,
				maxWidth = 50,
				height = WINDOW_FONT_SIZE,
				name = "Clockwise",
				fontSize = WINDOW_FONT_SIZE,
				caption = "Toggle",
				OnClick = {
					function()
						widget:ToggleClockwiseAction()
					end
				},
			},
			WG.Chili.Label:New{
				x = 0,
				y = (WINDOW_FONT_SIZE + WINDOW_LINE_PADDING) * 6,
				right = 0,
				height = WINDOW_FONT_SIZE,
				caption = "TargetDots:",
				fontSize = WINDOW_FONT_SIZE,
			},
			WG.Chili.Label:New{
				x = 100,
				y = (WINDOW_FONT_SIZE + WINDOW_LINE_PADDING) * 6,
				right = 0,
				height = WINDOW_FONT_SIZE,
				caption = "None",
				fontSize = WINDOW_FONT_SIZE,
			},
			WG.Chili.Button:New{
				x = 150,
				y = (WINDOW_FONT_SIZE + WINDOW_LINE_PADDING) * 6,
				height = WINDOW_FONT_SIZE,
				minWidth = 50,
				maxWidth = 50,
				name = "TargetDots",
				fontSize = WINDOW_FONT_SIZE,
				caption = "Draw",
				OnClick = {
					function()
						widget:StartDrawModeAction()
					end
				},
			},
			WG.Chili.Label:New{
				x = 0,
				y = (WINDOW_FONT_SIZE + WINDOW_LINE_PADDING) * 7,
				right = 0,
				height = WINDOW_FONT_SIZE,
				caption = "RandomRotationToggle:",
				fontSize = WINDOW_FONT_SIZE,
			},
			WG.Chili.Button:New{
				x = 150,
				y = (WINDOW_FONT_SIZE + WINDOW_LINE_PADDING) * 7,
				height = WINDOW_FONT_SIZE,
				minWidth = 50,
				maxWidth = 50,
				name = "RandomRotationWayToggle",
				fontSize = WINDOW_FONT_SIZE,
				caption = "ON",
				OnClick = {
					function()
						widget:ToggleRandomRotationAction()
					end
				},
			},
		}
	}
	window:SetVisibility(false)
end
---------------------CallIns---------------------
function widget:Shutdown()
		for _,llt in pairs(autoLltStack) do
			llt:unset()
		end
end

function widget:Initialize()
	widget:initGUI()
	widget:initHotkeyActions()
end

function widget:GameFrame(n) 
	keypressmem = {}
	widget:firstFrameInit()
	widget:UiDisplay()
	if (n%UPDATE_FRAME==0) then
		for _,llt in pairs(autoLltStack) do
			llt:handle()
		end
	end
end

function widget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
		if (UnitDefs[unitDefID].name==LLT_NAME) then
			if (oldTeam==GetMyTeamID()) then
				autoLltStack[unitID]=autoLltStack[unitID]:unset()
			end
			if (newTeam==GetMyTeamID()) then
				autoLltStack[unitID] = autoLLT:new(unitID)
			end
		end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
		if (UnitDefs[unitDefID].name==LLT_NAME) 
		and (unitTeam==GetMyTeamID()) then
			autoLltStack[unitID] = autoLLT:new(unitID)
		end
end

function widget:UnitDestroyed(unitID) 
	if not (autoLltStack[unitID]==nil) then
		autoLltStack[unitID]=autoLltStack[unitID]:unset()
	end
end

function widget:KeyRelease(key)
	if (USE_KEYS==true) then
		if (key==KEYSYMS[ADD_AUTOLLT_KEY]) then
			for unitID,LLT in pairs(autoLltStack) do
				LLT:stopDrawMode()
			end
		end
	end
end

function widget:DrawScreenEffects()
	if (DISPLAY_INFOBOX==true) then
		for _,unitID in pairs(GetSelectedUnits()) do
			if not (autoLltStack[unitID]==nil) then
				autoLltStack[unitID]:drawInfobox()
			end
		end
	end
end

function widget:DrawWorld()
	for _,llt in pairs(autoLltStack) do
		if (llt.drawMode==true) then
			llt:drawOuterCircle()
			llt:drawTargetDots()
		end
	end
end

function widget:ToggleRandomRotationAction()
	if (keypressmem["ToggleRandomRotationAction"]==nil) then
		keypressmem["ToggleRandomRotationAction"]=true
		for k,unitID in pairs(GetSelectedUnits()) do
			if  not (autoLltStack[unitID]==nil) then
				autoLltStack[unitID]:toggleRandomRotation()
			end
		end
	end
end
function widget:IncreaseMaxRangeAction()
	if (keypressmem["IncreaseMaxRangeAction"]==nil) then
		keypressmem["IncreaseMaxRangeAction"]=true
		for k,unitID in pairs(GetSelectedUnits()) do
			if  not (autoLltStack[unitID]==nil) then
				autoLltStack[unitID]:increaseMaxRange()
			end
		end
	end
end

function widget:DecreaseMaxRangeAction()
	if (keypressmem["DecreaseMaxRangeAction"]==nil) then
		keypressmem["DecreaseMaxRangeAction"]=true
		for k,unitID in pairs(GetSelectedUnits()) do
			if  not (autoLltStack[unitID]==nil) then
				autoLltStack[unitID]:decreaseMaxRange()
			end
		end
	end
end

function widget:IncreaseMinRangeAction()
	if (keypressmem["IncreaseMinRangeAction"]==nil) then
		keypressmem["IncreaseMinRangeAction"]=true
		for k,unitID in pairs(GetSelectedUnits()) do
			if  not (autoLltStack[unitID]==nil) then
				autoLltStack[unitID]:increaseMinRange()
			end
		end
	end
end

function widget:DecreaseMinRangeAction()
	if (keypressmem["DecreaseMinRangeAction"]==nil) then
		keypressmem["DecreaseMinRangeAction"]=true
		for k,unitID in pairs(GetSelectedUnits()) do
			if  not (autoLltStack[unitID]==nil) then
				autoLltStack[unitID]:decreaseMinRange()
			end
		end
	end
end

function widget:ToggleClockwiseAction()
	if (keypressmem["ToggleClockwiseAction"]==nil) then
		keypressmem["ToggleClockwiseAction"]=true
		for k,unitID in pairs(GetSelectedUnits()) do
			if  not (autoLltStack[unitID]==nil) then
				autoLltStack[unitID]:changeRotationWay()
			end
		end
	end
end

function widget:AddLltAction()
	if (keypressmem["AddLltAction"]==nil) then
		keypressmem["AddLltAction"]=true
		for k,unitID in pairs(GetSelectedUnits()) do
			if  not (autoLltStack[unitID]==nil) then
				if (autoLltStack[unitID].partyMode==true) then
					autoLltStack[unitID]:unset()
				else
					autoLltStack[unitID].partyMode=true
				end
			end
		end
	end
end

function widget:StartDrawModeAction()
	if (keypressmem["StartDrawModeAction"]==nil) then
		keypressmem["StartDrawModeAction"]=true
		for k,unitID in pairs(GetSelectedUnits()) do
			if  not (autoLltStack[unitID]==nil) then
				autoLltStack[unitID]:startDrawMode()
			end
		end
	end
end

function widget:MousePress()
	if (options.show_gui.value==true) then
		local becomeOwner = false
		for k,unitID in pairs(GetSelectedUnits()) do
			if not (autoLltStack[unitID]==nil) then
				if (autoLltStack[unitID].drawMode==true) then
					becomeOwner = true
				end
			end
		end
		return becomeOwner
	end
end

function widget:MouseRelease(x, y, button)
	if (options.show_gui.value==true) then
		local becomeOwner = false
		for k,unitID in pairs(GetSelectedUnits()) do
			if not (autoLltStack[unitID]==nil) then
				if (autoLltStack[unitID].drawMode==true) then
					autoLltStack[unitID]:stopDrawMode()
					window.children[18]:SetCaption("Draw")
					becomeOwner = false
				end
			end
		end
		return becomeOwner
	end
end

function widget:TeamDied(teamID)
	if (teamID==GetMyTeamID()) then
        widgetHandler:RemoveWidget()
	end
end
---------------------Helpers---------------------
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