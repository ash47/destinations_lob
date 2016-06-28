local timers = require('util.timers')
local enemyController = require('enemy_controller')

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


--[[function spawnTemplateAndGrab(templateName, objectName, callback)
    local spawner = Entities:FindByName(nil, templateName)
    DoEntFireByInstanceHandle(spawner, 'ForceSpawn', '', 0, nil, nil)

    timers:setTimeout(function()
        local newEnt = Entities:FindByName(nil, objectName)

        if callback and newEnt then
            callback(newEnt)
        end
    end, 0.1)
end]]


--local ent = Entities:FindByName(nil, 'test')

--DoEntFireByInstanceHandle(ent, 'ResetPosition', '0', 0, nil, nil)
--DoEntFireByInstanceHandle(ent, 'Open', '', 0, nil, nil)

--local ent2 = Entities:FindByName(nil, 'test2')
---DoEntFireByInstanceHandle(ent2, 'ResetPosition', '0', 0, nil, nil)
--DoEntFireByInstanceHandle(ent2, 'Open', '', 0, nil, nil)

--[[local scope = ent:GetOrCreatePrivateScriptScope()
for k,v in pairs(getmetatable(ent).__index) do
    print(k)
end]]

--local angles = ent:GetAnglesAsVector()
--print(angles.x, angles.y, angles.z)
--ent:SetAngles(0, 90, 0)

--[[local enemyController = class({})

function a:test()
    self.asd = self.asd or 1

    self.asd = self.asd + 1

    print(self.asd)
end

local b = a()

print(a)
print(a():test())
print(a():test())
print(b:test())
print(b:test())]]

local enemy = enemyController()

enemy:init(function(controller)
    controller.origin:SetOrigin(Entities:FindByName(nil, 'pathGenerationMarker'):GetOrigin())

    local prop = Entities:CreateByClassname('prop_physics')
    prop:SetModel('models/enemy/test_enemy/test_enemy.vmdl')
    prop:SetOrigin(controller.attachTo:GetOrigin() + Vector(0, 0, -32))
    prop:SetParent(controller.attachTo, '')

    controller:randomMovement()

    --[[controller:north(function()
        controller:east(function()
            controller:south(function()
                controller:west()
            end)
        end)
    end)]]
end)
