-- Libs
local constants = require('constants')
local timers = require('util.timers')
local errorlib = require('util.errorlib')
local util = require('util')

local enemyBlob = require('enemy_blob')

-- Define the gamemode
local Gamemode = {}

-- Init gamemode
function Gamemode:init(ply, hmd, hand0, hand1)
    -- Ensure we only init once
    if self.doneInit then return end
    self.doneInit = true

    -- Store references
    self.ply = ply
    self.hmd = hmd
    self.hand0 = hand0
    self.hand1 = hand1

    -- Store the teleport devices
    self.tpDevice0 = hand0:GetHandAttachment()
    self.tpDevice1 = hand1:GetHandAttachment()

    -- Init buttson
    self:initButtons()

    -- Init Inventory
    self:initInventory()

    -- Init doors
    self:spawnAllDoors()

    -- Init slider monsters
    self:spawnAllSliderMonsters()

    -- Spawn mobs
    self:spawnMobs()

    -- Handle the bow pickup
    self:handleBowPickup()

    -- Start thinking
    timers:setTimeout('onThink', 0.1, self)

    -- All good
    errorlib:notify('Gamemode has started successfully!')

    -- Room unlocking
    local this = self
    _G.onEnterRoom = function(roomName)
        this:onEnterRoom(roomName)
    end

    -- Init EULA
    self:initEula()

    self:generatePaths()
end

function Gamemode:initEula()
    local this = self

    _G.onAcceptedEULA = function()
        this:onAcceptedEULA()
    end

    -- Init eula
    local eula = Entities:FindByName(nil, 'info_eula')
    DoEntFireByInstanceHandle(eula, 'AcceptUserInput', '', 0, nil, nil)
    DoEntFireByInstanceHandle(eula, 'AddCSSClass', 'Activated', 0, nil, nil)

    local endGame = Entities:FindByName(nil, 'info_endgame')
    DoEntFireByInstanceHandle(endGame, 'AcceptUserInput', '', 0, nil, nil)
    DoEntFireByInstanceHandle(endGame, 'AddCSSClass', 'Activated', 0, nil, nil)
end

function Gamemode:onAcceptedEULA()
    -- Generate paths
    self:generatePaths()

    -- Remove EULA
    local eulaEnt = Entities:FindByName(nil, 'info_eula')
    eulaEnt:RemoveSelf()
end

-- Gamemode think function
function Gamemode:onThink()
    -- Process game stuff
    self:handleButtons()

    -- Run again after a short delay
    return 0.1
end

-- Generates paths
function Gamemode:generatePaths(currentPath)
    local marker = Entities:FindByName(nil, 'pathGenerationMarker')
    if not marker then
        errorlib:error('Unable to find path generation marker')
        return
    end

    self.pathMarker = marker

    -- Ensure we have a table to store generated nodes
    self.generatedNodes = self.generatedNodes or {}

    -- Cleanup old nodes
    for nodeID, node in pairs(self.generatedNodes) do
        if node ~= currentPath then
            node:RemoveSelf()
        end
    end

    -- Update our current path
    if self.pathRemoveNextTime and self.pathRemoveNextTime ~= currentPath then
        self.pathRemoveNextTime:RemoveSelf()
    end
    self.pathRemoveNextTime = currentPath

    -- Create new table
    self.generatedNodes = {}

    local middle = marker:GetOrigin()

    local travelDistance = 64
    local largeTravelDistance = 128

    -- Tests a position and adds it if it's valid
    local this = self
    local testPos = function(pos)
        local upPos = middle + Vector(0, 0, 64)
        if not util:isSolid(upPos, pos) and not util:isSolid(upPos, pos * 1.1) then
            table.insert(this.generatedNodes, this:generatePathNode(middle + pos))

            return true
        end

        return false
    end

    -- Spawn new nodes, inner circle
    local canEast = testPos(Vector(travelDistance, 0, 0))
    local canSouth = testPos(Vector(0, travelDistance, 0))
    local canWest = testPos(Vector(-travelDistance, 0, 0))
    local canNorth = testPos(Vector(0, -travelDistance, 0))

    if canEast and canSouth then
        testPos(Vector(travelDistance, travelDistance, 0))
    end

    if canWest and canSouth then
        testPos(Vector(-travelDistance, travelDistance, 0))
    end

    if canWest and canNorth then
        testPos(Vector(-travelDistance, -travelDistance, 0))
    end

    if canEast and canNorth then
        testPos(Vector(travelDistance, -travelDistance, 0))
    end

    -- Spawn new nodes, outer nodes
    testPos(Vector(-largeTravelDistance, 0, 0))
    testPos(Vector(largeTravelDistance, 0, 0))
    testPos(Vector(0, largeTravelDistance, 0))
    testPos(Vector(0, -largeTravelDistance, 0))
end

function Gamemode:generatePathNode(pos)
    -- Grab a reference to the gamemode
    local this = self

    -- Create the entity
    local ent = Entities:CreateByClassname('vr_teleport_marker')
    ent:SetOrigin(pos)

    -- Add the callback
    local scope = ent:GetOrCreatePrivateScriptScope()
    scope.OnTeleportTo = function(args)
        -- Move the marker
        this.pathMarker:SetOrigin(pos)

        -- Generate new paths
        this:generatePaths(ent)
    end
    ent:RedirectOutput('OnTeleportTo', 'OnTeleportTo', ent)

    return ent
