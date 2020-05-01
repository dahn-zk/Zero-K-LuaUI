function widget:GetInfo()
	local version = "0.43 beta"
	return {
		name      = "Commshare: Auto Inviter v" .. version,
		desc      = "Automatically invites players to squad.",
		author    = "_Shaman",
		date      = "7-15-2018",
		license   = "OH LET IT BURN CUZ I NEED MOAR MONEY",
		layer     = -99999999,   
		enabled   = true,
	}
end


--		Config
--local friends        = false															-- do we invite our friends automatically?
--local clanmembers    = false 															-- do we invite our clanmates automatically?
local invitebyelo    = false 															-- do we attempt to merge with strongest / weaker players? **May require redesign**
local autoaccept     = false															-- do we automatically accept lower player's requests?
local automergecfg   = {ignore = {}, automerge = {}, autoaccept = {}, whitelist = {},
version = 0.4, autoinvite = ""}	-- config table. Contains ignore and automerge.
local ignoreall      = "none"
local autodefeat     = false

--		variables
local numcoms        = 0								-- Number of commanders remaining for us
local numfacs        = 0								-- Number of factories remaining for us.
local numworkers     = 0								-- Number of constructors remaining for us.
local isdead         = false							-- Are we currently dead?
local clan, friendlist, myelo, mylevel, ignorelist		-- These are used for determining merges.
local mergelist      = "" 								-- list of players to merge with.
local mergecount     = 0								-- count of the number of players we're merging with.
local allylist       = {}								-- Processed Alliance members.
local autoinvited    = false							-- have we automatically invited people?
local enabledplayers = {}		 						-- table of players who have this widget.
local candidates     = {}
local spec			 = false
local needsproc      = false
local nextspam       = -1

--		Options
options_path = 'Settings/Interface/Commshare'

options_order = {
	'autodefeated',
	'invitelevel',
	--'invitebyelo',
	--'autodefeated',
	'autoaccept',
	'ignoreall',
	'reset',
}

options = {
	invitelevel = {
		name  = "Autoinvite level",
		type  = "radioButton",
		items = {
		{name = 'Friends+Clan members',key='friends+clan'},
		{name = 'Clan members',key='clan'},
		{name = 'Friends',key='friends'},
		{name = 'Specific People',key='none'},
		},
		value = 'none', 
		OnChange = function(self)
			automergecfg.autoinvite = self.value
		end, 
		noHotkey = true,
		desc = "Automatically invites your friends to a commshare merger."
	},
	invitebyelo = {
		name  = "Invite Strongest Player",
		type  = "bool", 
		value = false, 
		OnChange = function(self)
			invitebyelo = self.value
		end, 
		noHotkey = true,
		desc = "Automatically requests a merge with the strongest player."
	},
	autodefeated = {
		name  = "Automerge When Defeated (buggy)",
		type  = "bool", 
		value = false, 
		OnChange = function(self)
			autodefeat = self.value
		end, 
		noHotkey = true,
		desc = "When you have been defeated (no com + no factory + no workers), attempt to automatically merge with the highest elo player with this widget. This option does not merge you with dead players, and tries to merge you with someone with at least a commander and a factory."
	},
	ignoreall = {
		name  = "Decline mode:",
		type  = "radioButton",
		items = {
			{name = 'All',key='all',description="Ignore all invites."},
			{name = 'Non-whitelist', key='whitelist', description="Ignore all non whitelisted players."},
			{name = 'Non-clan members', key='nonclan',description="Ignore all nonclan members."},
			{name = 'Non-friend', key='nonfriend', description="Ignore all nonfriends."},
			{name = 'Non-clan/friends', key='nonfriendclan', description="Ignore everyone who isn't your friend or in your clan."},
			{name = 'None', key='none', description="Don't ignore any invites."}
		},
		value = 'none',
		OnChange = function(self)
			ignoreall = self.value
		end, 
		noHotkey = true,
		desc = "Declines certain users based on this param."
	},
	autoaccept = {
		name = "Autoaccept level:",
		type = "radioButton",
		items = {
			{name = 'All',key='all',description="Accepts all invites. Not recommended."},
			{name = 'Clan+Friends',key='clan+friends',description="Accepts all clan/friend invites."},
			{name = 'Clan members',key='clan',description="Accepts all clan invites."},
			{name = 'Friends',key='friends',description="Accepts all friend's merges."},
			{name = 'Only specified',key='none',description="Only automerge selected players."},
		},
		value = 'none',
		OnChange = function(self)
			autoaccept = self.value
		end,
		noHotkey = true,
		desc = "Accepts certain users based on this param.",
	},
	reset = {
		name = "Reset configuration",
		type = "button",
		OnChange = function(self)
			automergecfg = {ignore = {}, automerge = {}, autoaccept = {}, whitelist = {}, version = 0.4};Spring.Echo("User requested reset.")
		end,
		noHotkey = true,
		desc = "Clears your whitelist, ignore list, automerge list and autoaccept list.",
	},
}

