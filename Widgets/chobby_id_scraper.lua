function widget:GetInfo()
	return {
		name      = "Shaman Scrapper",
		desc      = "Scraps user info and pours it into the ADVENT database.",
		author    = "_Shaman",
		date      = "11 July 2016",
		license   = "GNU LGPL, v2.1 or later",
		layer     = -100000,
		enabled   = true  --  loaded by default?
	}
end

local users = {}
local open = io.open
local textfile = open("luaui\\scraper.txt", 'r')
if not textfile then
	local textfile,error = open("luaui\\scraper.txt",'w')
	assert(textfile,error)
	textfile:write("")
	textfile:close()
end

for line in io.lines("luaui\\scraper.txt") do
	local words = {}
	local i = 1
	line = line:gsub("#","")
	line = line:gsub("(","")
	line = line:gsub(")","")
	line = line:gsub(":flag_","")
	line = line:gsub(":","")
	for w in string.gmatch(line,"%s+") do words[i] = w; i=i+1; end -- STEAMID COUNTRY_CODE USERNAME (#LOBBYID)
	users[words[4]] = true
end
textfile:close()

local function Scraper(listener, userName)
	local userInfo = lobby:GetUser(userName)
	if userInfo and users[userInfo.accountID] == nil and userInfo.steamID then
		local textfile = open("luaui\\scraper.txt", "a")
		if userInfo.country == "??" then
			textfile:write(userInfo.steamID .. " :grey_question: " .. userName .. "(#" .. userInfo.accountID .. ")\n")
		else
			textfile:write(userInfo.steamID .. " :flag_" .. string.lower(userInfo.country) .. ": " .. userName .. "(#" .. userInfo.accountID .. ")\n")
		end
		textfile:close()
		users[userInfo.accountID] = true
	end
end

function widget:Initialize()
	VFS.Include(LUA_DIRNAME .. "widgets/chobby/headers/exports.lua", nil, VFS.RAW_FIRST)
	lobby:AddListener("OnAddUser", Scraper)
	lobby:AddListener("OnUpdateUserStatus", Scraper)
end
--local textfile = open("luaui\\scraper.txt", 'r')