end

function Gamemode:test()
    print('test')
end

-- Init buttons
function Gamemode:initButtons()
    -- Stored which buttons were pressed last frame
    self.buttonPressed = {}
    self.doneLongPress = {}

    -- How long is considered a long hold
    self.longHold = 0.25

    -- Contains all buttons for hand0

end

-- Handles VR button presses
function Gamemode:handleButtons()
    -- Grab useful variables
    local ply = self.ply

    -- Process both hands
    for handID=0,1 do
        local gripButtonID = constants['hand'..handID..'_grip']
        local now = Time()

        -- Is the grip button pressed?
        if ply:IsVRControllerButtonPressed(gripButtonID) then
            -- Grip is currently pressed
            if not self.buttonPressed[gripButtonID] then
                self.buttonPressed[gripButtonID] = Time()
            else
                -- Check how long we were holding it
                local timeHeld = now - self.buttonPressed[gripButtonID]
                if timeHeld >= self.longHold and not self.doneLongPress[gripButtonID] then
                    self.doneLongPress[gripButtonID] = true
                    --print('Long hold! ' .. handID)

                    --self:spawnMelon(handID)
                end
            end
        else
            -- Were we previously holding the button?
            if self.buttonPressed[gripButtonID] then
                -- Check how long we were holding it
                local timeHeld = now - self.buttonPressed[gripButtonID]
                if timeHeld < self.longHold then
                    --print('tap ' .. handID)
                    self:handGotoNextItem(handID)
                end

                -- Reset that it is no longer pressed
                self.buttonPressed[gripButtonID] = nil
                self.doneLongPress[gripButtonID] = nil
            end
        end

        -- Is the trigger pressed?
        local triggerButtonID = constants['hand'..handID..'_trigger']
        if ply:IsVRControllerButtonPressed(triggerButtonID) then
            if not self.buttonPressed[triggerButtonID] then
                self.buttonPressed[triggerButtonID] = true

                -- Trigger was pressed
                self:onTriggerPressed(handID, triggerButtonID)
            end
        else
            self.buttonPressed[triggerButtonID] = false
        end
    end
end

-- When the trigger is pressed
function Gamemode:onTriggerPressed(handID, buttonID)
    local hand = self['hand' .. handID]
    if not hand then
        errorlib:error('Failed to find hand ' .. handID)
        return
    end

    local this = self

    local angs = hand:GetAnglesAsVector()

    local pitchDegree = angs.x
    local yawDegree = angs.y

    local pitch = pitchDegree * math.pi / 180
    local yaw = yawDegree * math.pi / 180

    local newVec = Vector(
        math.cos(yaw) * math.cos(pitch),
        math.sin(yaw) * math.cos(pitch),
        -math.sin(pitch)
    )

    local handItem = self['hand' .. handID .. 'Item']

    if handItem == constants.item_boomerang then
        util:spawnTemplateAndGrab('prop_boomerang_template', {
            model = 'prop_boomerang',
            trigger = 'prop_boomerang_trigger'
        }, function(parts)
            local ent = parts.model

            local theVelocity = 250

            if this.upgradedBoomerang then
                theVelocity = 750
            end

            ent:SetOrigin(hand:GetOrigin())
            ent:ApplyAbsVelocityImpulse(newVec * theVelocity)

            local handParts = self['entityParts' .. handID] or {}
            local partModel = handParts.model

            if IsValidEntity(partModel) then
                local modelAngles = partModel:GetAnglesAsVector()
                ent:SetAngles(modelAngles.x, modelAngles.y, modelAngles.z)
            end

            timers:setTimeout(function()
                if IsValidEntity(ent) then
                    ent:RemoveSelf()
                end
            end, 2)

            local itemCol = parts.trigger

            if itemCol then
                local scope = itemCol:GetOrCreatePrivateScriptScope()
                scope.OnStartTouch = function(args)
                    local activator = args.activator

                    -- Are they an enemy?
                    if activator.enemy then
                        -- Do they have an onHit callback?
                        if activator.enemy.onHit then
                            activator.enemy:onHit()
                        end
                    end
                end
                itemCol:RedirectOutput('OnStartTouch', 'OnStartTouch', itemCol)
            end
        end)
    end

    if handItem == constants.item_bomb then
        util:spawnTemplateAndGrab('template_prop_bomb', {
            bomb = 'template_prop_bomb_bomb'
        }, function(parts)
            local ent = parts.bomb

            ent:SetOrigin(hand:GetOrigin())

            local handParts = self['entityParts' .. handID] or {}
            local partModel = handParts.model

            if IsValidEntity(partModel) then
                local modelAngles = partModel:GetAnglesAsVector()
                ent:SetAngles(modelAngles.x, modelAngles.y, modelAngles.z)
                ent:SetOrigin(partModel:GetOrigin())
            end

            ent:ApplyAbsVelocityImpulse(newVec * 250)

            timers:setTimeout(function()
                if IsValidEntity(ent) then
                    this:createExplosion(ent:GetOrigin())
                    ent:RemoveSelf()
                end
            end, 2)
        end)
    end

    if handItem == constants.item_bow then
        util:spawnTemplateAndGrab('template_prop_arrow', {
            model = 'template_prop_arrow_arrow',
            trigger = 'template_prop_arrow_trigger'
        }, function(parts)
            local ent = parts.model

            ent:SetOrigin(hand:GetOrigin())
            ent:ApplyAbsVelocityImpulse(newVec * 1000)

            local handParts = self['entityParts' .. handID] or {}
            local partModel = handParts.arrow

            if IsValidEntity(partModel) then
                local modelAngles = partModel:GetAnglesAsVector()
                ent:SetAngles(modelAngles.x, modelAngles.y, modelAngles.z)
                ent:SetOrigin(partModel:GetOrigin())
            end

            timers:setTimeout(function()
                if IsValidEntity(ent) then
                    ent:RemoveSelf()
                end
            end, 2)

            local itemCol = parts.trigger

            if itemCol then
                local scope = itemCol:GetOrCreatePrivateScriptScope()
                scope.OnStartTouch = function(args)
                    local activator = args.activator

                    -- Are they an enemy?
                    if activator.enemy then
                        -- Do they have an onHit callback?
                        if activator.enemy.onHit then
                            activator.enemy:onHit()
                        end
                    end
                end
                itemCol:RedirectOutput('OnStartTouch', 'OnStartTouch', itemCol)
            end
        end)
    end