-- Loading tables used--
function widget:GetConfigData()
	return automergecfg
end

function widget:SetConfigData(data)
	Spring.Echo("Automerge: version is: " .. tostring(data.version))
	if data.version ~= 0.41 then
		Spring.Echo("Automerge: updating table structure.")
		data.whitelist = {}
		data.version = 0.41
		data.automerge = {}
		data.autoinvite = "none"
	end
	automergecfg = data
end

local function ProcessAllyTeam()
	local teamlist = Spring.GetTeamList(Spring.GetMyAllyTeamID())
	for i=1, #teamlist do
		local playerlist = Spring.GetPlayerList(teamlist[i])
		for j=1, #playerlist do
			local playerID, _, spec, teamID, _, _, _, _, _, playerKeys = Spring.GetPlayerInfo(playerlist[j])
			if not spec and playerlist[j] ~= Spring.GetMyPlayerID() then
				allylist[playerID] = {
				team = playerlist[j],
				elo = playerKeys.elo or 0,
				level = playerKeys.level or 0,
				clan = playerKeys.clanfull or "",
				}
				Spring.Echo("[Automerge] Proccessed: " .. playerID .. "\nElo: " .. allylist[playerID].elo .. "\nclan: " ..allylist[playerID].clan)
			end
		end
	end
end

