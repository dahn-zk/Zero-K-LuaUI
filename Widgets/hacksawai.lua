function widget:GetInfo()
    return {
      name      = "Hacksaw AI",
      desc      = "Hacksaws ignore chaff.",
      author    = "_Shaman",
      date      = "8-1-2016",
      license   = "Unlicensed License copies will be terminated immediately.",
      layer     = 0,
      enabled   = true,
    }
end

local killtargets = {} -- targets that will already be killed by other hacksaws.
local predictdamage = {}
local hsrealrange = 0
local hs = {}
local hacksawdetectrange 
local hacksawdef
local hacksawbadtargets = {}
local mindamage = 0.8 -- percent of the damage needed to pass the bad target threshhold.
local minrange = 220 -- additional tracking range. Hacksaws have 430 range, this is added on top of it to get the tracking range. Careful not to increase this too high. Setting this to a negative number will set the hacksaws to ignore things at the edge of their range.
local forcedtargets = {
	athena = true,
	bomberriot = true,
	bomberstrike = true,
}
local forcedbadtargets = {
	planeheavyfighter = true,
}

local function GetHighestNumber(list)
	local highest = -999999999
	local highestid = 0
	for id,data in pairs(list) do
		if data.targetingvalue > highest then
			highestid = id
		end
	end
	return highestid
end

local function DistanceFormula(x1,y1,x2,y2) -- 2 dimensional distance formula
  local distance = math.sqrt((x1-x2)^2+(y1-y2)^2)
  --Spring.Echo("distance is " .. distance)
  return distance
end

local function Targeting(id,units)
	local loaded = Spring.GetUnitRulesParams(id).scriptLoaded or 2
	Spring.Echo("Loaded: " .. loaded)
	local x,y,z = Spring.GetUnitPosition(id)
	if loaded == nil then
		loaded = 2
	end
	local unitsproc = {}
	local x2,y2,z2,distance,cost
	for i=1, #units do
		health,_ = Spring.GetUnitHealth(units[i])
		cost = UnitDefs[Spring.GetUnitDefID(units[i])].metalCost
		if predictdamage[units[i]] and not (predictdamage[units[i]].damage > health) then
			health = health - predictdamage[units[i]].damage
		--elseif cost > 1500 and (predictdamage[units[i]]+(loaded*600.1))/health < 1.33 then
			--health = 1
		end
		unitsproc[units[i]] = {value = cost, targetingvalue = cost*((loaded*600.1)/health)}
		if health < loaded*600.1 then
			unitsproc[units[i]].targetingvalue = unitsproc[units[i]].targetingvalue + 400
		end
		x2,y2,z2 = Spring.GetUnitPosition(units[i])
		distance = DistanceFormula(x,z,x2,z2)
		if distance > hsrealrange then
			--Spring.Echo("distance " .. distance .. " > " .. hsrealrange)
			unitsproc[units[i]].targetingvalue = unitsproc[units[i]].targetingvalue/(1+(distance/hsrealrange))
			--Spring.Echo(units[i] .. " = " .. unitsproc[i])
		end
		--Spring.Echo("Unit ID: [" .. units[i] .. "] = " .. unitsproc[i])
	end
	return GetHighestNumber(unitsproc)
end