end

-- DEBUG: Spawn Melon
function Gamemode:spawnMelon(handID)
    local hand = self['hand' .. handID]
    if not hand then
        errorlib:error('Failed to find hand ' .. handID)
        return
    end

    local ent = Entities:CreateByClassname('prop_physics')
    ent:SetModel('models/props_junk/watermelon01.vmdl')

    ent:SetOrigin(hand:GetOrigin() + Vector(0, 0, 64))
end

-- Init inventory system
function Gamemode:initInventory()
    self.hand0Item = constants.item_nothing
    self.hand1Item = constants.item_nothing

    -- Defines all items that can be gotten
    self.itemOrderList = {
        [1] = constants.item_nothing,
        [2] = constants.item_sword,
        [3] = constants.item_shield,
        [4] = constants.item_boomerang,
        [5] = constants.item_bow,
        [6] = constants.item_bomb,
        [7] = constants.item_key,
        [8] = constants.item_map
    }

    -- Define the reverse lookup table
    self.reverseItemOrder = {}
    for posNum, itemID in pairs(self.itemOrderList) do
        self.reverseItemOrder[itemID] = posNum
    end

    -- Defines items that can only be in one hand at a time
    self.onlyOneCopy = {
        [constants.item_key] = true,
        [constants.item_map] = true
    }

    -- Defines which items we actually own
    self.myItems = {}

    -- Give starting items
    self.myItems[constants.item_nothing] = true
    self.myItems[constants.item_sword] = true
    self.myItems[constants.item_shield] = true
    self.myItems[constants.item_bomb] = true
    self.myItems[constants.item_map] = true
    self.myItems[constants.item_boomerang] = true

    -- DEBUG: Give all items
    --[[for posNum, itemID in pairs(self.itemOrderList) do
        self.myItems[itemID] = true
    end]]

    --self.myItems[constants.item_bow] = false

    -- Start with 0 keys
    self.totalKeys = 0
end

-- Go to the next item in a hand
function Gamemode:handGotoNextItem(handID)
    local hand = self['hand' .. handID]
    if not hand then
        errorlib:error('Failed to find hand ' .. handID)
        return
    end

    -- Grab the itemID that is currently in the hand
    local currentItemID = self['hand' .. handID .. 'Item']

    -- Find it's position in the item order list
    local itemOrder = self.reverseItemOrder[currentItemID]

    -- Find the next item
    local nextItemID = itemOrder + 1
    local tempItemID
    while true do
        tempItemID = self.itemOrderList[nextItemID]
        if tempItemID then
            if self.myItems[tempItemID] then
                -- is this item only allowed to be in one hand at a time?
                if self.onlyOneCopy[tempItemID] and (self.hand0Item == tempItemID or self.hand1Item == tempItemID) then
                    -- item is already in one of our hands :/
                    nextItemID = nextItemID + 1
                else
                    -- Is it a key, do we have any keys?
                    if tempItemID == constants.item_key and self.totalKeys <= 0 then
                        -- Item is a key, we don't have any keys :/
                        nextItemID = nextItemID + 1
                    else
                        -- Found the next item
                        break
                    end
                end
            else
                nextItemID = nextItemID + 1
            end
        else
            nextItemID = 1
        end
    end

    -- Put this item into our hand
    self:setHandItem(handID, tempItemID)
end

