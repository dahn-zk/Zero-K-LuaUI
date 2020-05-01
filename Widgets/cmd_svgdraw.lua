function widget:GetInfo()
  return {
    name      = "SVG Draw",
    desc      = "v0.003 Draw SVG on the map - /luaui svgdraw",
    author    = "CarRepairer",
    date      = "2013-08-10",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled = false,
  }
end

include("keysym.h.lua")
local imageLists = {}
local drawMode
local keypadNumKeys = {}
local picScale = 0.5
local picWidth = 0
local picHeight = 0
local echo = Spring.Echo

local function explode(div,str)
  if (div=='') then return false end
  local pos,arr = 0,{}
  -- for each divider found
  for st,sp in function() return string.find(str,div,pos,true) end do
    table.insert(arr,string.sub(str,pos,st-1)) -- Attach chars left of current divider
    pos = sp + 1 -- Jump past current divider
  end
  table.insert(arr,string.sub(str,pos)) -- Attach chars right of last divider
  return arr
end

function string:findlast(str)
  local i
  local j = 0
  repeat
    i = j
    j = self:find(str,i+1,true)
  until (not j)
  return i
end

function string:GetExt()
  local i = self:findlast('.')
  if (i) then
    return self:sub(i)
  end
end

function table:ifind(element)
  for i=1, #self do
    if self[i] == element then
      return i
    end
  end
  return false
end


--code from cmd_emotes by TheFatController

local function linePoints(x1, y1, x2, y2)
  return { x1 = x1, y1 = y1, x2 = x2, y2 = y2 }
end

local function addline(lineList,x1, y1, x2, y2)
  table.insert(lineList,linePoints((x1*picScale),(y1*picScale),(x2*picScale),(y2*picScale)))
end

local function getHW(lineList)
  if (table.getn(lineList) == 0) then
    return false
  end
  local bx1 = lineList[1].x1
  local by1 = lineList[1].y1
  local bx2 = lineList[1].x2
  local by2 = lineList[1].y2
  for _,lineInfo in ipairs(lineList) do
    if (lineInfo.x1 < bx1) then
      bx1 = lineInfo.x1
    end
    if (lineInfo.y1 < by1) then
      by1 = lineInfo.y1
    end
    if (lineInfo.x2 > bx2) then
      bx2 = lineInfo.x2
    end
    if (lineInfo.y2 > by2) then
      by2 = lineInfo.y2
    end
  end
  picWidth = math.abs(bx1 - bx2)
  picHeight = math.abs(by1 - by2)
end


local function drawList(lineList)
  local x,y = Spring.GetMouseState()
  local getOver,getCo = Spring.TraceScreenRay(x,y, true) --param3 = onlycoords
  getHW(lineList)
  --if (getOver == "ground") then
    x = (getCo[1] - (picWidth / 2))
    y = (getCo[3] - (picHeight / 2))
    for _,l in ipairs(lineList) do
      Spring.MarkerAddLine((x+l.x1),0,(y+l.y1),(x+l.x2),0,(y+l.y2))
    end
  --end
end
--end code from cmd_emotes


--convert svg path to a list of line segments. assumes no bezier curves
local function PathToList(data)

    local list = {}
    
    data = data:gsub('([%a,])', ' %1 ')
    --echo(data)
    
    local dataBreakdown = explode( ' ', data )
    
    local x,y, firstX,firstY
    
    local cx,cy
    local firstCmd
    local onFirstCmd
    local abs
    
    local gotX, gotY
    local nx, ny
    
    local gotCoord
    local curCmd
    local curCmdAbs
    
    for i,v in ipairs(dataBreakdown) do
        
        gotCoord = false
        badElem = false
        if v:sub(1,1):find( '[%d%-]' ) then
           
            if not gotX then
                x = v
                gotX = true
            elseif not gotY then
                y = v
                gotX = false
                gotCoord = true
                if not firstX then
                    firstX = x
                    firstY = y
                end
            else --got coord
                --echo('store coord', x, y)
            end
        elseif ({M=1, m=1})[v:sub(1,1)] then
            cmd = 'move'
            abs = v:sub(1,1):find( '%u' ) 
            curCmd = cmd
            curCmdAbs = abs
        elseif ({L=1, l=1})[v:sub(1,1)] then
            cmd = 'line'
            abs = v:sub(1,1):find( '%u' ) 
            curCmd = cmd
            curCmdAbs = abs
        elseif v:sub(1,1) == 'z' then
            cmd = 'line'
            abs = true
            curCmdAbs = abs
            x = firstX
            y = firstY
            gotCoord = true
            curCmd = cmd
        else
            badElem = true
        end
        
        if not badElem then
            abs = curCmdAbs
            if not firstCmd then
                firstCmd = cmd
                onFirstCmd = true
            end
            
            cmd = curCmd
            if gotCoord then
                if onFirstCmd then
                    abs = true
                end
                
                if cmd == 'move' or cmd == 'line' then
                    if abs then
                        nx = x
                        ny = y
                    else
                        nx = cx + x
                        ny = cy + y
                    end
                end
                if cmd == 'line' then
                    list[#list+1] = {cx,cy, nx,ny}
                end
                cx = nx
                cy = ny
                if cmd == 'move' then
                    curCmd = 'line'
                end
                cmd = nil
                abs = false
                onFirstCmd = false
            end
        end
        
    end
    
    return list
    
end


local function AddPaths( pic, paths )
    imageLists[pic] = {}
    for i,path in ipairs(paths) do
        local list = PathToList(path)
        for i2,v in ipairs(list) do
            addline(imageLists[pic],unpack(v))
        end
    end    
end

local function AddImage(file)
	local imageName = file:match( '([^/\\]+)%.svg' )
    --echo(imageName )
	
	local VFSMODE = VFS.ZIP_FIRST
	local data = VFS.LoadFile(file, VFSMODE)
	local lines = explode('\n', data)
	
    local lists = {}
    	
	for _,line in ipairs(lines) do
		--echo(line)
        local match = line:match('%sd="([^"]*)"')
        if match then
            lists[#lists+1] = match
        end
    end
    
    AddPaths( imageName, lists )
end

local function ScanDir()
    local files = VFS.DirList('LuaUI/images/svgdraw')
    local imageFiles = {}
    for i=1,#files do
        local fileName = files[i]
        local ext = (fileName:GetExt() or ""):lower()
        if (table.ifind({'.svg'},ext))then
            imageFiles[#imageFiles+1]=fileName
            AddImage(fileName)
        end
    end
    
end

local function EnterDrawMode()
    drawMode = true
    local out = ''
    local index = 1
    for pic, v in pairs(imageLists) do
        out = out .. '(' .. index .. ') ' .. pic .. '. '
        index = index + 1
    end
    echo(out)
end



-------------
--callins

function widget:Initialize()
    ScanDir()
    
    for i=0,9 do
        keypadNumKeys[ KEYSYMS['KP' .. i] ] = i
    end
end

function widget:KeyPress(key, mods, isRepeat, label, unicode)
    if not drawMode then
        return
    end
    if keypadNumKeys[key] then
        --drawList(imageLists['drawing'])
        
        local index = 1
        for pic, imageList in pairs(imageLists) do
            if index == keypadNumKeys[key] then
                drawList(imageList)
                drawMode = false
                return
            end
            index = index + 1
        end
    end
    drawMode = false
end

function widget:TextCommand(command)
    if (string.find(command, 'svgdraw') == 1) then
        EnterDrawMode()
    end
end