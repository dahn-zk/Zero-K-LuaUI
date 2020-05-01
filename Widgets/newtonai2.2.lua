function widget:GetInfo()
  local version = "Iteration 9"
  local versionnotes = "- lag compensation (adjusted for 16frame delay avg).\n- Targeting improvements (dropping untargetable units)\n - Code optimization.\n - organization\n- Target Tracking (thanks, terve!)"
  return {
      name      = "Newton AI " .. version,
      desc      = "Causes newton spires to become ungodly annoying.\n\nCurrent changes:\n" .. versionnotes,
      author    = "_Shaman",
      date      = "7-30-2016",
      license   = "Death to nonbelievers v92",
      layer     = 32,
      enabled   = true,
    }
end

-- variables --

local myteam = Spring.GetMyTeamID()
local ping = 0
local avgping = 0
local myPlayerID = 0
local pinghistory = {}
local targetinginfo = {}
local statebuffer = {}
local WeaponDef = UnitDefNames["turretimpulse"].weapons[1].weaponDef
local AlwaysAttract = {}
local AlwaysRepulse = {}
local newtons = {}
local config = {} -- NYI.
local commandbuffer = {}
local range = WeaponDefs[WeaponDef].range
local gravity = (Game.gravity/30)/-30
local debug = 0
local tolerance = 0

-- Speedups --
local GetUnitStates = Spring.GetUnitStates
local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetSpecState = Spring.GetSpectatingState
local spEcho = Spring.Echo
local GetUnitPosition = Spring.GetUnitPosition
local GetGroundHeight = Spring.GetGroundHeight
local GetGameFrame = Spring.GetGameFrame
local GetUnitDefID = Spring.GetUnitDefID
local GetNearestEnemy = Spring.GetUnitNearestEnemy
local GetUnitsInCylinder = Spring.GetUnitsInCylinder
local AreTeamsAllied = Spring.AreTeamsAllied
local GetUnitTeam = Spring.GetUnitTeam
local GetWeaponHaveFreeLoF = Spring.GetUnitWeaponHaveFreeLineOfFire
local GetUnitMass = Spring.GetUnitMass
local GetUnitVelocity = Spring.GetUnitVelocity
local ValidUnitID = Spring.ValidUnitID
local GetMyTeamID = Spring.GetMyTeamID
local GetMyPlayerID = Spring.GetMyPlayerID
local GetTeamUnitsByDefs = Spring.GetTeamUnitsByDefs
local GetPlayerInfo = Spring.GetPlayerInfo
local GetUnitWeaponVectors = Spring.GetUnitWeaponVectors
local GetUnitBuildFacing = Spring.GetUnitBuildFacing
local GetHeadingFromVector = Spring.GetHeadingFromVector
local sin = math.sin
local cos = math.cos
local atan = math.atan
local atan2 = math.atan2
local abs = math.abs
local sqrt = math.sqrt
local pi = math.pi
local max = math.max
local min = math.min
local format = string.format
local find = string.find
local rad = math.rad
local insert = table.insert


-- toolbox --
local function converttodegrees(r)
	return r * 180/pi
end

local function Echo(txt, lvl) -- Used to allow debug messages as well as speedup?
	if lvl == nil then lvl = 0 end
	if lvl <= debug then
		spEcho("[Newton AI] " .. tostring(txt))
	end
end

local function GEcho(txt, lvl) -- send text to player's console.
	if lvl <= debug then
		spEcho("game_message: [Newton AI] " .. txt)
	end
end

local function GetFacingAngle(id)
	local x,y,z = GetUnitPosition(id)
	local w1,w2,w3,w4,w5,w6 = GetUnitWeaponVectors(id, 1) -- w4, w5, w6 seem to be the proper ones? w5 is pointless though.
	local v = GetHeadingFromVector(w4,w6)
	v = v/65536*360
	if v < 0 then v = 360+v end -- convert into positive
	Echo(v,1)
	return v
end

local function DistanceFormula(x1,y1,x2,y2) -- 2 dimensional distance formula
	if x1 == nil or y1 == nil or x2 == nil or y2 == nil then
		return nil
	else
		return sqrt((x1-x2)^2+(y1-y2)^2)
	end
end