-- Sets the item that is in a hand
-- This assumes you own the item, check this elsewhere
function Gamemode:setHandItem(handID, itemID)
    local hand = self['hand' .. handID]
    if not hand then
        errorlib:error('Failed to find hand ' .. handID)
        return
    end

    -- Is this a new item?
    if self['hand' .. handID .. 'Item'] == itemID then
        -- Already got this item in this hand
        return
    end

    --[[local cols = Entities:FindByName(nil, 'swordCol' .. handID)
    if cols then
        cols:SetParent(nil, '')
        cols:SetOrigin(Vector(10000,10000,10000))
    end]]

    -- Destroy old item
    local oldItem = self['entityItem' .. handID]
    if IsValidEntity(oldItem) then
        oldItem:RemoveSelf()
        self['entityItem' .. handID] = nil
    end

    -- Remove references to parts
    self['entityParts' .. handID] = {}

    -- Create the new item
    self:createHandItem(itemID, handID, function(itemOrigin, parts)
        if itemOrigin then
            -- Store it
            self['entityItem' .. handID] = itemOrigin

            local angles = hand:GetAnglesAsVector()

            -- Attach
            itemOrigin:SetOrigin(hand:GetOrigin())
            itemOrigin:SetParent(hand, '')
            itemOrigin:SetAngles(angles.x, angles.y, angles.z)
        end

        self['entityParts' .. handID] = parts or {}
    end)

    -- Store the ID that is now in our hand
    self['hand' .. handID .. 'Item'] = itemID
end

-- Creates an instance of a given item
function Gamemode:createHandItem(itemID, handID, callback)
    local this = self

    if itemID == constants.item_sword then
        util:spawnTemplateAndGrab('templateSword1', {
            model = 'templateSword1_sword',
            trigger = 'templateSword1_trigger'
        }, function(parts)
            local itemCol = parts.trigger

            if itemCol then
                local scope = itemCol:GetOrCreatePrivateScriptScope()
                scope.OnStartTouch = function(args)
                    local activator = args.activator

                    -- Are they an enemy?
                    if activator.enemy then
                        -- Do they have an onHit callback?
                        if activator.enemy.onHit then
                            activator.enemy:onHit()
                        end
                    end
                end
                itemCol:RedirectOutput('OnStartTouch', 'OnStartTouch', itemCol)
            end
            callback(parts.model, parts)
        end)
    end

    if itemID == constants.item_key then
        util:spawnTemplateAndGrab('item_key_template', {
            origin = 'item_key_origin',
            model = 'item_key_model'
        }, function(parts)
            parts.model.isDoorKey = true
            callback(parts.origin, parts)
        end)
    end

    if itemID == constants.item_bomb then
        util:spawnTemplateAndGrab('template_item_bomb', {
            origin = 'template_item_bomb_origin',
            model = 'template_item_bomb_bomb'
        }, function(parts)
            callback(parts.origin, parts)
        end)
    end

    if itemID == constants.item_shield then
        util:spawnTemplateAndGrab('template_item_shield', {
            model = 'template_item_shield_model',
            origin = 'template_item_shield_origin'
        }, function(parts)
            callback(parts.origin, parts)
        end)
    end

    if itemID == constants.item_bow then
        util:spawnTemplateAndGrab('template_item_bow', {
            model = 'template_item_bow_bow',
            origin = 'template_item_bow_origin',
            arrow = 'template_item_bow_arrow'
        }, function(parts)
            callback(parts.origin, parts)
        end)
    end

    if itemID == constants.item_boomerang then
        util:spawnTemplateAndGrab('item_boomerang_template', {
            model = 'item_boomerang_model',
            origin = 'item_boomerang_origin'
        }, function(parts)
            callback(parts.origin, parts)
        end)
    end

    if itemID == constants.item_map then
        util:spawnTemplateAndGrab('template_map_template', {
            back = 'template_map_model',
            model = 'template_map_map',
            origin = 'template_map_origin',
            origin2 = 'template_map_origin2'
        }, function(parts)
            local attachTo = parts.origin
            if handID == 1 then
                attachTo = parts.origin2
            end

            parts.model:SetParent(attachTo, '')
            callback(attachTo, parts)

            -- Store this as our current map
            this.currentMapEntity = parts.model
            this:unlockRoomsForMapEntity(parts.model)
        end)
    end

    --[[if itemID == constants.item_bow then

    end]]
end

-- When a key is used
function Gamemode:onKeyUsed()
    for handID=0,1 do
        if self['hand' .. handID .. 'Item'] == constants.item_key then
            self:setHandItem(handID, constants.item_nothing)
        end
    end

    -- Lower the number of keys we have left
    self.totalKeys = self.totalKeys - 1
end

function Gamemode:createDoor(origin, angles, callback)
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

    local this = self

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
        scope.OnStartTouch = function(args)
            -- Check what just collided
            local activator = args.activator

            if not activator or not activator.isDoorKey then return end

            -- Only open once
            if isDoorOpen then return end
            isDoorOpen = true

            -- Play the sound
            if IsValidEntity(doorSound) then
                DoEntFireByInstanceHandle(doorSound, 'StartSound', '', 0, nil, nil)
            end

            -- Hide the lock
            if IsValidEntity(doorLock) then
                DoEntFireByInstanceHandle(doorLock, 'Disable', '', 0, nil, nil)
            end

            for _,doorPart in pairs(doorParts) do
                -- Open the doors
                if IsValidEntity(doorPart) then
                    DoEntFireByInstanceHandle(doorPart, 'Open', '', 0.25, nil, nil)
                end
            end

            -- The key has now been used
            this:onKeyUsed()
        end
        doorTrigger:RedirectOutput('OnStartTouch', 'OnStartTouch', doorTrigger)

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

