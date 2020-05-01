version = "2"

function widget:GetInfo() return {
  name    = "Wind Speed Printer",
  desc    = "["..version.."] Prints current wind speed to the corner of the screen",
  author  = "[99]Gambit, dahn",
  date    = "2020",
  license = "PD",
  layer   = -10,
  enabled = true
} end

function widget:DrawScreen()
   local dx, dy, dz, strength, nx, ny, nz = Spring.GetWind()
   local minWind, maxWind = Game.windMin, Game.windMax
   gl.Text(string.format("Wind: %d < %.1f < %d", minWind, strength, maxWind), 4, 4) 
end

