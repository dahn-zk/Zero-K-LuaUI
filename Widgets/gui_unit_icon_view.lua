function widget:GetInfo()
	return {
		name      = "All Unit Icon Overview - View",
		desc      = "Replaces the default engine icon drawing. Conflicts with Icon Height.",
		author    = "esainane",
		date      = "2020-01-27",
		license   = "GNU GPL, v2 or later",
		layer     = 2000,
		handler   = true,
		enabled = false  --  loaded by default?
	}
end

include("keysym.h.lua")

--
-- ICON DRAW SECTION
--

local spWorldToScreenCoords = Spring.WorldToScreenCoords
local glColor = gl.Color
local glTexture = gl.Texture
local glTexRect = gl.TexRect

local frame = 0

local shader
local tLoc
local isCloakyLoc
local constructionProgressLoc
local pulseRateLoc
local framesStaleLoc
local initialized = false

function widget:Initialize()
	--[[
	Shader:
	  glColor: team color (or white if selected)
		cloaky_effect: truthy if cloaked
		construction_effect: float of construction progress
	--]]
	shader = gl.CreateShader({
		fragment=[[
		#version 330

		const float pi = 3.141592;

		in vec4 gl_TexCoord[];
		in vec4 gl_Color;
		uniform sampler2D texture;
		out vec4 diffuseColor;

		uniform int t;
		uniform int cloaky_effect;
		uniform int frames_stale;
		uniform float construction_effect;
		uniform float pulse_rate;

		void main(void) {
			vec2 texCoord = vec2(gl_TexCoord[0]);
			vec4 S0 = texture2D(texture, texCoord);

			// As a base: Output is the input texture's color, tinted by the team color
			diffuseColor = S0 * gl_Color;

			if (bool(cloaky_effect)) {
				// If a unit is cloaked, override the visible black parts of it with a
				// shifting blue-green-purple effect
				const float blackishThreshold = 0.4;
				if (S0.r < blackishThreshold && S0.g < blackishThreshold && S0.b < blackishThreshold) {
					// cloaky effect
					diffuseColor.rgb += 3;
					diffuseColor.rgb /= 4;
					diffuseColor.rgb += vec3(
					  0.6+mod(texCoord.x*texCoord.x + texCoord.y / 3 + t / 50.0, 0.3),
						0.7+mod(texCoord.y*texCoord.y + texCoord.x / 2 + t / 50.0, 0.3),
						0.9
					) * 3;
					diffuseColor.rgb /= 4;
				} else {
					diffuseColor.rgb *= 1;
				}
			}
			// Draw a completion progress circle for under-construction entities
			if (construction_effect < 1.0f) {
				// Work out how far along the circle we are
				float dx = texCoord.x - .5;
				float dy = texCoord.y - .5;
				float angle;
				// Avoid x == 0 divide-by-zero implementation-definedness
				if (abs(dx) < 0.001) {
					angle = dy > 0 ? 3.0 * pi / 2.0 : pi / 2.0;
				} else {
					angle = atan(dy, dx);
					angle += pi;
				}
				// Change the boundary to be at the top of the icon
				angle += 3 * pi / 2;
				// convert to [0.0,1.0]
				float equivProgress = mod(angle, 2 * pi) / (2 * pi);

				// Ensure a minimal visible circle while under construction, of team color
				// Used to work around icons that are off center or very uneven
				// (Krow, Starlight)
				if (abs(dx)*abs(dx)+abs(dy)*abs(dy) < 0.1) {
					diffuseColor.rgb += (1 - diffuseColor.a) * gl_Color.rgb;
					diffuseColor.a = max(0.9, diffuseColor.a);
				}

				// Under-construction entities pulse, and more insistently the closer they are to completion

				// Now, actually darken the icon under-construction entities
				float ft = float(t);
				if (equivProgress > construction_effect) {
					// Further along the circle than actual progress made, very dark
					float mult = 0.50 + // Baseline
						-(0.4 * construction_effect) + // Emphasize the smaller slice - darker slice is much darker when nearly done for visibility
						0.16 * (mod(ft, pulse_rate) / pulse_rate); // Pulse
					diffuseColor.rgb *= mult;
				} else {
					// We've built this far, still leave it darker than usual
					float mult = 1 +
					  - (.1 + // Baseline
						  .36 * construction_effect // Emphasize the smaller slice - lighter slice is much ligher when barely started, for visibility
						) * (1.0 - mod(ft, pulse_rate) / pulse_rate); // Pulse
					diffuseColor.rgb *= mult;
				}
			}
			// Is our information stale, by many frames?
			// linear decay from 100% to 40% over 20 seconds
			diffuseColor.a *= 1 - 0.6 * min(600, frames_stale) / 600.0;
		}
		]],
		uniformInt = {cloaky_effect = 0, t=0, frames_stale = 0},
		uniformFloat= {construction_effect = 1.0, pulse_rate = 20.0}
	})
	Spring.Echo(gl.GetShaderLog())


	if not shader then
		Spring.Echo("[gui_unit_icon::Initialize] no shader support")
		Spring.Echo(gl.GetShaderLog())
		widgetHandler:RemoveWidget(self)
		return
	end

	tLoc = gl.GetUniformLocation(shader, "t")
	isCloakyLoc = gl.GetUniformLocation(shader, "cloaky_effect")
	pulseRateLoc = gl.GetUniformLocation(shader, "pulse_rate")
	constructionProgressLoc = gl.GetUniformLocation(shader, "construction_effect")
	framesStaleLoc = gl.GetUniformLocation(shader, "frames_stale")


	initialized = true