local function GetTargetHeading(id,target)
	local x,_,z = GetUnitPosition(id)
	local tx,_,tz = GetUnitPosition(target)
	if tx == nil or x == nil then return false end
	if DistanceFormula(x,z,tx,tz) <= range+(ping*5) then return false end
	local a = atan2((z-tz),(x-tx))
	a = -a + rad(270)
	px = x + (range-5)*sin(a)
	pz = z + (range-5)*cos(a)
	py = GetGroundHeight(px,pz)
	Echo(px .. "," .. py .. ", " .. pz,3)
	return a, px,py,pz
end

local function CheckHeading(id)
	if newtons[id] == -9 then return end
	local a,px,py,pz = GetTargetHeading(id,newtons[id])
	Echo(a,3)
	if a == false then return end
	local h = rad(GetFacingAngle(id))
	local tol = min((4/ping),1) * tolerance
	if h <= a-tol or h >= a+tol  then
		Echo("wrong angle: " .. px .. "," .. py .. "," .. pz,1)
		GiveOrderToUnit(id,20,{px,py,pz},{})
		--Spring.MarkerAddPoint(tx+x,GetGroundHeight(tx+x,ty+z), ty+z, "270 degrees?")
		if commandbuffer[GetGameFrame()+ping] then
			commandbuffer[GetGameFrame()+ping][id] = {id = CMD.STOP, params = 0}
		else
			commandbuffer[GetGameFrame()+ping] = {}
			commandbuffer[GetGameFrame()+ping][id] = {id = CMD.STOP, params = 0}
		end
	end
end

local function DisableForSpec()
	if GetSpecState() then
		GEcho("shutting down due to spectator.")
		widgetHandler:RemoveWidget()
	end
end

local function round2(num, idp)
	return tonumber(format("%." .. (idp or 0) .. "f", num))
end

local function GetLowestNumber(list)
	local lowest = 9999999999999999
	local lowestid = 0
	for i=1,#list do
		if list[i] and list[i] < lowest then
			lowestid = i
			lowest = list[i]
		end
	end
	return lowestid
end

local function Push(newtonid)
	local states = GetUnitStates(newtonid)
	if states and not states["active"] then
		GiveOrderToUnit(newtonid,35666,{1},0)
	end
end

local function Pull(newtonid)
	local states = GetUnitStates(newtonid)
	if states and states["active"] then
		GiveOrderToUnit(newtonid,35666,{0},0)
	end
end

local function distance3d(x1,y1,z1,x2,y2,z2)
	return sqrt(((x2-x1)*(x2-x1))+((y2-y1)*(y2-y1))+((z2-z1)*(z2-z1)))
end