function Gamemode:spawnAllDoors()
    local doorSpawners = Entities:FindAllByName('spawn_door_here')

    local spawnNextDoor

    local this = self
    spawnNextDoor = function()
        if #doorSpawners > 0 then
            local doorLocation = table.remove(doorSpawners, 1)

            if IsValidEntity(doorLocation) then
                this:createDoor(doorLocation:GetOrigin(), doorLocation:GetAnglesAsVector(), spawnNextDoor)
            else
                spawnNextDoor()
            end
        end
    end

    -- Start spawning
    spawnNextDoor()

    -- Hook breakable walls
    local ents = Entities:FindAllByName('breakable_wall')
    for _,ent in pairs(ents) do
        ent.breakOnExplode = true
    end
end

function Gamemode:createSliderMonster(origin, angles, callback)
    local templateName = 'scary_monster_template'
    local templateCornerName = 'scary_monster_corner'
    local templateRightTrigger = 'scary_monster_right_trigger'
    local templateDownTrigger = 'scary_monster_down_trigger'
    local templateTrainName = 'scary_monster_train'
    local templateOriginName = 'scary_monster_origin'
    local templateStartName = 'scary_monster_start'
    local templateMoveSoundName = 'scary_monster_sound_move'

    -- Spawn a new door
    local spawner = Entities:FindByName(nil, templateName)
    DoEntFireByInstanceHandle(spawner, 'ForceSpawn', '', 0, nil, nil)

    local this = self

    -- Grab it after a short delay
    timers:setTimeout(function()
        -- Grab door parts
        local corner = Entities:FindByName(nil, templateCornerName)
        local rightTrigger = Entities:FindByName(nil, templateRightTrigger)
        local downTrigger = Entities:FindByName(nil, templateDownTrigger)
        local train = Entities:FindByName(nil, templateTrainName)
        local templateOrigin = Entities:FindByName(nil, templateOriginName)
        local templateStart = Entities:FindByName(nil, templateStartName)
        local templateMoveSound = Entities:FindByName(nil, templateMoveSoundName)

        -- Hook the right trigger
        local scope = rightTrigger:GetOrCreatePrivateScriptScope()
        scope.OnStartTouch = function(args)
            -- Change the direction to move in
            if IsValidEntity(corner) then
                DoEntFireByInstanceHandle(corner, 'DisableAlternatePath', '', 0, nil, nil)
            end

            -- Start moving
            if IsValidEntity(train) then
                DoEntFireByInstanceHandle(train, 'SetSpeed', '1', 0, nil, nil)
                DoEntFireByInstanceHandle(train, 'StartForward', '', 0, nil, nil)
            end

            -- Start the movement sound
            DoEntFireByInstanceHandle(templateMoveSound, 'StartSound', '', 0, nil, nil)

            -- Disable triggers
            DoEntFireByInstanceHandle(rightTrigger, 'Disable', '', 0, nil, nil)
            DoEntFireByInstanceHandle(downTrigger, 'Disable', '', 0, nil, nil)
        end
        rightTrigger:RedirectOutput('OnStartTouch', 'OnStartTouch', rightTrigger)

        -- Hook the down trigger
        local scope = downTrigger:GetOrCreatePrivateScriptScope()
        scope.OnStartTouch = function(args)
            -- Change the direction to move in
            if IsValidEntity(corner) then
                DoEntFireByInstanceHandle(corner, 'EnableAlternatePath', '', 0, nil, nil)
            end

            -- Start moving
            if IsValidEntity(train) then
                DoEntFireByInstanceHandle(train, 'SetSpeed', '1', 0, nil, nil)
                DoEntFireByInstanceHandle(train, 'StartForward', '', 0, nil, nil)
            end

            -- Start the movement sound
            DoEntFireByInstanceHandle(templateMoveSound, 'StopSound', '', 0, nil, nil)
            DoEntFireByInstanceHandle(templateMoveSound, 'StartSound', '', 0.01, nil, nil)

            -- Disable triggers
            DoEntFireByInstanceHandle(rightTrigger, 'Disable', '', 0, nil, nil)
            DoEntFireByInstanceHandle(downTrigger, 'Disable', '', 0, nil, nil)
        end
        downTrigger:RedirectOutput('OnStartTouch', 'OnStartTouch', downTrigger)

        -- Hook re-enabling the triggers
        local scope = templateStart:GetOrCreatePrivateScriptScope()
        scope.OnPass = function(args)
            -- Disable triggers
            DoEntFireByInstanceHandle(rightTrigger, 'Enable', '', 0, nil, nil)
            DoEntFireByInstanceHandle(downTrigger, 'Enable', '', 0, nil, nil)
        end
        templateStart:RedirectOutput('OnPass', 'OnPass', templateStart)

        -- Move into position
        if IsValidEntity(templateOrigin) then
            templateOrigin:SetOrigin(origin)
            templateOrigin:SetAngles(angles.x, angles.y, angles.z)
        end

        -- Start forward
        DoEntFireByInstanceHandle(train, 'SetSpeed', '1', 0, nil, nil)
        DoEntFireByInstanceHandle(train, 'StartForward', '', 0, nil, nil)

        -- Reset
        DoEntFireByInstanceHandle(train, 'SetSpeed', '0.2', 0.1, nil, nil)
        DoEntFireByInstanceHandle(train, 'StartBackward', '', 0.1, nil, nil)

        if callback then
            callback()
        end
    end, 0.1)
