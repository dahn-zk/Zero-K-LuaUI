local version = "0.85"

function widget:GetInfo()
  return {
    name      = "Damage flicker",
    desc      = "Version " .. version .. ". May not be suitable for people prone to epileptic seizures. " .. 
    "Displays flashes of light at the edges of the game view in a first-person shooter style whenever a unit " .. 
    "is damaged or dies",
    author    = "Sphiloth aka. Alcur",
    date      = "Aug 22, 2012",
    license   = "BSD 3-clause with unsanctioned use aiming for profit forbidden",
    layer     = 0,
    enabled = false
  }
end

include"keysym.h.lua"

local GetWindowGeometry = Spring.GetWindowGeometry
local min = math.min

function minWindowDimension()
    local wx, wz = GetWindowGeometry()
    return min(wx, wz)
end

local death = {}
death.alt = {}

local damage = {}
damage.alt = {}





-- options begin

-- unit death options

-- colours, alternate colours and the alpha coefficient

death.red = 1
death.green = 0
death.blue = 0
death.alt.red = 0.5
death.alt.green = 0
death.alt.blue = 1
death.alpha = 0.4

-- in seconds, the duration of the effect

death.length = 1


-- how large the effect will be

death.size = 40




-- unit damage options

-- colours, alternate colours and the alpha coefficient

damage.red = 1
damage.green = 1
damage.blue = 0
damage.alt.red = -1.5
damage.alt.green = -1.5
damage.alt.blue = -1.5
damage.alpha = 0.15

-- in seconds, the duration of the effect

damage.length = 0.5


-- how large the effect will be

damage.size = 20

-- options end





local widgetName = widget:GetInfo().name

local abs = math.abs
local floor = math.floor
local pi = math.pi
local cos = math.cos
local sin = math.sin

local glColor = gl.Color
local glRect = gl.Rect

local GetUnitTeam = Spring.GetUnitTeam
local DiffTimers = Spring.DiffTimers
local GetTimer = Spring.GetTimer
local GetGameSeconds = Spring.GetGameSeconds
local GetTeamUnits = Spring.GetTeamUnits
local myTeam = Spring.GetMyTeamID()
local GetUnitDefID = Spring.GetUnitDefID
local GetUnitHealth = Spring.GetUnitHealth
local GetCameraPosition = Spring.GetCameraPosition
local GetGroundHeight = Spring.GetGroundHeight
local TraceScreenRay = Spring.TraceScreenRay
local IsUnitInView = Spring.IsUnitInView
local IsUnitIcon = Spring.IsUnitIcon
local GetUnitBasePosition = Spring.GetUnitBasePosition
local Echo = Spring.Echo

local minWindowDim

local dynamicAlpha = 1

local victim = {}
local timer = 0
local startTime

function isUnitComplete(unitID)
    local health, maxHealth, _, _, buildProgress = GetUnitHealth(unitID)
    if buildProgress == 1 and (health <= maxHealth-50 or health <= maxHealth*0.95) then             
        return true
    end
    return false
end

function isUnitInjured(unitID)
    local health, maxHealth, _, _, _ = GetUnitHealth(unitID)
    if health <= maxHealth-50 or health <= maxHealth*0.95 then             
        return true
    end
    return false
end

function resetGeometry()
    minWindowDim = minWindowDimension()
end

function initEffects()
    resetGeometry()
    dynamicAlpha = 1
end

function isVictimSuitable(victimID)

    if not IsUnitInView(victimID) and GetUnitTeam(victimID) == myTeam and 
    isUnitComplete(victimID) and isUnitInjured(victimID) then
        return true
    end
    return false
end

function lerp(startValue, endValue, pos)
    return (1-pos)*endValue + pos*startValue
end

function widget:DrawScreen()

    if startTime then

        local red, green, blue
        local wx, wz
        local effectDuration = timer - startTime
        local effectDurationPercent = effectDuration/victim.type.length
        local screendivider

        wx, wz = GetWindowGeometry()
        red = lerp(victim.type.alt.red, victim.type.red, effectDurationPercent)
        green = lerp(victim.type.alt.green, victim.type.green, effectDurationPercent)
        blue = lerp(victim.type.alt.blue, victim.type.blue, effectDurationPercent)

        dividerDelta = victim.type.size*(effectDurationPercent)^0.25
        screendivider = minWindowDim/dividerDelta

        if screendivider < 1 then
            --Echo(widgetName .. ": setting screendivider to 1")
            screendivider = 1
        end
        

        --Echo(widgetName .. ": screendivider is " .. screendivider)


        glColor(red, green, blue, dynamicAlpha*victim.type.alpha)  
        glRect(0, 0, wx, wz/screendivider)
        glRect(0, (screendivider-1)*wz/screendivider, wx, wz)          
        glRect(0, (screendivider-1)*wz/screendivider, wx/screendivider, wz/screendivider)
        glRect((screendivider-1)*wx/screendivider, (screendivider-1)*wz/screendivider, wx, 
        wz/screendivider)   
     
        
        dynamicAlpha = 1 - effectDurationPercent


        if effectDuration > victim.type.length then
            --Echo(widgetName .. ": effectDuration > victim.type.length ... reiniting ")
            widget:Initialize()
        end
    elseif dynamicAlpha < 1 then
        --Echo(widgetName .. ": dynamicAlpha < 1 ... reiniting ")
        widget:Initialize()
    end

end


-- unused
function callMeetsGlobalRules(unitID)

    return isVictimSuitable(unitID)

end


function widget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)

    if isVictimSuitable(unitID) and victim.type ~= death then
        victim = {id = unitID, type = death}

        initEffects()
        startTime = timer

    end
end


function widget:UnitDamaged(unitID, unitDefID, teamID, damageDone, paralyzer, weaponDefID, attackerID, attackerDefID, attackerTeam)

    if isVictimSuitable(unitID) and not victim.type then
        victim = {id = unitID, type = damage}

        startTime = timer
        
    end
end


function widget:Initialize()

    if Spring.GetSpectatingState() then
        Echo("<" .. widgetName .. "> Spectator mode. Widget removed.")
        widgetHandler:RemoveWidget()
    end

    initEffects()
    victim = {}
    startTime = nil

end

function widget:Update(dt)



    timer = timer + dt

end