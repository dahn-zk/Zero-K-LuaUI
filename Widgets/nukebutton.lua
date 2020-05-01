function widget:GetInfo()
	local version = "0.5 beta"
	return {
		name      = "Nuclear Subsystem " .. version,
		desc      = "New SHINY Nuclear button, shiny! Don't you wish you were SHINY?!",
		author    = "_Shaman",
		date      = "5-17-2018",
		license   = "It's shiny time.",
		layer     = 32,
		enabled   = true,
	}
end

local numready = 0
local launched = {}
local lastlaunch = 0
local launchednukes = 0
local empty = {}
local attackhere = {0,0,0}
local nuclearmissileready = 'luaui/sounds/TAdUpd07.ogg' -- nuclear launch detected
local nuclearlaunch = 'luaui/sounds/TAdUpd04.ogg' -- nuclear missile ready
local nukeground = 'LUAUI/images/nukecircle.png'
local nukeready = 'LUAUI/images/nukebutton.png' 
local nukes = {} -- {unitID = {stockpiled = #, buildpercent = .##}
local nukesready = {} -- {unitID = true}. used for the nuke button
local mode = false -- controls whether we draw the nuke circle or not. Also controls if we're aiming our nuke.
local rot = 0 -- the rotation of the texture we use to designate nuke
local Chili,Screen0,Window, nukeWindow,nukebutton2, nuketooltip, nuketooltip2,nukebuttonnotready, progressBar
local totalnukes = 0
local totallaunchers = 0
local launchersready = {}
local launcherstoprime = {}
local launcherslaunched = {}
local lastplayed = 0
local markers = {}
local updateperiod = 30
local alliedlaunchers = {}
local internal = {closestprogress = -1,}

local function GetPercent(percent,numPlaces)
	return string.format("%." .. (numPlaces or 0) .. "f", percent*100)
end

local function LaunchNuke(locx,locz,locy)
	Spring.MarkerAddPoint(locx,locz,locy,"Nuclear strike inbound", false)
	local launcherID,higheststockpile = 0
	Spring.GiveOrderToUnit(nukesready[1], CMD.ATTACK, {locx,locz,locy},0)
	launchersready[nukesready[1]] = nil
	launcherslaunched[nukesready[1]] = Spring.GetGameFrame() + 420
	table.remove(nukesready,1)
	totalnukes = totalnukes - 1
	markers[#markers+1] = {x = locx, z = locz, y = locy, frame = Spring.GetGameFrame() + 600} -- set this marker to be erased after 20 seconds.
	Spring.SendLuaUIMsg("launched nuke","a")
end

local function LaunchHotkey()
	local x,y = Spring.GetMouseState()
	local _,pos = Spring.TraceScreenRay(x,y,true)
	if #nukesready > 0 then
		LaunchNuke(pos[1],pos[2],pos[3])
	else
		Spring.Echo("game_message: You have no avaliable nukes!")
	end
end

local function ButtonSelect()
	mode = true
end

local function FramesToTime(f)
	local totaltime = math.ceil(f/30) -- in seconds
	local framesleft = f%30
	local minutes = math.floor(totaltime/60)
	local seconds = totaltime%60
	if seconds < 10 then
		seconds = "0" .. seconds
	end
	return tostring(minutes) .. ":" .. seconds
end

function widget:MousePress(x, y, button)
	--Spring.Echo(x,y,button)
	if button == 1 and mode then
		local _,pos = Spring.TraceScreenRay(x,y,true)
		LaunchNuke(pos[1],pos[2],pos[3])
	end
	mode = false
end

function widget:UnitReverseBuilt(unitID, unitDefID, unitTeam)
	if launchersready[unitID] then
		table.remove(nukesready,launchersready[unitID])
		totallaunchers = totallaunchers - 1
		totalnukes = totalnukes - nukes[unitID].stockpile
	end
	nukes[unitID] = nil
	launchersready[unitID] = nil
	launcherslaunched[unitID] = nil
	launcherstoprime[unitID] = nil
	alliedlaunchers[unitID] = nil
end

function widget:UnitDestroyed(unitID)
	if launchersready[unitID] then
		table.remove(nukesready, launchersready[unitID])
		launchersready[unitID] = nil
	end
	if nukes[unitID] then
		totallaunchers = totallaunchers - 1
	end
	launcherslaunched[unitID] = nil
	nukes[unitID] = nil
	launcherstoprime[unitID] = nil
	alliedlaunchers[unitID] = nil
end

function widget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	if oldTeam == Spring.GetMyTeamID() then
		if launchersready[unitID] then
			table.remove(nukesready,launchersready[unitID])
		end
		if nukes[unitID] then
			totallaunchers = totallaunchers - 1
		end
		nukes[unitID] = nil
		launcherslaunched[unitID] = nil
		launchersready[unitID] = nil
		launcherstoprime[unitID] = nil
		alliedlaunchers[unitID] = {currentorders = "none",oldorder = "none"}
	end
	if newTeam == Spring.GetMyTeamID() then
		if unitDefID == UnitDefNames["staticnuke"] then
			alliedlaunchers[unitID] = nil
			local stock,_,buildp = Spring.GetUnitStockpile(unitID)
			nukes[unitID] = {stockpile = stock, build = buildp, buildchange = 0}
			totallaunchers = totallaunchers + 1
			totalnukes = totalnukes + stock
			if stock > 0 then
				launchersready[unitID] = #nukesready+1
				nukesready[#nukesready+1] = unitID
				launcherstoprime[unitID] = 0
			end
		end
	end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if unitTeam == Spring.GetMyTeamID() then
		if unitDefID == UnitDefNames["staticnuke"].id then
			Spring.PlaySoundFile('luaui/sounds/TAdUpd03.wav',1)
			Spring.Echo("Launcher finished: " .. unitID)
			nukes[unitID] = {stockpile = 0, buildp = 0, buildchange = 0}
			totallaunchers = totallaunchers + 1
		end
	end
end

function widget:Initialize()
	if (Spring.GetSpectatingState() or Spring.IsReplay()) and (not Spring.IsCheatingEnabled()) then
		widgetHandler:RemoveWidget()
	end
	Spring.PlaySoundFile('luaui/sounds/TAdUpd03.wav',1)
	Chili = WG.Chili
    Screen0 = Chili.Screen0
	
	nukeWindow = Chili.Window:New{parent=Screen0, width='8.5%',height='12%',x='90%',y='30%',resizable=false,draggable=true,dockable=true}
	Chili.Line:New{parent=nukeWindow,x="0%",y="10%",width="100%",height="5%"}
	Chili.TextBox:New{parent=nukeWindow,x="10%",y="2.5%",width="100%",height="5%",text="Support Powers",fontSize=15}
	nukebutton = Chili.Image:New{parent=nukeWindow,width ='95%',height='52.5%',x='2.5%',y='20%',OnClick={function () ButtonSelect() ;end},tooltip="Press this button to launch a nuke.",file=nukeready,KeepAspect=false}
	nuketooltip2 = Chili.TextBox:New{parent=nukebutton,width = '80%', height='20%',x='10%',y='20%',text="?", fontSize = 30, color={153/255,0,0,1}}
	progressBar = Chili.Progressbar:New{parent=nukeWindow,min=0,max=100,caption="ETA: ?:??",height='20%',width='100%',x='0%',y='80%',color={0,1,0,1}}
	if Spring.GetGameFrame() > 0 then
		local mynukes = Spring.GetTeamUnitsByDefs(Spring.GetMyTeamID(), UnitDefNames["staticnuke"].id)
		local stock, build
		if #mynukes == 0 then
			nukeWindow:Hide()
		end
		for i=1,#mynukes do
			stock,_ = Spring.GetUnitStockpile(mynukes[i])
			totalnukes = totalnukes + stock
			local buildPercent = Spring.GetUnitRulesParam(mynukes[i],"gadgetStockpile")
			--Spring.Echo(mynukes[i] .. ":\nstock: " .. stock .. "\nbuild progress: " .. buildPercent)
			nukes[mynukes[i]] = {stockpile = stock, buildp = buildPercent, buildchange = 0}
			if stock > 1 then
				--launcherstoprime[mynukes[i]] = 0
				launchersready[mynukes[i]] = true
				nukesready[#nukesready+1] = mynukes[i]
			end --This code is dangerous to CHINA.
		end
		totallaunchers = #mynukes
		if totalnukes == 0 then
			nuketooltip2:Hide()
		else
			nuketooltip2:SetText(totalnukes)
		end
	end
end

local function CheckIfAllied()
	for id,data in pairs(alliedlaunchers) do
		if data.oldorder == "attack" and data.neworder == "none" then
			return true
		elseif data.oldorder == "attack" and data.neworder == "attack" then -- suspicious, but probably ours.
			return true
		end
	end
	for id,data in pairs(launcherslaunched) do
		if data > Spring.GetGameFrame() then
			return true
		end
	end
	return false
end

--[[local function Draw()
	local debug = ""
	local ct = internal.coordtable
	gl.PushMatrix()
	gl.Texture(false)
	gl.DepthTest(true)
	gl.Vertex((internal.x2-internal.x1)/2, (internal.y2-internal.y1)/2)
	for i=1, #ct do
		gl.Vertex(ct[i][1],ct[i][2])
	end
	gl.DepthTest(false)
	
	gl.PopMatrix()
end]]

local function DrawButton() -- Draws the progress shader over the button. Hopefully
	--[[local progress = internal.closestprogress
	if totalnukes > 0 or totallaunchers == 0 or progress == -1 then
		return
	end
	internal["x1"] = nukebutton.x + nukeWindow.x
	internal["y1"] = nukebutton.y + nukeWindow.y
	internal["x2"] = internal.x1 + nukebutton.width
	internal["y2"] = internal.y1 + nukebutton.height -- end point
	local x1 = internal["x1"]
	local y1 = internal["y1"]
	local x2 = internal["x2"]
	local y2 = internal["y2"]
	local midx = (internal.x2-internal.x1)/2 -- mid of x?
	local midy = (internal.y2-internal.y1)/2
	Spring.Echo(x1,y1,x2,y2,midx,midy)
	internal.coordtable = {{midx,y1}} -- 0%
	if progress < 7/8 then
		internal.coordtable[#internal.coordtable+1] = {x1,y1}
		--Spring.Echo("7/8")
	end
	if progress < 3/4 then
		internal.coordtable[#internal.coordtable+1] = {x1,midy}
		--Spring.Echo("6/8")
	end
	if progress < 5/8 then
		internal.coordtable[#internal.coordtable+1] = {x2,y1}
		--Spring.Echo("5/8")
	end
	if progress < 1/2 then
		internal.coordtable[#internal.coordtable+1] = {x2,midy}
		--Spring.Echo("4/8")
	end
	if progress < 3/8 then
		internal.coordtable[#internal.coordtable+1] = {x2,y2}
		--Spring.Echo("3/8")
	end
	if progress < 1/4 then
		internal.coordtable[#internal.coordtable+1] = {x2,midy}
		--Spring.Echo("2/8")
	end
	if progress < 1/8 then
		internal.coordtable[#internal.coordtable+1] = {x2,y1}
		--Spring.Echo("1/8")
	end
	-- Progress Point --
	if progress < 1/8 and progress > 0 then
		local distance = x2 - midx 
		local lineprogress = progress/(1/8)
		internal.coordtable[#internal.coordtable+1] = {midx+(distance*lineprogress),y1}
		--Spring.Echo("1/8: got " .. internal.coordtable[#internal.coordtable][1],internal.coordtable[#internal.coordtable][2])
	elseif progress < 1/4 and progress > 1/8 then
		local distance = midy - y1
		local lineprogress = progress/(2/8)
		internal.coordtable[#internal.coordtable+1] = {x2,y1+distance*lineprogress}
		--Spring.Echo("2/8: got " .. internal.coordtable[#internal.coordtable][1],internal.coordtable[#internal.coordtable][2])
	elseif progress < 3/8 and progress > 2/8 then
		local distance = y2 - midy
		local lineprogress = progress/(3/8)
		internal.coordtable[#internal.coordtable+1] = {x2,midy+distance*lineprogress}
		--Spring.Echo("3/8: got " .. internal.coordtable[#internal.coordtable][1],internal.coordtable[#internal.coordtable][2])
	elseif progress < 1/2 and progress > 3/8 then
		local distance = x2 - midx
		local lineprogress = progress/(0.5)
		internal.coordtable[#internal.coordtable+1] = {x2-(distance*lineprogress),y2}
		--Spring.Echo("4/8: got " .. internal.coordtable[#internal.coordtable][1],internal.coordtable[#internal.coordtable][2])
	elseif progress < 5/8 and progress > 4/8 then
		local distance = midx-x1
		local lineprogress = progress/(5/8)
		internal.coordtable[#internal.coordtable+1] = {midx-(distance*lineprogress),y2}
		--Spring.Echo("5/8: got " .. internal.coordtable[#internal.coordtable][1],internal.coordtable[#internal.coordtable][2])
	elseif progress < 6/8 and progress > 5/8 then
		local distance = y2-midy
		local lineprogress = progress/(6/8)
		internal.coordtable[#internal.coordtable+1] = {x1,y2-(distance*lineprogress)}
		--Spring.Echo("6/8: got " .. internal.coordtable[#internal.coordtable][1],internal.coordtable[#internal.coordtable][2])
	elseif progress < 7/8 and progress > 6/8 then
		local distance = midy - y1
		local lineprogress = progress/(7/8)
		internal.coordtable[#internal.coordtable+1] = {x1,midy-(distance*lineprogress)}
		--Spring.Echo("7/8: got " .. internal.coordtable[#internal.coordtable][1],internal.coordtable[#internal.coordtable][2])
	elseif progress > 7/8 then
		local distance = midx - x1
		local lineprogress = progress
		internal.coordtable[#internal.coordtable+1] = {midx-(lineprogress*distance),y1}
		--Spring.Echo("8/8: got " .. internal.coordtable[#internal.coordtable][1],internal.coordtable[#internal.coordtable][2])
	end
	gl.Color(0,0,0,0.7)
	gl.BeginEnd(GL.TRIANGLE_FAN, Draw)
	gl.Color(1,1,1,1)
	--Spring.Echo(x1,y1,x2,y2)]]
end

function widget:GameFrame(f)
	for id,data in pairs(launcherstoprime) do
		if data == 0 then
			Spring.GiveOrderToUnit(id,CMD.ATTACK,attackhere,0)
			launcherstoprime[id] = f + 10
			Spring.Echo("Primed " .. id)
		elseif data == f then
			Spring.GiveOrderToUnit(id,CMD.STOP,empty,0)
			Spring.Echo("Stopping " .. id)
			launcherstoprime[id] = nil
		end
	end
	for id,data in pairs(alliedlaunchers) do
		local queue = Spring.GetCommandQueue(id,1)
		data["oldorders"] = data["neworders"] or "none"
		if queue[1] == nil then
			data["neworders"] = "none"
		elseif queue[1] == CMD.ATTACK then
			data["neworders"] = "attack"
		else
			data["neworders"] = "?"
		end
	end
	if (Spring.GetGameRulesParam("recentNukeLaunch") == 1) and f > lastlaunch then -- nuclear launch detected.
		Spring.PlaySoundFile(nuclearlaunch,1)
		lastlaunch = f + 300
		if not (CheckIfAllied()) then
			Spring.SendCommands("say a:WARNING: Enemy nuclear launch detected!")
		else
			Spring.SendCommands("say a:NOTICE: Allied launch detected.")
		end
	end
	if f%updateperiod == 0 then
		local closestbp = 0
		local ready = 0
		local total = 0
		local closestid
		for id,data in pairs(nukes) do
			local stockpile,_ = Spring.GetUnitStockpile(id)
			--Spring.Echo(stockpile)
			local build = Spring.GetUnitRulesParam(id,"gadgetStockpile")
			total = total + stockpile
			if stockpile > data["stockpile"] then
				if f > lastplayed + 20 then
					Spring.PlaySoundFile(nuclearmissileready,1)
					lastplayed = f
				end
				data["stockpile"] = stockpile
			end
			if stockpile > 0 then
				ready = ready + 1
			end
			if stockpile > 0 and launchersready[id] == nil and launcherslaunched[id] == nil then
				launchersready[id] = #nukesready+1
				nukesready[#nukesready+1] = id
				launcherstoprime[id] = 0
				--Spring.Echo("Added to nukesready: " .. id)
			end
			if data["buildp"] == nil then data["buildp"] = Spring.GetUnitRulesParam(id,"gadgetStockpile") or 0;data["buildchange"] = 0 end
			if Spring.GetUnitRulesParam(id,"gadgetStockpile") == nil then
				build = 0
			end
			data["buildchange"] = build - data["buildp"] -- multiply this by 10 to get the build rate per second
			if build > closestbp then
				closestbp = build
				internal.closestprogress = closestbp
				closestid = id
			end
			data["buildp"] = build
		end
		numready = ready
		for id,frame in pairs(launcherslaunched) do
			if f > frame then
				launcherslaunched[id] = nil
			end
		end
		totalnukes = total -- update total.
		local timeleft = "?:??"
		-- update tooltips --
		if closestid ~= nil and nukes[closestid].buildchange == 0 then
			timeleft = "?:??" -- not being built
			Spring.Echo("No build progress!")
		elseif closestid ~= nil and closestbp == 1 then -- ready.. but skipped the cycle for some reason.
			timeleft = "0:00"
		elseif closestid ~= nil then
			timeleft = FramesToTime((1 - closestbp) / (nukes[closestid].buildchange/updateperiod))
		end
		progressBar:SetCaption("ETA: " .. timeleft .. "(" .. GetPercent(closestbp,2) .. "%)")
		progressBar:SetValue(closestbp*100)
		nuketooltip2:SetText(#nukesready)
		-- update markers --
		for id,data in pairs(markers) do
			if f > data.frame then
				Spring.MarkerErasePosition(data.x, data.z, data.y)
				table.remove(markers,i)
			end
		end
		-- update button status --
		--Spring.Echo("NumReady: " .. numready)
		if totallaunchers == 0 and nukeWindow.visible then
			nukeWindow:Hide()
			Spring.Echo("Hiding nuke panel")
		end
		if totallaunchers > 0 and not nukeWindow.visible then
			nukeWindow:Show()
			Spring.Echo("Showing nuke panel")
		end
		if numready == 0 and totalnukes == 0 then
			nuketooltip2:Hide()
		elseif numready > 0 and nuketooltip2.visible == false then
			nuketooltip2:Show()
		end
	end
end

local function UnitCircleVertices()
	for i = 1, circleDivs do
		local theta = 2 * math.pi * i / 64
		gl.Vertex(cos(theta), 0, sin(theta))
	end
end

local function DrawUnitCircle()
	gl.BeginEnd(GL_LINE_LOOP, UnitCircleVertices)
end

local function DrawCircle(x, y, z, radius)
	gl.PushMatrix()
	gl.Translate(x, y, z)
	gl.Scale(radius, radius, radius)
	--gl.CallList(circleList)
	gl.PopMatrix()
end

local function DRAWTEXT()
	local mouseX, mouseY = Spring.GetMouseState()
	local _, args = Spring.TraceScreenRay(mouseX, mouseY, true)
	local x1,y1,x2,y2,z
	if args == nil or mouseX == nil or mouseY == nil then
		return
	end
	--Spring.Echo("Mouse is at (" .. args[1] .. "," .. args[3] .. ")")
	gl.PushMatrix()
	gl.Billboard()
	for i = 1, 64 do
		--local proportion = i / (64 + 1)
		gl.Color(1, 0.2, 0.2, 1)
		DrawCircle(args[1], args[3], 1, 1920/2)
	end
	--gl.Translate(args[1],args[3],0)
	--gl.Texture("luaui/images/nukecircle.png")
	--gl.DrawGroundCircle(args[1],args[2],args[3],1920/2,60)
	--gl.Rotate(rot,0,0,0)
	gl.Color(1,1,1,1)
	gl.LineWidth(1)
	gl.PopMatrix()
	rot = rot + 1.5
	if rot > 360 then
		rot = 0
	end
end	

function widget:DrawWorld()
	if mode == true then
		DRAWTEXT()
	end
end

function widget:DrawScreen()
	DrawButton()
end

--- options ---
options_path = 'Settings/Shaman Stuff/Nukebutton'
options_order = {
	'nukeme',
}

options = {
	nukeme = {
		name  = "Nuke here!",
		type  = "button",
		OnChange = function(self)
			Spring.Echo("launching!")
			LaunchHotkey()
		end, 
		noHotkey = false,
		desc = "Launches a nuke."
	},
}

function widget:SetConfigData(data)
	return data
end

-------------------