end

function Gamemode:spawnAllSliderMonsters()
    local sliderSpawners = Entities:FindAllByName('spawnSliderMonsterHere')

    local nextSpawnCallback
    local this = self
    nextSpawnCallback = function()
        if #sliderSpawners > 0 then
            local spawnLocation = table.remove(sliderSpawners, 1)

            if IsValidEntity(spawnLocation) then
                this:createSliderMonster(spawnLocation:GetOrigin(), spawnLocation:GetAnglesAsVector(), nextSpawnCallback)
            else
                nextSpawnCallback()
            end
        end
    end

    -- Start spawning
    nextSpawnCallback()
end

-- Init rooms
function Gamemode:spawnMobs()
    -- Backlog of rooms to spawn
    self.spawningRoomBackLog = {}

    -- 1: Left bat room
    self:spawnRoom({
        spawnPos = Entities:FindByName(nil, 'spawn_room_left_1'):GetOrigin(),
        enemies = {
            bats = {
                count = 3,
                createEnemy = enemyBlob,
                needsKilling = true
            }
        },
        reward = constants.reward_key
    })

    -- 1: Right skel room
    self:spawnRoom({
        spawnPos = Entities:FindByName(nil, 'spawn_room_right_1'):GetOrigin(),
        enemies = {
            skels = {
                count = 5,
                createEnemy = enemyBlob,
                needsKilling = true
            }
        },
        reward = constants.reward_key
    })

    -- 2: Mid skel room
    self:spawnRoom({
        spawnPos = Entities:FindByName(nil, 'spawn_room_mid_2'):GetOrigin(),
        enemies = {
            skels = {
                count = 3,
                createEnemy = enemyBlob,
                needsKilling = true
            }
        }
    })

    -- 3: Mid skel room
    self:spawnRoom({
        spawnPos = Entities:FindByName(nil, 'spawn_room_mid_3'):GetOrigin(),
        enemies = {
            skels = {
                count = 5,
                createEnemy = enemyBlob,
                needsKilling = true
            }
        },
        reward = constants.reward_key
    })

    -- 3: Left bat room
    self:spawnRoom({
        spawnPos = Entities:FindByName(nil, 'spawn_room_left_3'):GetOrigin(),
        enemies = {
            bats = {
                count = 6,
                createEnemy = enemyBlob,
                needsKilling = true
            }
        },
        reward = 'special_room_unlockable'
    })

    -- 3: Right bat room
    self:spawnRoom({
        spawnPos = Entities:FindByName(nil, 'spawn_room_right_3'):GetOrigin(),
        enemies = {
            bats = {
                count = 8,
                createEnemy = enemyBlob,
                needsKilling = true
            }
        },
        reward = constants.reward_compass
    })

    -- 4: Mid blob room
    self:spawnRoom({
        spawnPos = Entities:FindByName(nil, 'spawn_room_mid_4'):GetOrigin(),
        enemies = {
            blobs = {
                count = 5,
                createEnemy = enemyBlob,
                needsKilling = true
            }
        },
        reward = constants.reward_map
    })

    -- 4: Left blob room
    self:spawnRoom({
        spawnPos = Entities:FindByName(nil, 'spawn_room_left_4'):GetOrigin(),
        enemies = {
            blobs = {
                count = 3,
                createEnemy = enemyBlob,
                needsKilling = true
            }
        },
        reward = 'special_room_pushable'
    })

    -- 4: Right boomerang room
    self:spawnRoom({
        spawnPos = Entities:FindByName(nil, 'spawn_room_right_4'):GetOrigin(),
        enemies = {
            boomerangs = {
                count = 3,
                createEnemy = enemyBlob,
                needsKilling = true
            }
        },
        reward = constants.reward_boomerang
    })

    -- 4: right right hand room
    self:spawnRoom({
        spawnPos = Entities:FindByName(nil, 'spawn_room_right_right_4'):GetOrigin(),
        enemies = {
            hands = {
                count = 2,
                createEnemy = enemyBlob,
                needsKilling = true
            }
        },
        reward = constants.reward_key
    })

    -- 5: Mid skeleton room
    self:spawnRoom({
        spawnPos = Entities:FindByName(nil, 'spawn_room_mid_5'):GetOrigin(),
        enemies = {
            skels = {
                count = 3,
                createEnemy = enemyBlob,
                needsKilling = true
            }
        }
    })

    -- 6: Mid boomerang room
    self:spawnRoom({
        spawnPos = Entities:FindByName(nil, 'spawn_room_mid_6'):GetOrigin(),
        enemies = {
            boomerangs = {
                count = 3,
                createEnemy = enemyBlob,
                needsKilling = true
            }
        },
        reward = constants.reward_key
    })
