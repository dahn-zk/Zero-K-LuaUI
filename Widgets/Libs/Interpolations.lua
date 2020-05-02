VFS.Include("LuaUI/Widgets/Libs/Algebra.lua")

--- https://en.wikipedia.org/wiki/Cubic_Hermite_spline
function cubic_hermite_spline(x, y, dx, dy)
    return function(t)
        -- @formatter:off
        return v_mul(x, 2*t^3 - 3*t^2 + 1)
             + v_mul(dx, t^3 - 2*t^2 + t)
             + v_mul(y, -2*t^3 + 3*t^2)
             + v_mul(dy, t^3 - t^2)
        -- @formatter:on
    end
end