local function ProccessCommand(str)
	local strtbl = {}
	for w in string.gmatch(str, "%S+") do
		if #strtbl < 5 then
			strtbl[#strtbl+1] = w
		else
			strtbl[5] = strtbl[5] .. " " .. w
		end
	end
	return strtbl
end

local function GetHighestElo(tab)
	local highestteamid = -1
	local highestelo = 0
	for name,data in pairs(tab) do
		if data["elo"] > highestelo then
			highestelo = data["elo"]
			highestteamid = data["team"]
		end
	end
	return highestteamid
end

function widget:GamePreload()
	Spring.SendLuaUIMsg("automerger", "a")
end

function widget:RecvLuaMsg(msg, playerID)
	local name,_ = Spring.GetPlayerInfo(playerID)
	if msg == "automerger" then
		enabledplayers[name] = playerID
		Spring.Echo("player " .. name .. " is using automerge!")
	end
	if msg == "automerge dead" then
		Spring.Echo("Got death message.")
		Spring.Echo("My response:\n isaccepting: " .. tostring(automergecfg.autoaccept[name]~= nil) .. "\nFriends pass: " .. tostring((string.find(automergecfg.autoinvite,"friends") or autoaccept == "friends" or autoaccept == "clan+friends") and friendlist:find(name)) .. "\nClan pass: " .. tostring((string.find(automergecfg.autoinvite,"clan") or autoaccept == "clan" or autoaccept == "clan+friends") and select(10, Spring.GetPlayerInfo(playerID)).clan == clan) .. "\n autoaccept: " .. tostring(autoaccept == "all" ) .. "\nOverall pass: "  .. tostring(msg == "automerge dead" and playerID ~= Spring.GetMyPlayerID() and (automergecfg.autoaccept[name] or ((string.find(automergecfg.autoinvite,"friends") or autoaccept == "friends" or autoaccept == "clan+friends") and friendlist:find(name)) or ((string.find(automergecfg.autoinvite,"clan") or autoaccept == "clan" or autoaccept == "clan+friends") and select(10, Spring.GetPlayerInfo(playerID)).clan == clan) or autoaccept == "all")))
	end
	if msg == "automerge dead" and playerID ~= Spring.GetMyPlayerID() and (automergecfg.autoaccept[name] or ((string.find(automergecfg.autoinvite,"friends") or autoaccept == "friends" or autoaccept == "clan+friends") and friendlist:find(name)) or ((string.find(automergecfg.autoinvite,"clan") or autoaccept == "clan" or autoaccept == "clan+friends") and select(10, Spring.GetPlayerInfo(playerID)).clan == clan) or autoaccept == "all") then
		Spring.Echo("Condition passed. " .. numcoms .. " coms, " .. numfacs .. " facs.")
		if (not isdead) and numcoms > 0 and numfacs > 0 then
			Spring.SendLuaUIMsg("automerge accepting","a")
		elseif not isdead and numcoms > 0 and numfacs == 0 then
			Spring.SendLuaUIMsg("automerge nonideal","a")
		elseif not isdead and numcoms == 0 and numfacs > 0 then
			Spring.SendLuaUIMsg("automerge nonideal","a")
		end
	end
	if msg == "automerge accepting" then
		candidates[name] = 2
	elseif msg == "automerge nonideal" then
		candidates[name] = 1
	elseif msg == "autoinvite " .. Spring.GetMyPlayerID() and (automergecfg.autoaccept[name] or ((string.find(automergecfg.autoinvite,"friends") or autoaccept == "friends") and friendlist:find(name)) or ((string.find(automergecfg.autoinvite,"clan") or autoaccept == "clan") and select(10, Spring.GetPlayerInfo(playerID)).clan == clan) or autoaccept == "all") then
		Spring.SendLuaRulesMsg("sharemode invite " .. playerID)
		Spring.Echo("Got valid autoinvite msg. Sending.")
	end
end

function widget:Initialize()
	_,_,spec,_ = Spring.GetPlayerInfo(Spring.GetMyPlayerID())
	Spring.Echo("[Automerge] Checking users")
	if spec then
		autoinvited = true -- turn off the widget's functions, but don't remove the widget so user can mess with settings.
		return
	end
	if Spring.GetGameFrame() > 0 then
		ProcessUnits()
	end
	local playerlist = Spring.GetPlayerList(Spring.GetMyTeamID())
	local currentsquad = ""
	if #playerlist > 1 then
		for i=1, #playerlist do
			currentsquad = currentsquad .. select(1,Spring.GetPlayerInfo(playerlist[i])) .. " "
		end
	end
	local customkeys = select(10, Spring.GetPlayerInfo(Spring.GetMyPlayerID()))
	clan = customkeys["clanfull"] -- the full name of your clan.
	friendlist = customkeys["friends"] -- your friends list.
	myelo = customkeys["elo"] -- your elo.
	ignorelist = customkeys["ignored"] -- your ignore list. We automatically ignore requests from these users.
	mylevel = customkeys["level"] -- your level.
	Spring.Echo("[Automerge] Details: \nMyElo: " .. myelo .. "\nignorelist: " .. ignorelist .. "\nclan: " .. clan .. "\nFriends: " .. friendlist)
	ProcessAllyTeam()
	Spring.Echo("Automerge: Determing merge list. Config:\nClan: " .. tostring(string.find(automergecfg.autoinvite,"clan") ~= nil) .. "\nfriends: " .. tostring(string.find(automergecfg.autoinvite,"friends") ~= nil))
	for name, data in pairs(allylist) do
		if automergecfg.automerge[name] or (string.find(automergecfg.autoinvite,"friends") and friendlist[name]) or (string.find(automergecfg.autoinvite,"clan") and data.clan == clan) then
			if ((ignoreall == "whitelist" and automerge.cfg.whitelist[name]) or ignoreall ~= "whitelist") and not currentsquad:find(name) then
				mergelist = mergelist .. " " .. name -- clever way of working around table creation.
				mergecount = mergecount + 1
			end
		end
	end
	Spring.Echo("Got mergelist: " .. mergelist)
end

function ProcessUnits()
	local myunits = Spring.GetTeamUnits(Spring.GetMyTeamID())
	local unitdef
	for i=1,#myunits do
		unitdef = UnitDefs[Spring.GetUnitDefID(myunits[i])]
		if unitdef.isFactory then
			numfacs = numfacs+1
		end
		if unitdef.isMobileBuilder then
			numworkers = numworkers+1
		end
		if unitdef.customParams.level or unitdef.customParams.dynamic_comm or unitdef.customParams.commtype then
			numcoms = numcoms +1
		end
	end
	if numfacs > 0 or numcoms > 0 or numworkers > 0 then
		isdead = false
	end
end

function widget:TextCommand(msg)
	if msg:find("automerge") then
		local command = ProccessCommand(msg)
		if command[2] == nil then
			Spring.Echo("Automerge: Invalid command.")
			return
		end
		if command[2] == "ignore" then
			if command[3] == "add" and command[4] and command[4] ~= "" then
				Spring.Echo("game_message: ignoring invites from " .. command[4] .. ".")
				if command[5] == nil or command[5] == "" then
					local randomnum = math.random(1,5)
					if randomnum == 1 then
						command[5] = "Reasons"
					elseif randomnum == 2 then
						command[5] = "You're too ugly"
					elseif randomnum == 3 then
						command[5] = "Don't know"
					elseif randomnum == 4 then
						command[5] = "Wubwub"
					else
						command[5] = "Lobster"
					end
				end
				automergecfg.ignore[command[4]] = command[5]
				automergecfg.automerge[command[4]] = nil
			elseif command[3] == "remove" and command[4] and command[4] ~= "" then
				if automergecfg.ignore[command[4]] then
					automergecfg.ignore[command[4]] = nil
					Spring.Echo("game_message: You are no longer ignoring " .. command[4] .. ".")
				else
					Spring.Echo("game_message: You aren't ignoring " .. command[4] .. "'s requests.")
				end
			elseif command[3] == "list" then
				local ignorelist = ""
				local count = 0
				for name,reason in pairs(automergecfg.ignore) do
					ignorelist = ignorelist .. name .. ": " .. reason .. "\n"
					count = count+1
				end
				if count > 1 then
					Spring.Echo("game_message: You are ignoring " .. count .. " users' requests:\n" .. ignorelist)
				elseif count == 1 then
					Spring.Echo("game_message: You are ignoring " .. count .. " user's request:\n" .. ignorelist)
				else
					Spring.Echo("game_message: You aren't ignoring any user's request.")
				end
			end
		elseif command[2] == "add" then
			if command[3] and command[3] ~= "" then
				if automergecfg.ignore[command[3]] or ignorelist:find(command[3]) then
					Spring.Echo("game_message: Remove " .. command[3] .. " from your ignore list first.")
				end
				automergecfg.automerge[command[3]] = true
				Spring.Echo("game_message:Added " .. command[3] .. " to automerge.")
			else
				Spring.Echo("game_message: Invalid param for add.")
			end
		elseif command[2] == "remove" then
			if command[3] and command[3] ~= "" then
				automergecfg.automerge[command[3]] = nil
				Spring.Echo("game_message:Removed " .. command[3] .. " from automerge.")
			else
				Spring.Echo("game_message: Invalid param for remove.")
			end
		elseif command[2] == "list" then
			local ignorelist = ""
			local count = 0
			for id,_ in pairs(automergecfg.automerge) do
				if count == 0 then
					ignorelist = ignorelist .. id
				else
					ignorelist = ignorelist .. ", " 
				end
				count = count+1
			end
			if count > 1 then
				Spring.Echo("game_message: You are automerging with " .. count .. " users:\n" .. ignorelist)
			elseif count == 1 then
				Spring.Echo("game_message: You are automerging with " .. count .. " user:\n" .. ignorelist)
			else
				Spring.Echo("game_message: You aren't automerging with anyone.")
			end
		elseif command[2] == "autoaccept" then
			if command[3] then
				if command[3] == "add" and command[4] then
					automergecfg.autoaccept[command[4]] = true
					Spring.Echo("game_message: Autoaccepting invites from " .. command[4] .. ".")
				elseif command[3] == "remove" and command[4] then
					if automergecfg.autoaccept[command[4]] then
						automergecfg.autoaccept[command[4]] = nil
						Spring.Echo("game_message: You are no longer autoaccepting invites from " .. command[4] .. ".")
					else
						Spring.Echo("game_message: You aren't autoaccepting " .. command[4] .. "'s requests.")
					end
				elseif command[3] == "list" then
					-- list the stuff here.
				end
			end
		elseif command[2] == "whitelist" then
			if command[3] and command[3] == "add" and command[4] then
				Spring.Echo("game_message: Added " .. command[4] .. " to whitelist.")
				automergecfg.whitelist[command[4]] = true
				automergecfg.whitelist[command[4]] = true
			elseif command[3] and command[3] == "remove" and command[4] then
				Spring.Echo("game_message: Removed " .. command[4] .. " from whitelist.")
				automergecfg.whitelist[command[4]] = nil
			elseif command[3] and command[3] == "list" then
				local ignorelist = ""
				local count = 0
				for id,_ in pairs(automergecfg.whitelist) do
					if count == 0 then
						ignorelist = ignorelist .. id
					else
						ignorelist = ignorelist .. ", " 
					end
					count = count+1
				end
				if count > 1 then
					Spring.Echo("game_message: You have " .. count .. " users whitelisted:\n" .. ignorelist)
				elseif count == 1 then
					Spring.Echo("game_message: You have " .. count .. " user whitelisted:\n" .. ignorelist)
				else
					Spring.Echo("game_message: You don't have anyone whitelisted.")
				end
			end
		else
			Spring.Echo("game_message: Invalid automerge command.")
		end
	end
end

function widget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	local unitdef = UnitDefs[unitDefID]
	if newTeam == Spring.GetMyTeamID() then
		if unitdef.isFactory then
			numfacs = numfacs+1
		end
		if unitdef.isMobileBuilder then
			numworkers = numworkers+1
		end
		if unitdef.customParams.level or unitdef.customParams.dynamic_comm or unitdef.customParams.commtype then
			numcoms = numcoms +1
		end
	end
	if oldTeam == Spring.GetMyTeamID() then -- I gave away a unitDefID
		if unitdef.isFactory then
			numfacs = numfacs-1
		end
		if unitdef.isMobileBuilder then
			numworkers = numworkers-1
		end
		if unitdef.customParams.level or unitdef.customParams.dynamic_comm or unitdef.customParams.commtype then
			numcoms = numcoms -1
		end
	end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if unitTeam == Spring.GetMyTeamID() then
		local unitdef = UnitDefs[unitDefID]
		if unitdef.isFactory then
			numfacs = numfacs+1
		end
		if unitdef.isMobileBuilder then
			numworkers = numworkers+1
		end
		if unitdef.customParams.level or unitdef.customParams.dynamic_comm or unitdef.customParams.commtype then
			numcoms = numcoms +1
		end
	end
end

function widget:UnitReverseBuilt(unitID, unitDefID, unitTeam)
	if unitTeam == Spring.GetMyTeamID() then
		local unitdef = UnitDefs[unitDefID]
		if unitdef.isFactory then
			numfacs = numfacs-1
		end
		if unitdef.isMobileBuilder then
			numworkers = numworkers-1
		end
		if unitdef.customParams.level or unitdef.customParams.dynamic_comm or unitdef.customParams.commtype then
			numcoms = numcoms -1
		end
	end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
	if unitTeam == Spring.GetMyTeamID() then
		local unitdef = UnitDefs[unitDefID]
		if unitdef.isFactory then
			numfacs = numfacs-1
		end
		if unitdef.isMobileBuilder then
			numworkers = numworkers-1
		end
		if unitdef.customParams.level or unitdef.customParams.dynamic_comm or unitdef.customParams.commtype then
			numcoms = numcoms -1
		end
	end
end

function widget:GameFrame(f)
	if spec then
		return
	end
	--if f%60 == 0 then
		--Spring.Echo("Automerge debug:\n Constructors: " .. numworkers .. "\nCommanders: " .. numcoms .. "\nFactories: " .. numfacs)
	--end
	if needsproc then
		ProcessUnits()
		needsproc = false
	end
	if autoinvited == false and f> 10 then
		autoinvited = true
		local invited = "I invited " -- list of players we've invited.
		for name,data in pairs(allylist) do
			if mergelist:find(name) then
				Spring.SendLuaRulesMsg("sharemode invite " .. data["team"])
				if enabledplayers[name] == nil then
					invited = invited .. name .. ","
				end
			end
		end
		if invited ~= "I invited " then
			invited = invited:sub(1, -2)
			Spring.SendCommands("say a:" .. invited .. " to join my squad.")
		end
		if invitebyelo then
			local highestplayer = GetHighestElo(playerlistprocessed)
			if highestplayer == Spring.GetMyTeamID() then
				for name,data in pairs(enabledplayers) do
					if automergecfg.ignore[name] == nil and not ignorelist:find(name) then
						Spring.SendLuaRulesMsg("sharemode invite " .. data["team"])
					end
				end
			end
		end
	end
	if autodefeat and f%20 == 6 then
		if not isdead and numcoms == 0 and numworkers == 0 and numfacs == 0 then
			isdead = true
			Spring.Echo("Automerge: User is dead!")
		end
		if f > nextspam and isdead then
			Spring.Echo("Sent dead message.")
			Spring.SendLuaUIMsg("automerge dead","a")
			candidates = {}
		end
	end
	if autodefeat and f%20 == 12 and isdead and (numcoms > 0 or numworkers > 0 or numfacs > 0) then
		isdead = false
		Spring.Echo("Automerge: User revived.")
	end
	if autodefeat and f%20 == 13 and isdead and numcoms == 0 and numworkers == 0 and numfacs == 0 and f > nextspam then
		local players = {}
		local hasgoodplayers = false
		for name,value in pairs(candidates) do
			if value == 2 then -- prioritize putting us with someone in a okay position
				players[#players+1] = name
				hasgoodplayers = true
			end
		end
		if not hasgoodplayers then
			for name, value in pairs(candidates) do
				players[#players+1] = name
			end
		end
		Spring.Echo("isDead: Num of players: " .. #players)
		if #players == 1 then
			Spring.SendLuaUIMsg("autoinvite " .. allylist[players[1]].team)
			Spring.Echo("isDead: sent autoinvite")
			nextspam = f + 1800 -- try again in a minute.
		elseif #players > 1 then
			candidates = {}
			local name = ""
			for i=1,#players do
				name = players[i]
				candidates[name] = {elo=allylist[name].elo, team=allylist[name].team}
			end
			Spring.SendLuaUIMsg("autoinvite " .. GetHighestElo(candidates))
			Spring.Echo("isDead: sent autoinvite to " .. GetHighestElo(candidates))
		elseif f > nextspam then
			Spring.SendCommands("say a:Need constructor or factory!")
			Spring.Echo("No players got. Sad")
		end
		nextspam = f + 1800 -- try again in a minute.
	end
	if f%20 == 0 then
		local invitecount = Spring.GetPlayerRulesParam(Spring.GetMyPlayerID(), "commshare_invitecount") or 0
		if invitecount > 0 then
			for i=1, invitecount do
				local id = Spring.GetPlayerRulesParam(Spring.GetMyPlayerID(), "commshare_invite_" .. i .. "_id")
				local name,_ = Spring.GetPlayerInfo(id)
				local clanname = select(10,Spring.GetPlayerInfo(id)).clanfull
				Spring.Echo("Invite ID: " .. id .. " (" .. name .. ", member of " ..  clan .. ")")
				if clanname == nil then clanname = "" end
				if id == Spring.GetMyPlayerID() then
					return
				end
				if ((candidates[name] and autodefeat) or automergecfg.autoaccept[name] or ((autoaccept == "friends" or autoaccept == "clan+friends") and friendlist:find(name)) or autoaccept=="all" or ((autoaccept == "clan" or autoaccept == "clan+friends") and clanname == clan)) and ignoreall ~= "all" and ignorelist:find(name) == nil and automergecfg.ignore[name] == nil then
					Spring.SendLuaRulesMsg("sharemode accept " .. id)
					needsproc = true
				elseif automergecfg.ignore[name] or string.find(ignorelist,name) or ((ignoreall == "nonfriend" or ignoreall == "nonfriendclan") and not friendlist:find(name)) or ((ignoreall == "nonclan" or ignoreall == "nonfriendclan") and clan ~= allylist[name].clan) or (ignoreall== "whitelisted" and automergecfg.whitelist[name] == nil) then
					Spring.SendLuaRulesMsg("sharemode decline " .. id)
					local reason = ""
					if string.find(ignorelist,name) then
						reason = "You are ignored by this user."
					end
					if reason == "" and ignoreall == "whitelist" and automergecfg.whitelist[name] == nil then
						reason = "You need to be whitelisted by this user."
					end
					if reason == "" and automergecfg.ignore[name] ~= nil then
						reason = automergecfg.ignore[name]
						Spring.Echo("ignored!")
					end
					if reason == "" and ignoreall ~= "none" and ignoreall ~= "all" then
						reason = "Not interested in random invites."
					elseif reason == "" then
						reason = "Not interested in commshare."
					end
					Spring.SendCommands("w " .. name .. " is not interested in merging with you. Reason: " .. reason)
				end
			end
		end
	end
end