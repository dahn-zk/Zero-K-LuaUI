function widget:GetInfo()
	return {
		name      = "All Unit Icon Overview - Control",
		desc      = "Replaces the default engine icon drawing. Conflicts with Icon Height.",
		author    = "esainane",
		date      = "2020-01-27",
		license   = "GNU GPL, v2 or later",
		layer     = 2000,
		handler   = true,
		enabled = false  --  loaded by default?
	}
end

include("keysym.h.lua")

--
-- ICON MODE SECTION
--

-- Parameters
local tolerance = 25

-- Flags and switches
local waiting_on_double
local current_mode
local target_mode
local showingicons

-- Variables
local kp_timer

-- Forward function declarations
local UpdateDynamic = function() end
local GotHotkeypress = function() end

--
-- Take/reuse same settings as Icon Height widget
--

options_path = 'Settings/Graphics/Unit Visibility'

options_order = {
	'lblIconHeight',
	'iconheight',
	'iconmodehotkey',
}

options = {

	lblIconHeight = {name='Icon Height Widget', type='label'},
	iconheight = {
		name = 'Icon Height',
		desc = 'If the camera is above this height, all units will be icons; if below, no units will be icons.\n\nOnly applies when the icon display mode is set to Dynamic.\n\nThis setting overrides Icon Distance.',
		type = 'number',
		min = 0, max = 10000,
		value = 2500,
		OnChange = function(self) WG.AllUnitIcon.iconheight = options.iconheight.value end
	},
	iconmodehotkey = {
		name = "Icon Mode Hotkey",
		desc = "Define a hotkey to switch between icon display modes (On/Off/Dynamic).\n\nSingle-press to switch between On/Off.\n\nDouble-press to switch to Dynamic.",
		type = 'button',
		OnChange = function(self) GotHotkeypress() end,
	},

}
function widget:Initialize()
	WG.AllUnitIcon.iconheight = options.iconheight.value
	Spring.SendCommands("disticon " .. 100000)
end

function widget:Shutdown()
	-- Try to restore a sane default
	-- TODO: Remember where we were?
	Spring.SendCommands("disticon " .. 50)
end

local function GetCameraHeight()
	local cs = Spring.GetCameraState()
	local gy = Spring.GetGroundHeight(cs.px, cs.pz)
	local testHeight = cs.py - gy
	if cs.name == "ov" then
		testHeight = options.iconheight.value * 2
	elseif cs.name == "ta" then
		testHeight = cs.height - gy
	end
	return testHeight
end

GotHotkeypress = function()
	if waiting_on_double then
		waiting_on_double = false
		target_mode = nil
		kp_timer = nil
		current_mode = "Dynamic"
		UpdateDynamic()
	else
		waiting_on_double = true
		kp_timer = Spring.GetTimer()
		if current_mode == "On" then target_mode = "Off"
		elseif current_mode == "Off" then target_mode = "On"
		elseif showingicons then target_mode = "Off"
		else target_mode = "On"
		end
	end
end

UpdateDynamic = function()
	local testHeight = GetCameraHeight()
	if showingicons and testHeight < options.iconheight.value - tolerance then
		showingicons = false
		WG.AllUnitIcon.showing_icons = false
	elseif not showingicons and testHeight > options.iconheight.value + tolerance then
		showingicons = true
		WG.AllUnitIcon.showing_icons = true
	end
end

local function UpdateMode()
	if not waiting_on_double and (current_mode == "On" or current_mode == "Off") then return end

	if not waiting_on_double then UpdateDynamic() -- Not waiting, Dynamic mode
	else
		-- Waiting to see if there's a double keypress
		local now_timer = Spring.GetTimer()
		if kp_timer and Spring.DiffTimers(now_timer, kp_timer) < 0.2 then return end -- keep waiting

		-- Otherwise, time's up
		if target_mode == "On" then
			showingicons = true
			WG.AllUnitIcon.showing_icons = true
			current_mode = "On"
		else
			showingicons = false
			WG.AllUnitIcon.showing_icons = false
			current_mode = "Off"
		end
		target_mode = nil
		kp_timer = nil
		waiting_on_double = nil
	end
end

function widget:GameFrame(n)
	UpdateMode()
end
