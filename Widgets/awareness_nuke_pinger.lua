VFS.Include("LuaUI/Widgets/Libs/speedups.lua")
VFS.Include("LuaUI/Widgets/Libs/math.lua")

function widget:GetInfo()
    local version = "2.0"
    return {
        name = "Missile Pinger",
        desc = "[v" .. version .. "] Battlefield Awareness: Pings allied nukes and missiles.",
        author = "_Shaman, dahn",
        date = "2020-05-12",
        license = "CC-0",
        layer = -1,
        enabled = false,
    }
end

local DRAW_LIMIT = 25 -- Spring has a limit on how many lines a widget can draw per ~15 (10? 12?) frames it seems.

local points = {}
local circlehandler = {}
local recentallied = 0
local watcheddefs = {}
local silos = {}

local EMPTY = {}

----------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------

function widget:Initialize()
    DisableForSpec()

    local nuke = VFS.Include("units/staticnuke.lua").staticnuke
    watcheddefs[UnitDefNames["staticnuke"].id] = {
        points = 60,
        radius = nuke.weaponDefs.CRBLMSSL.areaOfEffect // 2,
        type = "nuclear strike",
        life = 45,
        label_text = "nuke inc",
    }
    
    local tacnuke = VFS.Include("units/tacnuke.lua").tacnuke
    watcheddefs[UnitDefNames["tacnuke"].id] = {
        points = 16,
        radius = tacnuke.weaponDefs.WEAPON.areaOfEffect // 2,
        type = "tactical nuke",
        life = 10,
        label_text = "tacnuke inc",
    }
    
    local napalmmissile = VFS.Include("units/napalmmissile.lua").napalmmissile
    watcheddefs[UnitDefNames["napalmmissile"].id] = {
        points = 16,
        radius = napalmmissile.weaponDefs.WEAPON.areaOfEffect // 2,
        type = "napalm strike",
        life = 10,
        label_text = "napalm inc",
    }
    
    local empmissile = VFS.Include("units/empmissile.lua").empmissile
    watcheddefs[UnitDefNames["empmissile"].id] = {
        points = 16,
        radius = empmissile.weaponDefs.EMP_WEAPON.areaOfEffect,
        type = "EMP",
        life = 13,
        label_text = "emp inc",
    }
    
    local seismic = VFS.Include("units/seismic.lua").seismic
    watcheddefs[UnitDefNames["seismic"].id] = {
        points = 16,
        radius = seismic.weaponDefs.SEISMIC_WEAPON.areaOfEffect // 2,
        type = "quake",
        life = 13,
        label_text = "quake inc",
    }
end

function widget:PlayerChanged(playerID)
    DisableForSpec()
end

function DisableForSpec()
    if GetSpecState() then
        widgetHandler:RemoveWidget()
    end
end

function get_missile_radius(missile_name)

end

----------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------

local function EraseRadius(x, z, radius, points, stepnum, ending)
    local x2, y2 = 0
    local x1, y1 = 0
    local step = 360 / points
    for i = stepnum, ending do
        x1 = radius * sin(rad(i * step)) + x
        y1 = radius * cos(rad(i * step)) + z
        Spring.MarkerErasePosition(x1, Spring.GetGroundHeight(x1, y1), y1)
    end
end

local function CreateRadius(x, z, radius, points, stepnum, ending)
    local x2, y2 = 0
    local x1, y1 = 0
    local step = 360 / points
    local ox, oy = 0
    for i = stepnum, ending do
        if i == stepnum then
            x1 = radius * sin(rad(i * step)) + x
            y1 = radius * cos(rad(i * step)) + z
            if i > 1 then
                x2 = radius * sin(rad((i - 1) * step)) + x
                y2 = radius * cos(rad((i - 1) * step)) + z
            end
        else
            x2 = x1
            y2 = y1
            x1 = radius * sin(rad(i * step)) + x
            y1 = radius * cos(rad(i * step)) + z
        end
        if i > 1 then
            Spring.MarkerAddLine(x1, Spring.GetGroundHeight(x1, y1) + 700, y1, x2, Spring.GetGroundHeight(x1, y1) + 700, y2)
        end
        if i == points then
            ox = radius * sin(rad(1 * step)) + x
            oy = radius * cos(rad(1 * step)) + z
            Spring.MarkerAddLine(x1, Spring.GetGroundHeight(x1, y1) + 700, y1, ox, Spring.GetGroundHeight(x1, y1) + 700, oy)
        end
    end
