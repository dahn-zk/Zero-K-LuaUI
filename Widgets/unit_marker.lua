function widget:GetInfo() return {
	name    = "Unit Marker Zero-K",
	desc    = "[v1.3.10] Marks spotted buildings of interest and commander corpse.",
	author  = "Sprung",
	date    = "2015-04-11",
	license = "GNU GPL v2",
	layer   = -1,
	enabled = false,
} end

local knownUnits = {}
local unitList = {}
local locality = false
local supression = false
local markingActive = false
local usersonteam = {}

if VFS.FileExists("LuaUI/Configs/unit_marker_local.lua") then
	unitList = VFS.Include("LuaUI/Configs/unit_marker_local.lua")
else
	unitList = VFS.Include("LuaUI/Configs/unit_marker.lua")
end

local tablelength = 5
local pingtime = 30*30
local watched = {}
local watchme = {energysingu=true,staticheavyarty=true,staticnuke=true,staticantinuke=true,staticarty=true,raveparty=true,zenith=true,mahlazer=true,striderdetriment=true,striderbantha=true}
local conditional = {gunshipkrow=10*60*30, striderdante = 10*60*30, tankheavyassault=7*60*30, striderarty = 10*60*30, striderantiheavy = 10*60*30, shipcarrier = 10*60*30,subtacmissile = 10*60*30,shipheavyarty = 10*60*30,bomberheavy = 10*60*30,turretheavylaser = 2*60*30, turretriot = 2*60*30,tankheavyarty = 5*60*30}
local warntimes = {0,0.05, 0.33, 0.66, 0.8,1.0}
local watchednames = ""
for name,_ in pairs(watchme) do
	watchednames = watchednames .. UnitDefNames[name].humanName .. ", "
end
local checked = {}
watchednames = watchednames:sub(1, -3)
watchednames = watchednames .. "."
local overtime = true
local warn = false
local init = false
options_path = 'Settings/Interface/Unit Marker'
options_order = { 'enableAll', 'disableAll', 'unitslabel', 'locality','warn','overtime','tablelength'}
options = {
	enableAll = {
		type='button',
		name= "Enable All",
		desc = "Marks all listed units.",
		path = options_path .. "/Presets",
		OnChange = function ()
			for i = 1, #options_order do
				local opt = options_order[i]
				local find = string.find(opt, "_mark")
				local name = find and string.sub(opt,0,find-1)
				local ud = name and UnitDefNames[name]
				if ud then
					options[opt].value = true
				end
			end
			for unitDefID,_ in pairs(unitList) do
				unitList[unitDefID].active = true
			end
			if not markingActive then
				widgetHandler:UpdateCallIn('UnitEnteredLos')
				markingActive = true
			end
        end,
		noHotkey = true,
	},
	disableAll = {
		type='button',
		name= "Disable All",
		desc = "Mark nothing.",
		path = options_path .. "/Presets",
		OnChange = function ()
			for i = 1, #options_order do
				local opt = options_order[i]
				local find = string.find(opt, "_mark")
				local name = find and string.sub(opt,0,find-1)
				local ud = name and UnitDefNames[name]
				if ud then
					options[opt].value = false
				end
			end
			for unitDefID,_ in pairs(unitList) do
				unitList[unitDefID].active = false
			end
			if markingActive then
				widgetHandler:RemoveCallIn('UnitEnteredLos')
				markingActive = false
			end
        end,
		noHotkey = true,
	},
	
	unitslabel = {name = "unitslabel", type = 'label', value = "Individual Toggles", path = options_path},
	locality = {
		name = "Send Chat Messages",
		type  = "bool", 
		value = false, 
		OnChange = function(self)
			locality = self.value
		end, 
		noHotkey = true,
	},
	warn = {
		name = "Warn on Milestones",
		type  = "bool", 
		value = false, 
		OnChange = function(self)
			warn = self.value
		end, 
		noHotkey = true,
	},
	overtime = {
		name = "Warn time (seconds)",
		type = "number",
		value = 90,
		min = 0,
		max = 300,
		step = 5,
		simpleMode = true,
		everyMode = true,
		OnChange = function(self)
			pingtime = self.value*30; if pingtime == 0 then overtime = false end;
		end,
		noHotkey = true,
	},
	tablelength = {
		name = "Accuracy level",
		type = "number",
		value = 90,
		min = 5,
		max = 20,
		step = 1,
		simpleMode = true,
		everyMode = true,
		OnChange = function(self)
			tablelength = self.value
		end,
		noHotkey = true,
	},
}