end

-- Spawns a room full of enemies
function Gamemode:spawnRoom(options)
    -- Only spawn one room at a time
    if self.spawningRoom then
        table.insert(self.spawningRoomBackLog, options)
        return
    end
    self.spawningRoom = true

    local enemies = options.enemies or {}
    local spawnPos = options.spawnPos or options.rewawrdPos
    local rewawrdPos = options.rewawrdPos or options.spawnPos

    -- Create a table of the total number of mobs to spawn
    local toSpawn = {}
    for _,enemyInfo in pairs(enemies) do
        for i=1,enemyInfo.count do
            table.insert(toSpawn, enemyInfo)
        end
    end

    local this = self
    local totalEnemiesAlive = 0

    local spawnUpto = 0
    function spawnNextMob()
        spawnUpto = spawnUpto + 1
        if spawnUpto > #toSpawn then
            this.spawningRoom = false
            if #this.spawningRoomBackLog > 0 then
                this:spawnRoom(table.remove(this.spawningRoomBackLog, 1))
            end
            return
        end

        local enemyInfo = toSpawn[spawnUpto]

        local enemy = enemyInfo.createEnemy()
        enemy:init(spawnPos, function(controller)
            local needsKilling = enemyInfo.needsKilling or false

            if needsKilling then
                totalEnemiesAlive = totalEnemiesAlive + 1
            end

            controller:addCallback('onDie', function(info)
                if needsKilling then
                    totalEnemiesAlive = totalEnemiesAlive - 1

                    if totalEnemiesAlive == 0 then
                        local theReward = options.reward

                        if theReward == constants.reward_key then
                            this:createKey(info.deathOrigin + Vector(0, 0, 64))
                        end

                        -- A special reward, allows you to unlock the next room
                        if theReward == 'special_room_pushable' then
                            local breakableFloor = Entities:FindByName(nil, 'mover_two_break')
                            if breakableFloor then
                                DoEntFireByInstanceHandle(breakableFloor, 'Break', '', 0, nil, nil)
                            end
                        end

                        -- Unlock the door for killing all the enemies
                        if theReward == 'special_room_unlockable' then
                            local theDoor = Entities:FindByName(nil, 'slider_door_2a')
                            if theDoor then
                                DoEntFireByInstanceHandle(theDoor, 'Close', '', 0, nil, nil)
                            end

                            local theDoor = Entities:FindByName(nil, 'slider_door_2b')
                            if theDoor then
                                DoEntFireByInstanceHandle(theDoor, 'Close', '', 0, nil, nil)
                            end
                        end

                        -- Spawn a map
                        if theReward == constants.reward_map then
                            this:createPickupMap(info.deathOrigin)
                        end

                        -- Spawn a compass
                        if theReward == constants.reward_compass then
                            this:createPickupCompass(info.deathOrigin)
                        end

                        -- Spawn boomerang upgrade
                        if theReward == constants.reward_boomerang then
                            this:createPickupBoomerang(info.deathOrigin)
                        end
                    end
                end
            end)

            -- Start the enemy
            controller:onReady()

            -- Continue spawning
            spawnNextMob()
        end)
    end

    -- Start spawning mobs
    spawnNextMob()
end

-- Creates an explosion at the given point
function Gamemode:createExplosion(origin)
    util:spawnTemplateAndGrab('explosion_sample_template', {
            explosion = 'explosion_sample'
        }, function(parts)
            -- Create the explosion
            local explosion = parts.explosion
            explosion:SetOrigin(origin)
            DoEntFireByInstanceHandle(explosion, 'Explode', '', 0, nil, nil)

            -- Find stuff to cause damage to
            local ents = Entities:FindAllInSphere(origin, 64)
            for _,ent in pairs(ents) do
                -- Do they have an onHit callback?
                if ent.enemy then
                    if ent.enemy.onHit then
                        ent.enemy:onHit()
                    end
                end

                if ent.breakOnExplode then
                    DoEntFireByInstanceHandle(ent, 'Break', '', 0, nil, nil)
                end
            end

            -- Remove the explosion ent after a delay
            timers:setTimeout(function()
                if IsValidEntity(explosion) then
                    explosion:RemoveSelf()
                end
            end, 5)
        end)
end

-- Creates a key at the given position
function Gamemode:createKey(spawnOrigin)
    local this = self

    util:spawnTemplateAndGrab('prop_key_template', {
        model = 'prop_key',
        trigger = 'prop_key_trigger'
    }, function(parts)
        local ent = parts.model

        ent:SetOrigin(spawnOrigin)

        local itemCol = parts.trigger

        if itemCol then
            local scope = itemCol:GetOrCreatePrivateScriptScope()
            scope.OnStartTouch = function(args)
                local activator = args.activator

                -- Player
                if activator:GetClassname() == 'player' then
                    -- Collect key
                    this:onCollectKey(ent)
                end
            end
            itemCol:RedirectOutput('OnStartTouch', 'OnStartTouch', itemCol)
        end
    end)
end

-- Called when we collect a key
function Gamemode:onCollectKey(ent)
    if IsValidEntity(ent) then
        ent:RemoveSelf()
    end

    -- Increase the number of keys we have
    self.totalKeys = self.totalKeys + 1
    self.myItems[constants.item_key] = true
