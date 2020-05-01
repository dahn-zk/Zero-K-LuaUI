function widget:GetInfo()
	return {
		name      = "TacCom",
		desc      = "Shaman's tactical communication relay",
		author    = "_Shaman",
		date      = "5-17-2018",
		license   = "It's shiny time.",
		layer     = 32,
		enabled = false,
	}
end

local rushtime = 3*60*30

local scary = {
	amphassault = 10*60*30,
	tankheavyassault = 10*60*30,
	tankriot = 3*60*30,
	striderdetriment = "always",
	striderarty = "always",
	striderbantha = "always",
	striderdante = 30*60*15,
	striderscorpion = 30*60*15,
	athena = "always",
	striderantiheavy = "always",
	gunshipheavytrans = 3*60*30,
	energysingu = 12*60*30,
	gunshipheavyraider = 7*60*30,
	gunshipkrow = 10*60*30,
}

local selfair = false
local seenunits = {}
local seenair = false

local air = {
    planecon = true,
    planefighter = true,
    planeheavyfighter = true,
	bomberprec = true,
	bomberriot = true,
    bomberdisarm = true,
    bomberheavy = true,
    planescout = true,
}

local bigscarytracking = {}
local planelastseen = {}
local bombertracking = {}

local bombers = {
	bomberprec = true,
	bomberriot = true,
    bomberdisarm = true,
    bomberheavy = true,
}

function SendTaccomMsg(msg)
	Spring.SendCommands("say a: <TACCOM> " .. msg)
end

function widget:GameFrame(f)
	if f%30 == 0 then
		if not selfair and #Spring.GetTeamUnitsByDefs(Spring.GetMyTeamID(), UnitDefNames["factoryplane"]) > 1 then
			selfair = true
		end
	end
	if f%30*5 == 0 then
		for id,timer in pairs(bombertracking) do
			timer = timer - 5
			if timer == 0 then
				bombertracking[id] = nil
			end
		end
	end
	if f%30*5 == 75 then
		for id,timer in pairs(bigscarytracking) do
			timer = timer - 5
			if timer == 0 then
				bigscarytracking[id] = nil
			end
		end
	end
end

function widget:UnitEnteredLos(unitID, unitTeam, allyTeam, unitDefID)
	if seenunits[unitID] == nil and not Spring.AreTeamsAllied(unitTeam,Spring.GetMyTeamID()) then
		seenunits[unitID] = true
		local unitdefname = UnitDefs[Spring.GetUnitDefID(unitID)].name
		local humanname = UnitDefs[Spring.GetUnitDefID(unitID)].humanName
		if Spring.GetGameFrame() < rushtime and air[unitdefname] and not seenair then
			SendTaccomMsg("Enemy planes spotted.")
			seenair = true
		end
		if bombers[unitdefname] and selfair and bombertracking[unitID] == nil then
			local x,y,z = Spring.GetUnitPosition(unitID)
			bombertracking[unitID] = 30
			Spring.MarkerAddPoint(x,y,z,"<TACCOM> Enemy aircraft",true)
		end
		if bombers[unitdefname] and not selfair then
			local x,y,z = Spring.GetUnitPosition(unitID)
			Spring.MarkerAddPoint(x,y,z,humanname,false)
			bombertracking[unitID] = 30
		end
		if scary[unitdefname] and (scary[unitdefname] == "always" or (scary[unitdefname] ~= "always" and Spring.GetGameFrame() >= scary[unitdefname])) then
			if Spring.GetGameFrame < rushtime then
				SendTaccomMsg("Enemy " .. humanname .. " rush detected.")
			else
				SendTaccomMsg("Enemy " .. humanname .. " spotted.")
			end
			local buildprogress = select(5, Spring.GetUnitHealth(unitID))
			if (buildprogress ~= 1.0 or buildprogress == nil) and bigscarytracking[unitID] == nil then -- in progress
				local x,y,z = Spring.GetUnitPosition(unitID)
				bigscarytracking[unitID] = 30
				Spring.MarkerAddPoint(x,y,z,humanname .. " under construction (" .. buildprogress .. ")", false)
			end
		end
	end
end