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

--[[local enemy = enemyController()

enemy:init(function(controller)
    controller.origin:SetOrigin(Entities:FindByName(nil, 'enemySpawnTest'):GetOrigin())

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
--end)


--print(type(0))

--[[function createDoor(origin, angles, callback)
    local doorTemplateName = 'door_1_template'
    local doorPartsName = {
        [1] = 'door_1_door_a',
        [2] = 'door_1_door_b',
        [3] = 'door_1_door_c',
        [4] = 'door_1_door_d'
    }
    local doorOriginName = 'door_1_origin'
    local doorTriggerName = 'door_1_trigger'
    local doorLockName = 'door_1_lock'
    local doorSoundName = 'door_1_sound'

    -- Spawn a new door
    local spawner = Entities:FindByName(nil, doorTemplateName)
    DoEntFireByInstanceHandle(spawner, 'ForceSpawn', '', 0, nil, nil)

    -- Grab it after a short delay
    timers:setTimeout(function()
        -- Grab door parts
        local doorOrigin = Entities:FindByName(nil, doorOriginName)
        local doorTrigger = Entities:FindByName(nil, doorTriggerName)
        local doorLock = Entities:FindByName(nil, doorLockName)
        local doorSound = Entities:FindByName(nil, doorSoundName)

        local doorParts = {}
        for _,doorPartName in pairs(doorPartsName) do
            table.insert(doorParts, Entities:FindByName(nil, doorPartName))
        end

        local isDoorOpen = false

        -- Hook the trigger
        local scope = doorTrigger:GetOrCreatePrivateScriptScope()
        scope.OnTrigger = function(args)
            -- Check what just collided
            local activator = args.activator

            if activator then
                print(activator:GetClassname())
            end

            -- Only open once
            if isDoorOpen then return end
            isDoorOpen = true

            print('Yes!')

            for _,doorPart in pairs(doorParts) do
                -- Play the sound
                if IsValidEntity(doorSound) then
                    DoEntFireByInstanceHandle(doorSound, 'StartSound', '', 0, nil, nil)
                end

                -- Hide the lock
                if IsValidEntity(doorLock) then
                    DoEntFireByInstanceHandle(doorLock, 'Disable', '', 0, nil, nil)
                end

                -- Open the doors
                if IsValidEntity(doorPart) then
                    DoEntFireByInstanceHandle(doorPart, 'Open', '', 0, nil, nil)
                end
            end
        end
        doorTrigger:RedirectOutput('OnTrigger', 'OnTrigger', doorTrigger)

        -- Move into position
        if IsValidEntity(doorOrigin) then
            doorOrigin:SetOrigin(origin)
            doorOrigin:SetAngles(angles.x, angles.y, angles.z)
        end

        if callback then
            callback()
        end
    end, 0.1)
end

function spawnAllDoors()
    local doorSpawners = Entities:FindAllByName('spawn_door_here')

    local spawnNextDoor

    spawnNextDoor = function()
        if #doorSpawners > 0 then
            local doorLocation = table.remove(doorSpawners, 1)

            if IsValidEntity(doorLocation) then
                createDoor(doorLocation:GetOrigin(), doorLocation:GetAnglesAsVector(), spawnNextDoor)
            else
                spawnNextDoor()
            end
        end
    end

    -- Start spawning
    spawnNextDoor()
end

spawnAllDoors()]]

function createSliderMonster()
    local templateName = 'scary_monster_template'
    local templateCornerName = 'scary_monster_corner'
    local templateRightTrigger = 'scary_monster_right_trigger'
    local templateDownTrigger = 'scary_monster_down_trigger'


end


--[[local monster = Entities:FindByName(nil, 'scary_monster_train')
local monsterCorner = Entities:FindByName(nil, 'scary_monster_corner')

--DoEntFireByInstanceHandle(monsterCorner, 'EnableAlternatePath', '', 0, nil, nil)
DoEntFireByInstanceHandle(monsterCorner, 'DisableAlternatePath', '', 0, nil, nil)

DoEntFireByInstanceHandle(monster, 'SetSpeed', '1', 0, nil, nil)
DoEntFireByInstanceHandle(monster, 'StartForward', '', 0, nil, nil)]]