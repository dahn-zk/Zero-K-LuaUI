--- shame on you, Lua
function math.sign(x)
    if x < 0 then
        return -1
    elseif x > 0 then
        return 1
    else
        return 0
    end
end

--- **facepalm**, Lua...
function math.round(x)
    return math.floor(x + 0.5)
end

---
-- Speedups
-- Ref: https://springrts.com/wiki/Lua_Performance#TEST_1:_Localize
---

sin   = math.sin
cos   = math.cos
rad   = math.rad
floor = math.floor
round = math.round
min   = math.min
max   = math.max
