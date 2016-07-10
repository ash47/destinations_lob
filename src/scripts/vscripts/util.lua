-- Imports
local timers = require('util.timers')

-- Create the class
local util = {}

function util:traceWorld(startPos, endPos)
    local data = {
        startpos = startPos,
        endpos = endPos,
        mask = 33570827,

    }
    local res = TraceLine(data)

    return data.hit
end

-- Decides if we can move in a given direction
function util:isSolid(startPos, dir, distance)
    local endPos

    distance = distance or 128

    if not dir or type(dir) == 'number' then
        if dir == 1 then
            endPos = Vector(0, distance, 0)
        elseif dir == 2 then
            endPos = Vector(distance, 0, 0)
        elseif dir == 3 then
            endPos = Vector(0, -distance, 0)
        else
            endPos = Vector(-distance, 0, 0)
        end
    else
        endPos = dir
    end

    return self:traceWorld(startPos, startPos + endPos)
end

-- Spawns a template and runs the callback with the new ent
function util:spawnTemplateAndGrab(templateName, parts, callback)
    local spawner = Entities:FindByName(nil, templateName)
    DoEntFireByInstanceHandle(spawner, 'ForceSpawn', '', 0, nil, nil)

    timers:setTimeout(function()
        local partList = {}
        for _,partName in pairs(parts) do
            partList[_] = Entities:FindByName(nil, partName)
        end

        if callback then
            callback(partList)
        end
    end, 0.1)
end

-- Export the class
return util