end

function widget:Shutdown()
	if initialized then
		gl.DeleteShader(shader)
	end
end

local function GetCameraHeight()
	local cs = Spring.GetCameraState()
	local gy = Spring.GetGroundHeight(cs.px, cs.pz)
	local testHeight = cs.py - gy
	if cs.name == "ov" then
		testHeight = WG.AllUnitIcon.iconheight * 2
	elseif cs.name == "ta" then
		testHeight = cs.height - gy
	end
	return testHeight
end

local function GetIconScaleForHeight(h)
	-- Want 10 for ~2600, 8 for 6000, 6 for 8334
	return 11.5 - h * 2 / 3400
end

local function DrawOneUnit(u, iconScale)
	local x,y,z = spWorldToScreenCoords(u.wx, u.wy, u.wz)
	local tr,tg,tb = u.tr, u.tg, u.tb
	local icon = u.icon
	local size = iconScale * icon.size
	glColor(tr,tg,tb,1)
	local isCloakedInt
	if u.isCloaked then
		isCloakedInt = 1
	else
		isCloakedInt = 0
	end
	gl.UniformInt(isCloakyLoc, isCloakedInt)
	gl.Uniform(constructionProgressLoc, u.buildProgress)
	gl.Uniform(pulseRateLoc, u.pulseRate)
	gl.UniformInt(framesStaleLoc, frame - u.lastUpdate)
	--Spring.Echo(icon.bitmap)
	glTexture(icon.bitmap)
	glTexRect(x-size, y-size, x+size, y+size)
	glTexture(false)
end

-- local lastHeight = 0
function widget:DrawScreen()
	if not WG.AllUnitIcon.showing_icons then return end
	local testHeight = GetCameraHeight()
	local iconScale = GetIconScaleForHeight(testHeight)
	--if lastHeight ~= testHeight then
	--	Spring.Echo("New Height:", testHeight)
	--	lastHeight = testHeight
	--end
	gl.UseShader(shader)
	gl.UniformInt(tLoc, frame)
	for i,u in pairs(WG.AllUnitIcon.all_units) do
		DrawOneUnit(u, iconScale)
	end
	gl.UseShader(0)
end

function widget:GameFrame(n)
	frame = n
end