local function Intro()
	Spring.SendCommands("say a: Super Spotter v0.77 by _Shaman enabled.")
	--Spring.SendCommands("say a: I am tracking the following units or structures: ")
	--Spring.SendCommands("say a: " .. watchednames)
	--Spring.SendCommands("say a: Please note heavy defenses are watched for 4 minutes and striders/demistriders are watched!")
	init = true
end

function widget:GameStart()
	if not init then
		Intro()
	end
end

for unitDefID,_ in pairs(unitList) do
	local ud = (not unitDefID) or UnitDefs[unitDefID]
	if ud then
		options[ud.name .. "_mark"] = {
			name = "  " .. Spring.Utilities.GetHumanName(ud) or "",
			type = 'bool',
			value = false,
			OnChange = function (self)
				unitList[unitDefID].active = self.value
				if self.value and not markingActive then
					widgetHandler:UpdateCallIn('UnitEnteredLos')
					markingActive = true
				end
			end,
			noHotkey = true,
		}
		options_order[#options_order+1] = ud.name .. "_mark"
	end
end

function widget:Initialize()
	warn = options.warn.value
	pingtime = options.overtime.value*30
	locality = options.locality.value
	tablelength = options.tablelength.value
	if pingtime == 0 then
		overtime = false
	end
	if not init then
		Intro()
	end
	if not markingActive then
		widgetHandler:RemoveCallIn("UnitEnteredLos")
	end
	if Spring.GetSpectatingState() then
		widgetHandler:RemoveCallIn("UnitEnteredLos")
		widgetHandler:RemoveCallIn("GameFrame")
		widgetHandler:RemoveCallIn("GameStart")
		widgetHandler:RemoveCallIn("RecvLuaMsg")
	elseif markingActive then
		widgetHandler:UpdateCallIn('UnitEnteredLos')
	end
end

function widget:PlayerChanged(playerID)
	widget:Initialize ()
end

function widget:TeamDied ()
	widget:Initialize ()
end

local function CalculateDelta(data)
	if #data > 1 then
		local sum = 0
		local last = 0
		local lastf = 0
		for i=1, #data do
			if i == 1 then
				last = data[i][1]
				lastf = data[i][2]
			else
				sum = sum + ((last - data[i][1])/((lastf - data[i][2])/30))
				last = data[i][1]
				lastf = data[i][2]
			end
		end
		return sum/#data
	else
		return "?"
	end
end

local function Convert(eta)
	local minutes = math.floor(eta/60)
	local seconds = eta%60
	return string.format("%02d:%02d", minutes,seconds)
end

function widget:UnitEnteredLos (unitID, teamID)
	if Spring.IsUnitAllied(unitID) or Spring.GetSpectatingState() or watched[unitID] or checked[unitID] then return end
	local x, y, z = Spring.GetUnitPosition(unitID)
	local unitDefID = Spring.GetUnitDefID (unitID)
	if not unitDefID then return end -- safety just in case
	--Spring.Echo("Spotted " .. UnitDefs[unitDefID].name .. "watched: " .. tostring(watchme[UnitDefs[unitDefID].name]))
	if (watchme[UnitDefs[unitDefID].name] or (conditional[UnitDefs[unitDefID].name] and Spring.GetGameFrame() <= conditional[UnitDefs[unitDefID].name])) and watched[unitID] == nil and select(5,Spring.GetUnitHealth(unitID)) < 1.0 then
		watched[unitID] = {unitdefid = unitDefID,lastwarn = 0, estimatedprogress = 0, x = x,y = y,z = z, name = Spring.Utilities.GetHumanName(UnitDefs[unitDefID]),progress = {[1] = {[1] = select(5,Spring.GetUnitHealth(unitID)),[2] = Spring.GetGameFrame()}}, nextlabel = Spring.GetGameFrame() + 300}
		Spring.MarkerAddPoint(x,y,z,Spring.Utilities.GetHumanName(UnitDefs[unitDefID]) .. " ( " .. string.format("%.2f",watched[unitID].progress[1][1]*100) .. "% completed)", false)
		if locality then
			Spring.SendCommands("say a: Spotted enemy " .. Spring.Utilities.GetHumanName(UnitDefs[unitDefID]) .. ". Tracking progress for estimated completion time. Update in 10 seconds.")
		end
		--Spring.SendCommands("say a: --> PLEASE KEEP VISION IN IT FOR AT LEAST TWO SECONDS FOR ETA! <--")
		return
	else
		checked[unitID] = true
	end
	if unitList[unitDefID] and unitList[unitDefID].active and ((not knownUnits[unitID]) or (knownUnits[unitID] ~= unitDefID)) then
		local markerText = unitList[unitDefID].markerText or Spring.Utilities.GetHumanName(UnitDefs[unitDefID])
		if not unitList[unitDefID].mark_each_appearance then
			knownUnits[unitID] = unitDefID
		end
		if unitList[unitDefID].show_owner then
			local _,playerID,_,isAI = Spring.GetTeamInfo(teamID, false)
			local owner_name
			if isAI then
				local _,botName,_,botType = Spring.GetAIInfo(teamID)
				owner_name = (botType or "AI") .." - " .. (botName or "unnamed")
			else
				owner_name = Spring.GetPlayerInfo(playerID, false) or "nobody"
			end

			markerText = markerText .. " (" .. owner_name .. ")"
		end
		Spring.MarkerAddPoint (x, y, z, markerText, true)
		checked[unitID] = true
	else
		checked[unitID] = true
	end
	if watched[unitID] then checked = true end
end

local function UpdateWarnTime(uid,bp)
	--Spring.Echo(tostring(uid).. "," .. tostring(bp))
	if type(bp) == "String" then
		return
	end
	for i=1, #warntimes do
		if bp >= warntimes[i] then
			watched[uid].lastwarn = warntimes[i]
		end
		if bp <= warntimes[i] and bp >= warntimes[i-1] and i > 1 then
			watched[uid].nextwarn = warntimes[i]
		end
	end
end

function widget:GameFrame(f)
	if f%30 == 0 then
		for uid,data in pairs(watched) do
			if Spring.IsPosInLos(data.x,data.y,data.z) and not Spring.ValidUnitID(uid) then
				watched[uid] = nil
				if not locality then
					Spring.MarkerErasePosition(data.x,data.y,data.z)
				end
			else
				local eta = 0
				local bp = select(5, Spring.GetUnitHealth(uid))
				if (bp and bp == 1.0) then
					--Spring.Echo("Unit completed.")
					if locality then
						Spring.SendCommands("say a: WARNING: Enemy " .. data.name .. " is now active!")
					end
					Spring.MarkerErasePosition(data.x,data.y,data.z)
					if UnitDefs[data.unitdefid].isImmobile then
						Spring.MarkerAddPoint(data.x,data.y,data.z,data.name .. " operational.",false)
					end
					watched[uid] = nil
				elseif not bp and data.estimatedprogress > 1.0 then
					if locality then
						Spring.SendCommands("say a: Caution: " .. data.name .. " is estimated to have been completed. Suggest scouting.")
					end
					Spring.MarkerErasePosition(data.x,data.y,data.z)
					Spring.MarkerAddPoint(data.x,data.y,data.z,data.name .. " potentially Completed. Suggest scouting.",false)
					watched[uid] = nil
				else
					--Spring.Echo("Updating " .. uid)
					if bp then
						table.insert(data.progress,1,{bp,f})
						if #data.progress > tablelength then
							data.progress[tablelength+1] = nil
							--Spring.Echo("Garbaged")
						end
						--Spring.Echo("table updated")
					end
					local delta = CalculateDelta(data.progress)
					--Spring.Echo("BP : " .. tostring(bp) .. "\nDelta: " .. tostring(delta) .."\nNextWarn: " .. tostring(data.nextwarn) .. "\nNextSay: " .. tostring(f-data.nextlabel) .. "\nestimatedprogress: ".. tostring(data.estimatedprogress))
					if bp == nil and delta ~= "?" then
						--Spring.Echo("Updating estimatedprogress")
						data.estimatedprogress = data.estimatedprogress + delta
					elseif bp then
						if bp > data.estimatedprogress and f-data.nextlabel >= -300 then
							data.nextlabel = f + pingtime
							UpdateWarnTime(uid,bp)
						end
						data.estimatedprogress = bp
					else
						data.estimatedprogress = "?"
					end
					if bp and delta and delta ~= "?" then
						local remaining = 1 - bp
						eta = remaining/delta
						eta = Convert(eta)
					elseif delta ~= "?" and data.estimatedprogress ~= "?" then
						local remaining = 1 - data.estimatedprogress
						eta = remaining/delta
						eta = Convert(eta)
					else
						eta = "??:??:??"
					end
					--Spring.Echo("ETA: " .. eta)
					if warn then
						if data.lastwarn == 0 then
							if bp then
								UpdateWarnTime(uid,bp)
							else
								UpdateWarnTime(uid,data.estimatedprogress)
							end
						end
						if bp then
							if bp >= data.nextwarn and (f-data.nextlabel) >= -300 then
								data.nextlabel = f + pingtime
								UpdateWarnTime(uid,bp)
								--Spring.Echo("Threshhold reached")
								if locality then
									Spring.SendCommands("say a: WARNING: Enemy " .. data.name .. " is " .. string.format("%.3f", bp*100) .. "% complete! ETA: " .. eta)
								end
							end
						else -- based on estimatedprogress
							if data.estimatedprogress >= data.nextwarn and (f-data.nextlabel) >= -300 then
								data.nextlabel = f + pingtime
								UpdateWarnTime(uid,data.estimatedprogress)
								if locality then
									Spring.SendCommands("say a: WARNING: Enemy " .. data.name .. " has been estimated to be " .. string.format("%.3f",data.estimatedprogress*100) .. "% complete! ETA: " .. eta)
								end
								Spring.MarkerErasePosition(data.x,data.y,data.z)
								Spring.MarkerAddPoint(data.x,data.y,data.z,data.name .. " (" .. string.format("%.3f",data.estimatedprogress*100) .. "% [est], ETA: " .. eta .. ", " .. string.format("%.3f",delta*100) .. "%/sec)",locality)
							end
						end
					end
					--Spring.Echo(" Next: " .. f - data.nextlabel .. "\nWarn: " .. data.nextwarn .. "\nETA: " .. eta .. "\nDelta: " .. delta)
					if overtime then
						--Spring.Echo("Checking label status")
						if f-data.nextlabel >= 0 then
							data.nextlabel = f + pingtime
							if bp and (delta ~= "?" and delta ~= 0) then
								if locality then
									Spring.SendCommands("say a: Tracking construction of enemy " .. data.name .. "(ETA: " .. eta .. ").\nCurrent progress: " .. string.format("%.3f", bp*100) .. "% complete. Currently building at an average rate of " .. string.format("%.3f",delta*100) .. "%/sec.")
								end
									Spring.MarkerErasePosition(data.x,data.y,data.z)
									Spring.MarkerAddPoint(data.x,data.y,data.z,data.name .. " -- " .. string.format("%.3f", bp*100) .. "% (ETA: " .. eta .. ", " .. string.format("%.3f",delta*100) .. "%/sec)",false)
							elseif (not bp) and delta ~= "?" and delta > 0 then
								if locality then
									Spring.SendCommands("say a: Estimating build progress of enemy " .. data.name .. "\nDelta: " .. string.format("%.3f",delta*100) .. "%/sec\nETA: " .. eta .. "\nEstimated Progress: " .. string.format("%.3f",data.estimatedprogress*100) .. "%")
								end
								Spring.MarkerErasePosition(data.x,data.y,data.z)
								Spring.MarkerAddPoint(data.x,data.y,data.z, data.name .. " -- " .. string.format("%.3f",data.estimatedprogress*100) .. "% (estimated) complete. (ETA: " .. eta .. ", " .. string.format("%.3f",delta*100) .. "%/sec" .. ")",false)
							end
						end
					end
					data.eta = eta
					data.delta = delta
				end
			end
		end
	end
end	

local glColor 			   = gl.Color
local glText			   = gl.Text
local cx,cy,cz
local ALL_UNITS            = Spring.ALL_UNITS
local GetCameraPosition    = Spring.GetCameraPosition
local GetUnitDefID         = Spring.GetUnitDefID
local glDepthMask          = gl.DepthMask
local glMultiTexCoord      = gl.MultiTexCoord
local glBeginEnd 		   = gl.BeginEnd
local glVertex			   = gl.Vertex
local GL_QUADS 			   = GL.QUADS

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
	knownUnits[unitID] = nil
	watched[unitID] = nil
	checked[unitID] = nil
end

local spGetGroundHeight = Spring.GetGroundHeight
local function IsCameraBelowMaxHeight()
	local cs = Spring.GetCameraState()
	if cs.name == "ta" then
		return cs.height < options.drawMaxHeight.value
	elseif cs.name == "ov" then
		return false
	else
		return (cs.py - spGetGroundHeight(cs.px, cs.pz)) < 3000
	end
end

local function DrawGradient(left,top,right,bottom,topclr,bottomclr)
	glColor(bottomclr)
	glVertex(left,bottom)
	glVertex(right,bottom)
	glColor(topclr)
	glVertex(right,top)
	glVertex(left,top)
end

local bar_Width = 10
local bar_Height = 3

local function DrawBar(x,y,z,bp,delta,eta,est)
	local color = {}
	local color2 = {}
	local text = ""
	local wx,wy,wz = Spring.WorldToScreenCoords(x,y,z)
	local progress = 0
	if delta == nil then
		delta = 0
	end
	if eta == nil then
		eta = "??:??"
	end
	--Spring.Echo(wx .. "," .. wy .. "," .. wz)
	if wx < 0 or wy < 0 or wz < 0 then
		return
	end
	if bp == nil then -- this is estimated progress
		color  = {[1] = 0.4, [2] = 0.4, [3] = 0.4, [4] = 1.0}
		color2 = {[1] = 0.2, [2] = 0.2, [3] = 0.2, [4] = 1.0}
		text   = "Est. Progress"
		progress = est
	else
		color  = {[1] = 0.8, [2] = 0.4, [3] = 0.4, [4] = 1.0}
		color2 = {[1] = 0.4, [2] = 0.2, [3] = 0.2, [4] = 1.0}
		text   = "Progress"
		progress = bp
	end
	local progress_pos= -bar_Width+bar_Width*2*progress-1
	
	glBeginEnd(GL_QUADS,DrawGradient,wx-bar_Width, wy+bar_Height, wx+progress_pos, wz-8,color,color2)
	glColor(1,1,1,0.6)
	glText(text .. ": " .. delta .. "/sec",wx,wy+bar_Height,wz, 4,"r")
	glText("ETA: " .. eta,wx,wy+10,wz, 8,"r")
end

function widget:DrawWorld()
	if not Spring.IsGUIHidden() then
		-- Test camera height before processing
		if not IsCameraBelowMaxHeight() then
			return false
		end

		-- Processing
		if WG.Cutscene and WG.Cutscene.IsInCutscene() then
			return
		end
		for id, data in pairs(watched) do
			local x = data.x
			local y = data.y
			local z = data.z
			local bp = select(5, Spring.GetUnitHealth(id))
			--Spring.Echo(tostring(Spring.WorldToScreenCoords(x,y,z)))
			DrawBar(x,y,z,bp,data.delta,data.eta,data.estimatedprogress)
		end
		--gl.Fog(false)
		--gl.DepthTest(true)
		glDepthMask(true)

		cx, cy, cz = GetCameraPosition()

		--// draw bars of units

		--// draw bars for features

	glDepthMask(false)

	--DrawOverlays()
	glMultiTexCoord(1,1,1,1)
	glColor(1,1,1,1)
	end
	--gl.DepthTest(false)
end