local function avg(tab)
	local sum = 0
	for i=1, #tab do
		sum = sum + tab[i]
	end
	return round2(sum/#tab)
end

local function avg3(tab)
	local sum = {0,0,0}
	for i=1, #tab do
		sum[1] = sum[1] + tab[i][1]
		sum[2] = sum[2] + tab[i][2]
		sum[3] = sum[3] + tab[i][3]
	end
	return sum[1]/#tab, sum[2]/#tab, sum[3]/#tab
end

local function WillUnitHitMe(id)
	if AlwaysAttract[GetUnitDefID(newtons[id])] then return end
	if not targetinginfo[newtons[id]] then
		return
	end
	local x,y,z = GetUnitPosition(id)
	local x2,y2,z2 = GetUnitPosition(newtons[id])
	if DistanceFormula(x,z,x2,z2) > range then return end
	local v = targetinginfo[newtons[id]].velocity[1]
	local a = targetinginfo[newtons[id]].avg
	if acceleration == nil then a = {0,0,0} end
	local ty = GetGroundHeight(x2,z2)
	local mass = UnitDefs[GetUnitDefID(newtons[id])].mass
	if x2 == nil or x == nil or v == nil or mass == nil then return end
	for i=1, round2(ping*1.5,0) do
		if v[1] == nil then return end
		x2 = x2 + v[1]
		y2 = y2 + v[2]
		z2 = z2 + v[3]
		ty = GetGroundHeight(x2,z2)
		if v[2] > 0 and y2 > ty then
			v[2] = v[2] + gravity + a[2]
		end
		v[1] = v[1] + a[1]
		v[3] = v[3] + a[3]
		if distance3d(x,y,z,x2,y2,z2) < max((600*(200/mass)*(avgping*1.3))/(sqrt((y-y2)*(y-y2))),175) or v[2] > max(mass/1000,0.5) then -- DANGER CLOSE!
			if i <= ping-5 then
				Push(id)
				return
			else
				statebuffer[id] = GetGameFrame()+i
			end
		end
	end
	Pull(id)
end

local function SelectTarget(id)
	if GetNearestEnemy(id, range + (60*ping)) == nil then
		Echo(id .. ": selecttarget out", 2)
		Pull(id)
		return
	end
	local x,_,z = GetUnitPosition(id)
	local list = GetUnitsInCylinder(x,z,range + (60 * ping))
	local n = {}
	if #list == 0 then return end
	for i=1, #list do
		if not AreTeamsAllied(GetUnitTeam(list[i]),myteam) then
			local x2,_,z2 = GetUnitPosition(list[i])
			if GetWeaponHaveFreeLoF(id, 2, list[i]) or DistanceFormula(x,z,x2,z2) > range then
				n[#n+1] = list[i]
			end
		end
	end
	list = {}
	for i=1, #n do
		local x2,_,z2 = GetUnitPosition(n[i])
		local mod = 1
		local unitDefID = GetUnitDefID(n[i])
		if AlwaysAttract[unitDefID] or AlwaysRepulse[unitDefID] then 
			if not config[unitDefID].priority then 
				mod = mod*.0005
			else
				mod = priorities[config[unitDefID]]
			end
		end
		--if unitDefID and find(UnitDefs[unitDefID].name, "gunship") then mod = mod * 100 end -- gunships aren't useful to pull or push, so prioritize other things.
		local mass = GetUnitMass(n[i])
		if mass then
			if newtons[id] == n[i] then -- this is my target
				mod = mod*0.8
			end
			if DistanceFormula(x2,z2,x,z) <= range then mod = mod*(DistanceFormula(x2,z2,x,z)/range) end
			list[i] = (GetUnitMass(n[i])/UnitDefs[unitDefID].metalCost)*DistanceFormula(x2,z2,x,z) * mod
		end
	end
	if #list == 0 then
		return
	end
	newtons[id] = n[GetLowestNumber(list)]
	Echo("Targeted: " .. newtons[id], 2)
	local x2,_,z2 = GetUnitPosition(newtons[id])
	local states = GetUnitStates(id)
	local _,v,_ = GetUnitVelocity(newtons[id])
	local mass = UnitDefs[GetUnitDefID(newtons[id])].mass
	if DistanceFormula(x,z,x2,z2) > range+50 and states and states.onoff == false then Pull(id) end
	if DistanceFormula(x,z,x2,z2) > 250*(avgping/11) and states and states.onoff == false and not v > max(mass/1000,0.5) then
		Pull(id)
	elseif DistanceFormula(x,z,x2,z2) < 250*(avgping/11) and states and states.onoff == true then
		Push(id)
	end
end

local function UpdateTarget(id)
	Echo("Updating " .. id, 0)
	if newtons[id] ~= -9 and AlwaysRepulse[newtons[id]] then
		local states = GetUnitStates(id)
		if states and states["onoff"] ~= true then
			Pull(id)
		end
	end
	if newtons[id] ~= -9 and ValidUnitID(newtons[id]) then
		local vx,vy,vz = GetUnitVelocity(newtons[id])
		local x,y,z = GetUnitPosition(id)
		local x2,y2,z2 = GetUnitPosition(newtons[id])
		local distance = DistanceFormula(x,z,x2,z2)
		if distance > range + ping*30 then
			if not AlwaysRepulse[newtons[id]] and GetUnitStates(id).active ~= false then Pull(id) end
			--GiveOrderToUnit(id,CMD.STOP,{},0)
		elseif distance <= range+ping*5 then
			GiveOrderToUnit(id,CMD.ATTACK,{newtons[id]}, 0)
			WillUnitHitMe(id)
		else -- out of range.
			newtons[id] = -9
			SelectTarget(id)
		end
	else
		newtons[id] = -9
		SelectTarget(id)
	end
end

-- callins --

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if unitTeam == myteam and unitDefID == UnitDefNames["turretimpulse"].id then
		newtons[unitID] = -9 -- placeholder
		Pull(unitID)
		GiveOrderToUnit(unitID,CMD.FIRE_STATE,{0},0)
	end
end

function widget:UnitReverseBuilt(unitID, unitDefID, unitTeam)
	newtons[unitID] = nil
end

function widget:PlayerChanged(playerID)
	DisableForSpec()
end

function widget:Initialize()
	tolerance = rad(converttodegrees(WeaponDefs[WeaponDef].maxAngle))
	Echo("G: " .. gravity, 0)
	Echo("Tolerance: " .. tostring(tolerance) .. "\nrange: " .. tostring(range), 0)
	myPlayerID = GetMyPlayerID()
	DisableForSpec()
	local newtons2 = GetTeamUnitsByDefs(GetMyTeamID(),UnitDefNames["turretimpulse"].id)
	for i=1, #newtons2 do
		widget:UnitFinished(newtons2[i], UnitDefNames["turretimpulse"].id, GetMyTeamID())
	end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	newtons[unitID] = nil
end

local test = 0
function widget:GameFrame(f)
	for id,frame in pairs(statebuffer) do
		if frame == f then
			Push(id)
			statebuffer[id] = nil
		end
	end
	if f%10 == 0 then -- ping is detected 3 times a second, giving history a 33 1/3 second history. this is to smooth out collision detection.
		ping = select(6,GetPlayerInfo(myPlayerID))
		ping = round2(ping*30,0) -- convert to frames
		insert(pinghistory,1,ping) -- push into history.
		if #pinghistory > 10 then -- knock out the last table entry.
			pinghistory[11] = nil
		end
		avgping = avg(pinghistory) -- get average frame lag
		Echo("Frame: " .. f .. "\nAvgping: " .. avgping .. "\nCurrent: " .. ping, 2)
	end
	if commandbuffer[f] then
		for id,cmd in pairs(commandbuffer[f]) do
			GiveOrderToUnit(id,cmd["id"],cmd["params"],{})
		end
	end
	-- update targeting info --
	if f%2 == 0 then
		for id,_ in pairs(newtons) do
			CheckHeading(id)
		end
	end
	if f%2 ~= 0 then
		for id,target in pairs(newtons) do
			local w1,w2,w3,w4,w5,w6 = GetUnitWeaponVectors(id,1)
			if target ~= -9 then
				if targetinginfo[target] == nil then
					targetinginfo[target] = {avg={0,0,0},acceleration = {},lastupdate = f-1,velocity = {}}
				end
				if not ValidUnitID(target) then
					targetinginfo[target] = nil
				else
					if targetinginfo[target].lastupdate ~= f then
						local vx,vy,vz = GetUnitVelocity(target)
						Echo("VX: " .. tostring(vx) .. "\nVY: " .. tostring(vy) .. "\nVZ: " .. tostring(vz), 4)
						insert(targetinginfo[target].velocity,1,{vx,vy,vz})
						if #targetinginfo[target].velocity > 2 then
							local x2 = targetinginfo[target].velocity[2][1]
							local y2 = targetinginfo[target].velocity[2][2]
							local z2 = targetinginfo[target].velocity[2][1]
							if vx ~= nil and x2 ~= nil then
								insert(targetinginfo[target].acceleration,1, {vx-x2,vy-y2,vz-z2})
							end
							if targetinginfo.avg == nil then targetinginfo.avg = {0,0,0} end
							targetinginfo.avg[1],targetinginfo.avg[2],targetinginfo.avg[3] = avg3(targetinginfo[target].acceleration)
							if #targetinginfo[target].acceleration > 10 then
								targetinginfo[target].acceleration[11] = nil
							end
						end
						if #targetinginfo[target].velocity > 11 then
							targetinginfo[target].velocity[12] = nil
						end
						targetinginfo[target].lastupdate = f
					end
				end
				UpdateTarget(id)
				if f%3 == 0 then
					SelectTarget(id)
					UpdateTarget(id)
				end
			else
				SelectTarget(id)
			end
		end
	end
	if f%30 == 0 then
		if GetMyTeamID() ~= myteam then
			GEcho("Notice: Commshare detected! Reinitalizing. . .", 0)
			newtons = {}
			widget:Initialize()
			myteam = GetMyTeamID()
		end
	end
end