end

-- Handles picking up a bow
function Gamemode:handleBowPickup()
    local bowTrigger = Entities:FindByName(nil, 'trigger_collectable_bow')

    local this = self

    if bowTrigger then
        local scope = bowTrigger:GetOrCreatePrivateScriptScope()
        scope.OnStartTouch = function(args)
            local collectModel = Entities:FindByName(nil, 'collectable_arrow_rotating')

            if collectModel then
                collectModel:RemoveSelf()

                this.myItems[constants.item_bow] = true
            end
        end
        bowTrigger:RedirectOutput('OnStartTouch', 'OnStartTouch', bowTrigger)
    end
end

-- Creates a generic pickup
function Gamemode:createPickup(spawnOrigin, itemID, templateName, templateParts)
    local this = self

    util:spawnTemplateAndGrab(templateName, templateParts, function(parts)
        local ent = parts.origin

        ent:SetOrigin(spawnOrigin)

        local itemCol = parts.trigger

        if itemCol then
            local scope = itemCol:GetOrCreatePrivateScriptScope()
            scope.OnStartTouch = function(args)
                this:onCollectItem(ent, itemID)
            end
            itemCol:RedirectOutput('OnStartTouch', 'OnStartTouch', itemCol)
        end
    end)
end

-- Creates a map pickup at the given position
function Gamemode:createPickupMap(spawnOrigin)
    local this = self

    self:createPickup(spawnOrigin, function()
        -- Unlock the full map
        this:unlockFullMap()
    end, 'template_collect_map', {
        origin = 'template_collect_map_rot',
        model = 'template_collect_map_model',
        trigger = 'template_collect_map_trigger'
    })
end

-- Creates a compass pickup at the given position
function Gamemode:createPickupCompass(spawnOrigin)
    local this = self

    self:createPickup(spawnOrigin, function()
        -- We now have the compass
        this.hasCompass = true

        -- Re-render map
        this:unlockRoomsForMapEntity(this.currentMapEntity)
    end, 'template_collect_compass', {
        origin = 'template_collect_compass_rot',
        model = 'template_collect_compass_model',
        trigger = 'template_collect_compass_trigger'
    })
end

function Gamemode:createPickupBoomerang(spawnOrigin)
    local this = self

    self:createPickup(spawnOrigin, function()
        this.upgradedBoomerang = true
    end, 'template_collect_boomerang', {
        origin = 'template_collect_boomerang_rot',
        model = 'template_collect_boomerang_model',
        trigger = 'template_collect_boomerang_trigger'
    })
end

-- When we collect an item
function Gamemode:onCollectItem(ent, itemID)
    if IsValidEntity(ent) then
        ent:RemoveSelf()
    end

    if type(itemID) == 'number' then
        -- Add the item to our inventory
        self.myItems[itemID] = true
    elseif type(itemID) == 'function' then
        itemID()
    else
        print('Unknown item handle!')
    end
end

-- Called when we enter a new room
function Gamemode:onEnterRoom(name)
    -- Highlight the room
    self.currentRoom = name;

    -- Ensure the room is unlocked
    self:unlockMapRoom(name);
end

-- Unlocks a map room
function Gamemode:unlockMapRoom(name)
    -- Ensure we have a store for unlocked rooms
    self.unlockedRooms = self.unlockedRooms or {}
    self.unlockedRooms[name] = true;

    self:unlockRoomsForMapEntity(self.currentMapEntity)
end

-- Unlocks the full map
function Gamemode:unlockFullMap()
    local allRooms = {
        map_1_mid = true,
        map_1_right = true,
        map_2_mid = true,
        map_3_left = true,
        map_3_mid = true,
        map_3_right = true,
        map_4_left = true,
        map_4_left_left = true,
        map_4_mid = true,
        map_4_right = true,
        map_4_right_right = true,
        map_5_mid = true,
        map_5_right_right = true,
        map_5_right_right_right = true,
        map_6_left = true,
        map_6_mid = true
    }

    for roomName,_ in pairs(allRooms) do
        self:unlockMapRoom(roomName)
    end
end

-- Unlocks all the rooms for us
function Gamemode:unlockRoomsForMapEntity(mapEntity)
    if not self.unlockedRooms then return end
    if not mapEntity or not IsValidEntity(mapEntity) then return end

    -- Do we have the compass?
    if self.hasCompass then
        DoEntFireByInstanceHandle(mapEntity, 'AddCSSClass', 'hasCompass', 0, nil, nil)
    end

    for roomName,_ in pairs(self.unlockedRooms) do
        -- Highlight current room
        if self.currentRoom == roomName then
            DoEntFireByInstanceHandle(mapEntity, 'AddCSSClass', 'inside_' .. roomName, 0, nil, nil)
        else
            DoEntFireByInstanceHandle(mapEntity, 'RemoveCSSClass', 'inside_' .. roomName, 0, nil, nil)
        end

        -- Show this room on the map
        DoEntFireByInstanceHandle(mapEntity, 'AddCSSClass', roomName, 0, nil, nil)
    end
end

-- Export the gamemode
return Gamemode
