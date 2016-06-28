local timers = require('util.timers')

--[[local ent = Entities:First()

while ent do
    local className = ent:GetClassname()
    --print(className)

    if className == 'player_manager' then
        --DeepPrintTable(getmetatable(ent))
    end

    ent = Entities:Next(ent)
end

timers:setTimeout(function()
    print('Hello 2 seconds later')
end, 2)]]


--print(Time())

--[[local ply = Entities:FindByClassname(nil, 'player')
local floor = Entities:FindByName(nil, 'testTeleport')

floor:SetParent(ply, '')]]


function spawnTemplateAndGrab(templateName, objectName, callback)
    local spawner = Entities:FindByName(nil, templateName)
    DoEntFireByInstanceHandle(spawner, 'ForceSpawn', '', 0, nil, nil)

    timers:setTimeout(function()
        local newEnt = Entities:FindByName(nil, objectName)

        if callback and newEnt then
            callback(newEnt)
        end
    end, 0.1)
end


