function widget:GetInfo()
	return {
		name      = "All Unit Icon Overview - Model",
		desc      = "Replaces the default engine icon drawing. Conflicts with Icon Height.",
		author    = "esainane",
		date      = "2020-01-27",
		license   = "GNU GPL, v2 or later",
		layer     = 2000,
		handler   = true,
		enabled = false  --  loaded by default?
	}
end

local icontypes = VFS.Include("LuaUI/Configs/icontypes.lua")
include("keysym.h.lua")

--
-- ICON DRAW SECTION
--

local spGetAllUnits = Spring.GetAllUnits
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetUnitIsCloaked = Spring.GetUnitIsCloaked
local spIsUnitSelected = Spring.IsUnitSelected

local frame = 0

local all_units = {}

WG.AllUnitIcon = {
	all_units = all_units,
	showing_icons = WG.AllUnitIcon and WG.AllUnitIcon.showing_icons or false
}

local function ProgressToFlashRate(progress)
	if progress >= .5 then
		if progress >= .75 then
			if progress >= .90 then
				-- 97%+ - OSHI THE STARLIGHT'S NEARLY DONE, PANIIIC
				-- If something is nearly done, we want it to be pretty clear that it's still under construction
				-- If it's an enemy unit, we need to know to deal with it imminently
				-- If it's a friendly unit, we should be aware that we don't want to leave it unfinished
				-- ...or simply that it's something we're delaying if we set priority elsewhere
				return 10.0
			else
				-- [.75,.97) - almost done, flash just faster than 1Hz, fairly insistently
				return 25.0
			end
		else
			-- [.5,.75) - something to think about soon, flash just slower than 1Hz
			return 35.0
		end
	else
		if progress >= .2 then
			-- [.2,.5) - enough invested to probably not be a decoy, flash slowly, slightly faster than 2Hz
			return 55
		else
			-- [0,.2) - whether it's half a dozen decoy fusions or some nub waiting an hour for a det, we don't care that much. 3Hz it is.
			return 90
		end
	end
end

local terraunitid = UnitDefNames["terraunit"].id
local clawid = UnitDefNames["wolverine_mine"].id

local function UpdateOneUnit(unitID)
	local udID = spGetUnitDefID(unitID)
	if udID == terraunitid then
		-- Terraform is a special snowflake which always manages to creep little bits of frost into every addon
		return
	end

	local have_old_data = true
	local data = all_units[unitID]
	if not data then
		data = {}
		have_old_data = false
	end
	--data.debug = 0

	data.udID = udID
	local ud = UnitDefs[udID]
	local isCloaked = spGetUnitIsCloaked(unitID)
	local tr, tg, tb
	if spIsUnitSelected(unitID) then
		tr, tg, tb = 1,1,1
	else
		local team = Spring.GetUnitTeam(unitID)
		if team == nil then
			tr, tg, tb = 1,0,1
		else
			tr, tg, tb = Spring.GetTeamColor(team)
		end
	end
	local health, maxHealth, _, _, buildProgress = Spring.GetUnitHealth(unitID)
	-- aimpos
	local _,_,_,wx,wy,wz = Spring.GetUnitPosition(unitID, false, true)

	-- ud is nil sometimes.
	if ud == nil then
		-- We've got a radar dot (?). Update what we can
		if not have_old_data then
			return
		end
		if wx ~= nil and wy ~= nil and wz ~= nil then
			--Spring.Echo("We still know the coordiates ", wx, wy, wz)
			--data.debug = 1
		else
			--Spring.Echo("UnitDef for unit", unitID, "unitDefID",udID,"is nil - we don't even know the coordinates! Skipping.")
			return
		end
	else
		-- We know the ud, update everything that depends on knowing ud
		local icon = icontypes[ud.iconType]
		data.icon = icon
		data.name = ud.name
	end
	if buildProgress == nil then
		--Spring.Echo('nil buildprogress for unit', ud and ud.name)
		if data.buildProgress == nil then
			data.buildProgress = 0.0
		end
	else
		data.buildProgress = buildProgress
	end
	data.pulseRate = ProgressToFlashRate(data.buildProgress)
	data.isCloaked = isCloaked
	data.wx=wx
	data.wy=wy
	data.wz=wz
	data.tr=tr
	data.tg=tg
	data.tb=tb
	data.lastUpdate = frame
	if not have_old_data then
		all_units[unitID] = data
	end
end

local one_minute = 30 * 60

local function UpdateUnits()
	-- table.clear(all_units)
	local dead = {}
	for unitID,data in pairs(all_units) do
		if spGetUnitIsDead(unitID) then
			dead[#dead + 1] = unitID
		elseif data.udID == clawid and data.lastUpdate < frame - one_minute then
			dead[#dead + 1] = unitID
		end
	end
	for _,unitID in pairs(dead) do
		all_units[unitID] = nil
	end
	for _,unitID in pairs(spGetAllUnits()) do
		-- WHY IS THE API LIKE THIS? WHY?
		if not spGetUnitIsDead(unitID) then
			UpdateOneUnit(unitID)
		end
	end
end

function widget:GameFrame(n)
	frame = n
	UpdateUnits()
end
