function widget:GetInfo()
  local version = "v3"
  return {
      name      = "No estall " .. version,
      desc      = "Increases priority of energy buildings when E<M",
      author    = "Zenfur",
      date      = "2019",
      layer     = 32,
      enabled   = true
   }
end

--include("LuaRules/Configs/customcmds.h.lua")
local CMD_PRIORITY = 34220
local helloWorld = "Estall protection enabled"
local player_id
local team_id
local energy_buildings
local metal_to_energy_ratio = 1.8
local delayed = nil

function widget:Initialize()
    player_id = Spring.GetMyPlayerID()
    team_id = Spring.GetMyTeamID()
    Spring.Echo(helloWorld .. " " .. player_id .. " " .. team_id)
    energy_buildings = {["energygeo"] = true, ["energysolar"] = true, ["energywind"] = true}
end


List = {}
function List.new ()
  return {first = 0, last = -1}
end

function List.pushleft (list, value)
  local first = list.first - 1
  list.first = first
  list[first] = value
end

function List.pushright (list, value)
  local last = list.last + 1
  list.last = last
  list[last] = value
end

function List.popleft (list)
  local first = list.first
  if first > list.last then error("list is empty") end
  local value = list[first]
  list[first] = nil        -- to allow garbage collection
  list.first = first + 1
  return value
end

function List.popright (list)
  local last = list.last
  if list.first > last then error("list is empty") end
  local value = list[last]
  list[last] = nil         -- to allow garbage collection
  list.last = last - 1
  return value
end

local delayed_commands = List.new()

 function widget:UnitCreated(uid, udefid, tid, bid) --> "unitID, unitDefID, teamID, builderID"
  	local e, _, e_p, e_i, e_e = Spring.GetTeamResources(team_id, "energy")
    local m, _, m_p, m_i, m_e = Spring.GetTeamResources(team_id, "metal")
    -- nil | number currentLevel,
    --   number storage,
    --   number pull,
    --   number income,
    --   number expense,
    --   number share,
    --   number sent,
    --   number received
  	-- Spring.Echo(Spring.GetTeamResources(team_id, "energy"))
    -- Spring.Echo(Spring.GetTeamResources(team_id, "metal"))
    -- Spring.Echo(UnitDefs[udefid].name)
    -- Spring.GetUnitRulesParam(unitID, "buildpriority" or "miscpriority")

    if uid and tid == team_id and energy_buildings[UnitDefs[udefid].name] == true then
        Spring.Echo("Detected " .. UnitDefs[udefid].name .. " E/M: " .. e_i .. " " .. m_i)
        -- Spring.Echo(Spring.GetUnitRulesParam(uid, "buildpriority")) -- does not print anything
        if e_i < m_i*metal_to_energy_ratio then
            Spring.Echo("Energy lower than metal, increasing priority")
            List.pushright(delayed_commands, {Spring.GetGameFrame()+2, uid, 2})
            -- Spring.GiveOrderToUnit(uid, CMD_PRIORITY, {2}, 0)
        else
            List.pushright(delayed_commands, {Spring.GetGameFrame()+2, uid, 1})
        end
        Spring.Echo("Inserting " .. " " .. Spring.GetGameFrame()+2 .. " " .. uid)
        -- Spring.Echo(Spring.GetUnitRulesParam(uid, "buildpriority")) -- does not print anything
    end
 end

function widget:GameFrame(f)
 if delayed_commands.first <= delayed_commands.last then
   while delayed_commands[delayed_commands.first] and delayed_commands[delayed_commands.first][1] >= f do
     local tab = List.popleft(delayed_commands)
     Spring.Echo("Popping " .. " " .. tab[1] .. " " .. tab[2] .. " priority: " .. tab[3])
     Spring.GiveOrderToUnit(tab[2], CMD_PRIORITY, {tab[3]}, 0)
   end
 end
end
