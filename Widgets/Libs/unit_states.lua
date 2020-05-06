local GiveOrderToUnit = Spring.GiveOrderToUnit

--- state:
--- - 2 - fire at will
--- - 1 - return fire
function set_fire_state(unit_id, state)
    GiveOrderToUnit(unit_id, CMD_FIRE_STATE, state, 0)
end