local function HacksawTargetAcquisition(id)
	local x,y,z = Spring.GetUnitPosition(id)
	local units = Spring.GetUnitsInCylinder(x,z,hacksawdetectrange)
	local unitsproc = {}
	local health
	local loaded = Spring.GetUnitRulesParams(id).scriptLoaded
	if loaded == nil then
		loaded = 2
	end
	local targeted
	if units and #units > 0 then
		for i=1,#units do -- First pass
			health,_ = Spring.GetUnitHealth(units[i])
			if predictdamage[units[i]] then
				health = health - predictdamage[units[i]].damage
			end
			if Spring.GetUnitAllyTeam(units[i]) ~= Spring.GetMyAllyTeamID() and not hacksawbadtargets[Spring.GetUnitDefID(units[i])] and (health ~= nil and health > 0) then
				Spring.Echo("UnitID: " .. units[i] .. "\n" .. tostring(killtargets[units[i]]))
				if not killtargets[units[i]] then
					unitsproc[#unitsproc+1] = units[i]
				end
			end
		end
		Spring.Echo("unitsproc size: " .. #unitsproc)
		if (not unitsproc) or #unitsproc == 0 then
			return
		elseif #unitsproc == 1 then
			targeted = unitsproc[1]
			--Spring.Echo("!Target Acquired: " .. hs[id]["target"])
		else
			targeted = Targeting(id,unitsproc)
		end
		hs[id]["target"] = targeted
		if predictdamage[targeted] then
			predictdamage[targeted].damage = predictdamage[targeted].damage + (600.1 * loaded)
			predictdamage[targeted]["hacksaws"][id] = true
		else
			predictdamage[targeted] = {damage = 600.1*loaded, hacksaws = {}}
			predictdamage[targeted]["hacksaws"][id] = true
		end
	end
	unitsproc,units,x,y,z,health = nil
end

local function HacksawTargetTracking(id,target)
	--Spring.Echo("Tracking " .. target .. ": ")
	local x,y,z = Spring.GetUnitPosition(id)
	local x2,y2,z2 = Spring.GetUnitPosition(target)
	local health,_ = Spring.GetUnitHealth(target)
	local queue = Spring.GetCommandQueue(id,1)
	local target = hs[id]["target"]
	if x2 == nil or y2 == nil or z2 == nil then -- probably out of LOS.. stop tracking.
		hs[id]["target"] = nil
		Spring.GiveOrderToUnit(id,CMD.STOP,{},0)
		return
	end
	--Spring.Echo("x: " .. x .. "\ny: " .. z .. "\nx2: " .. tostring(x2) .. "\ny2: " .. tostring(z2))
	if not Spring.ValidUnitID(target) or DistanceFormula(x,z,x2,z2) >= hacksawdetectrange or health <= 0 then --Target lost
		Spring.Echo("Target lost")
		hs[id]["target"] = nil
		Spring.GiveOrderToUnit(id,CMD.STOP,{},0)
		HacksawTargetAcquisition(id)
		if predictdamage[target] then
			predictdamage[target] = nil
		end
	end
	if not queue[1] or queue[1]["id"] ~= CMD.ATTACK or queue[1]["params"][1] ~= target then--not attacking, reissue the comamnd.
		Spring.GiveOrderToUnit(id,CMD.ATTACK,{target},0)
	end
end

local function UpdateTarget(id)
	if hs[id].target then
		local loaded = Spring.GetUnitRulesParams(id).scriptLoaded
		if loaded == nil then
			loaded = 2
		end
		local x,y,z = Spring.GetUnitPosition(id)
		local x2,y2,z2 = Spring.GetUnitPosition(hs[id].target)
		local units = Spring.GetUnitsInCylinder(x,z,hacksawdetectrange)
		local distance = DistanceFormula(x,z,x2,z2)
		local currenttargetvalue = UnitDefs[Spring.GetUnitDefID(hs[id].target)].metalCost
		local newtarget
		if distance > hsrealrange then
			currenttargetvalue = currenttargetvalue/(1+(hsrealrange/distance))
		end
		local unitsproc = {}
		local health
		if units and #units > 1 then
			for i=1,#units do -- First pass
				health,_ = Spring.GetUnitHealth(units[i])
				if Spring.GetUnitAllyTeam(units[i]) ~= Spring.GetMyAllyTeamID() and not hacksawbadtargets[Spring.GetUnitDefID(units[i])] then
					unitsproc[#unitsproc+1] = units[i]
				end
			end
			if (not unitsproc) or (#unitsproc <= 1) then
				return
			else
				newtarget = Targeting(id,unitsproc)
			end
			if newtarget ~= hs[id].target then
				if predictdamage[hs[id].target] then
					predictdamage[hs[id].target].damage = predictdamage[hs[id].target].damage - loaded*600.1
					predictdamage[hs[id].target]["hacksaws"][id] = nil
					Spring.GiveOrderToUnit(id,CMD.ATTACK,{newtarget},0)
				end
			end
		end
		unitsproc,units,x,y,z,health,currenttargetvalue = nil
	else
		Spring.Echo("Update failed")
	end
end

function widget:GameFrame(f)
	if hs then
		if predictdamage then
			local loaded = 0
			for id,data in pairs(predictdamage) do
				data.damage = 0
				for hacksawid,_ in pairs(data.hacksaws) do
					if Spring.ValidUnitID(hacksawid) then
						loaded = Spring.GetUnitRulesParams(hacksawid).scriptLoaded
						if loaded == nil then
							loaded = 2
						end
						data.damage = data.damage + (loaded*600.1)
					else
						data.hacksaws[hacksawid] = nil
					end
				end
			end
		end
		for id,data in pairs(hs) do
			local unitrules = Spring.GetUnitRulesParams(id)
			local loaded = Spring.GetUnitRulesParams(id).scriptLoaded
			if loaded == nil then
				loaded = 2
			end
			--for value,data in pairs(unitrules) do
				--Spring.Echo(value .. ": " .. tostring(data))
			--end
			if data.target == nil and loaded > 0 then
				--Spring.Echo("Selecting target for " .. id)
				HacksawTargetAcquisition(id)
			elseif data.target ~= nil and f%5 == 0 and loaded > 0 then -- Check if better target nearby.
				--Spring.Echo("Updating target for " .. id)
				UpdateTarget(id)
			elseif data.target ~= nil then
				--Spring.Echo("Tracking for " .. id)
				HacksawTargetTracking(id,data.target)
			end
		end
	end
end

function widget:Initialize()
	hacksawdef = UnitDefNames["turretaaclose"].id
	local hacksawweapondef = UnitDefNames["turretaaclose"].weapons[1].weaponDef
	Spring.Echo(hacksawweapondef)
	local hacksawdamage = WeaponDefs[hacksawweapondef].damages[0] * 2 -- hacksaw has two shots.
	Spring.Echo("hacksaw damage is: " .. hacksawdamage) -- should be 1200.2
	for id,data in pairs(UnitDefs) do -- build hacksaw bad targets
		if forcedtargets[data.name] == nil and (not data.isAirUnit or data.health < hacksawdamage*mindamage or data.isBuilder) or forcedbadtargets[data.name] then -- cannot be aircon,nonair,or have less than 75% of a hacksaw's burst damage.
			if data.isAirUnit then 
				Spring.Echo(data.name .. ":\nhealth check: " .. tostring(not(data.health < hacksawdamage*mindamage)) .. "\nisBuilder: " .. tostring(data.isBuilder and not data.name == "athena"))
			end
			hacksawbadtargets[id] = true
		end
	end
	Spring.Echo("Bad unitdefs:")
	for id,_ in pairs(hacksawbadtargets) do
		if UnitDefs[id].isAirUnit then
			Spring.Echo(UnitDefs[id].name)
		end
	end
	hsrealrangerange = WeaponDefs[hacksawweapondef].range
	hacksawdetectrange = WeaponDefs[hacksawweapondef].range + minrange
	local hacks = Spring.GetTeamUnitsByDefs(Spring.GetMyTeamID(),hacksawdef)
	if #hacks > 0 then
		for i=1,#hacks do
			hs[hacks[i]] = {}
			Spring.GiveOrderToUnit(hacks[i],CMD.FIRE_STATE,{0},0)
		end
		hacks = nil
	end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
    if unitTeam == Spring.GetMyTeamID() and unitDefID == hacksawdef then
       hs[unitID] = {target = nil}
       Spring.GiveOrderToUnit(unitID,CMD.FIRE_STATE,{0},0) -- turn off to prevent misfire. AI will handle it.
    end
end

function widget:UnitReverseBuilt(unitID, unitDefID, unitTeam)
	hs[unitID] = nil
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	hs[unitID] = nil
	predictdamage[unitID] = nil
end