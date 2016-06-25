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

