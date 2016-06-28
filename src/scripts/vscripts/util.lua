-- Create the class
local util = {}

function util:traceWorld(startPos, endPos)
    local data = {
        startpos = startPos,
        endpos = endPos,
        mask = 131083
    }
    local res = TraceLine(data)

    return data.hit
end

-- Decides if we can move in a given direction
function util:isSolid(startPos, dir)
    local endPos
    if dir == 1 then
        endPos = Vector(0, -128, 0)
    elseif dir == 2 then
        endPos = Vector(128, 0, 0)
    elseif dir == 3 then
        endPos = Vector(0, 128, 0)
    else
        endPos = Vector(-128, 0, 0)
    end

    return self:traceWorld(startPos, startPos + endPos)
end

-- Export the class
return util