end

local function GetID(x, z)
    -- Assigns an ID to a missile strike.
    local id = x + z + Spring.GetGameFrame()
    if circlehandler[id] ~= nil then
        repeat
            id = id + 1
        until circlehandler[id] == nil
    end
    return id
end

function widget:UnitDestroyed(unitID)
    silos[unitID] = nil
end

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag, bypass)
    --Spring.Echo("Got " .. unitDefID .. "\nOnList: " .. tostring(watcheddefs[unitDefID] ~= nil))
    if watcheddefs[unitDefID] and cmdID == CMD.ATTACK then
        if ((unitDefID == UnitDefNames["staticnuke"].id or unitDefID == UnitDefNames["subtacmissile"].id)
                and (select(1, Spring.GetUnitStockpile(unitID)) == 0 and type(bypass) ~= "boolean"))
                or select(5, Spring.GetUnitHealth(unitID)) < 1.0 then
            --Spring.Echo("added " .. unitID)
            silos[unitID] = { cmdParams[1], cmdParams[2], cmdParams[3] }
            return
        end
        
        local p = watcheddefs[unitDefID].points
        local type = watcheddefs[unitDefID].type
        local radius = watcheddefs[unitDefID].radius
        local life = watcheddefs[unitDefID].life
        local label_text = watcheddefs[unitDefID].label_text
        local x, y, z = 0
        if #cmdParams == 1 then
            x, y, z = Spring.GetUnitPosition(cmdParams[1])
        else
            x = cmdParams[1]
            y = cmdParams[2]
            z = cmdParams[3]
        end
        points[GetID(x, z)] = { x = x, y = y, z = z, timer = life, radius = radius, points = p }
        Spring.MarkerAddPoint(x, y, z, label_text, false)
        circlehandler[GetID(x, z)] = { x = x, z = z, points = p, current = 0, radius = radius, erase = false }
        --Spring.Echo("It's a " .. UnitDefs[unitDefID].name)
        if unitDefID == UnitDefNames["staticnuke"].id then recentallied = Spring.GetGameFrame() end
    end
end

function widget:GameFrame(f)
    if Spring.GetGameRulesParam("recentNukeLaunch") == 1 and f < recentallied - 30 then
        Spring.SendCommands("say a:[info] WARNING: Possible enemy nuke launch detected.")
    end
    for id, _ in pairs(silos) do
        --Spring.Echo("NumCommands: " .. tostring(#Spring.GetUnitCommands(id,2)))
        if ((UnitDefNames["staticnuke"].id == Spring.GetUnitDefID(id) or UnitDefNames["subtacmissile"].id) and #Spring.GetUnitCommands(id, 1) == 0) or (UnitDefNames["staticnuke"].id ~= Spring.GetUnitDefID(id) and select(5, Spring.GetUnitHealth(id))) == 1.0 then
            --Spring.Echo("Calling UnitCommand")
            widget:UnitCommand(id, Spring.GetUnitDefID(id), Spring.GetUnitTeam(id), CMD.ATTACK, silos[id], EMPTY, EMPTY, true)
            silos[id] = nil
        end
    end
    DRAW_LIMIT = 25
    if f % 30 == 0 then
        for id, data in pairs(points) do
            data.timer = data.timer - 1
            if data.timer == 0 then
                Spring.MarkerErasePosition(data.x, data.y, data.z)
                DRAW_LIMIT = DRAW_LIMIT - 1
                circlehandler[GetID(data.x, data.z)] = { x = data.x, z = data.z, points = data.points, radius = data.radius, current = 0, erase = true }
                points[id] = nil
            end
        end
    end
    if f % 10 == 0 then
        local result = 0
        for id, data in pairs(circlehandler) do
            if data.current ~= data.points then
                result = min(10, DRAW_LIMIT)
                result = min(result, data.points - data.current)
                DRAW_LIMIT = DRAW_LIMIT - result
                if not data.erase and DRAW_LIMIT > 0 then
                    CreateRadius(data.x, data.z, data.radius, data.points, data.current, data.current + result)
                    data.current = data.current + result
                elseif DRAW_LIMIT > 0 then
                    EraseRadius(data.x, data.z, data.radius, data.points, data.current, data.current + result)
                    data.current = data.current + result
                end
            else
                circlehandler[id] = nil
            end
        end
    end
end
