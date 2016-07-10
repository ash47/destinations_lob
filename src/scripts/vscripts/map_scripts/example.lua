-- Libraries
local gamemode = require('gamemode')
local timers = require('util.timers')
local errorlib = require('util.errorlib')

-- Called once the HMD has init
function OnHMDAvatarAndHandsSpawned()
    -- Need time for the HMD to spawn
    timers:setTimeout(function()
        -- GRab an instance of the player
        local ply = Entities:FindByClassname(nil, 'player')
        if not ply then
            errorlib:error('Failed to find player!')
            return
        end

        -- Grab an instance of the HMD
        local hmd = ply:GetHMDAvatar()
        if not hmd then
            errorlib:error('Failed to find VR headset!')
        end

        -- Grab an instace of each hand
        local hand0 = hmd:GetVRHand(0)
        local hand1 = hmd:GetVRHand(1)
        if not hand0 or not hand1 then
            errorlib:error('Failed to find both VR hands!')
            return
        end

        -- Init the gamemode
        gamemode:init(ply, hmd, hand0, hand1)
    end, 0)
end

-- Precaching
function OnPrecache(context)
    -- Precache

    -- Weapons and items
    context:AddResource('models/weapons/sword1/sword1.vmdl')
    context:AddResource('models/items/shield1/shield1.vmdl')

    context:AddResource('models/items/boomerang/boomerang.vmdl')
    context:AddResource('models/props/boomerang/boomerang.vmdl')

    -- Misc
    context:AddResource('models/props_junk/watermelon01.vmdl')

    -- Enemy
    context:AddResource('models/enemy/test_enemy/test_enemy.vmdl')

    -- Teleport stuff
    context:AddResource('models/effects/teleport/teleport_destinations.vmdl')
    context:AddResource('models/effects/teleport/teleport_info.vmdl')
    context:AddResource('models/effects/teleport/teleport_lock.vmdl')
    context:AddResource('models/effects/teleport/teleport_marker.vmdl')
    context:AddResource('models/effects/teleport/teleport_move.vmdl')
    context:AddResource('models/effects/teleport/teleport_switchscenes.vmdl')
    context:AddResource('models/effects/teleport/vt_teleport_destination.vmdl')
    context:AddResource('models/effects/teleport/vt_teleport_destination_0e0e9edf.vmdl')
end