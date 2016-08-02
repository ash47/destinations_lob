-- Libs
local constants = require('constants')
local timers = require('util.timers')
local errorlib = require('util.errorlib')
local util = require('util')
local music = require('music')

local enemyBlob = require('enemy_blob')
local enemyBlobFast = require('enemy_blob_fast')
local enemyBoss = require('enemy_boss')

-- Define the gamemode
local Gamemode = class({})

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

    -- Store the initial spawn pos
    self.checkpointPos = Entities:FindByName(nil, 'pathGenerationMarker'):GetOrigin()

    -- Init music
    music:init()

    -- test music
    --music:playRandom()

    --self:generatePaths()
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

    -- Start music
    music:playRandom()
end

-- Gamemode think function
function Gamemode:onThink()
    -- Process game stuff
    self:handleButtons()

    -- Run again after a short delay
    return 0.1
end

-- Generates paths
function Gamemode:generatePaths(currentPath, newPathOrigin)
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

    -- If we have a current path
    if currentPath then
        currentPath:SetOrigin(Vector(0,0,-1024 * 100))
    end

    -- Create new table
    self.generatedNodes = {}

    local middle = marker:GetOrigin()

    if newPathOrigin then
        middle = newPathOrigin
        marker:SetOrigin(middle)
    end

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

    --[[for i=0,31 do
        print(i, ply:IsVRControllerButtonPressed(bit.lshift(1, i)))
    end]]

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
                    --self:killHero()
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

    --self.myItems[constants.item_bow] = true

    -- Start with 0 keys
    self.totalKeys = 0

    --self.myItems[constants.item_key] = true
    --self.totalKeys = 100
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
    local this = self

    util:spawnTemplateAndGrab('door_1_template', {
        doorA = 'door_1_door_a',
        doorB = 'door_1_door_b',
        doorC = 'door_1_door_c',
        doorD = 'door_1_door_d',

        origin = 'door_1_origin',
        trigger = 'door_1_trigger',
        lock = 'door_1_lock',
        soundUnlock = 'door_1_sound',

        solid = 'door_1_door_solid'
    }, function(parts)
        local doorParts = {
            [1] = parts.doorA,
            [2] = parts.doorB,
            [3] = parts.doorC,
            [4] = parts.doorD
        }

        local isDoorOpen = false

        local trigger = parts.trigger
        local doorOrigin = parts.origin
        local doorSound = parts.soundUnlock
        local doorLock = parts.lock
        local doorSolid = parts.solid

        -- Hook the trigger
        local scope = trigger:GetOrCreatePrivateScriptScope()
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

            -- Disable the trigger
            if IsValidEntity(trigger) then
                DoEntFireByInstanceHandle(trigger, 'Disable', '', 0, nil, nil)
            end

            -- Remove the solid part
            if IsValidEntity(doorSolid) then
                doorSolid:RemoveSelf()
            end

            for _,doorPart in pairs(doorParts) do
                -- Open the doors
                if IsValidEntity(doorPart) then
                    DoEntFireByInstanceHandle(doorPart, 'Open', '', 0.25, nil, nil)
                end
            end

            -- Recalculate paths
            this:generatePaths(this.pathRemoveNextTime)

            -- The key has now been used
            this:onKeyUsed()
        end
        trigger:RedirectOutput('OnStartTouch', 'OnStartTouch', trigger)

        -- Move into position
        if IsValidEntity(doorOrigin) then
            doorOrigin:SetOrigin(origin)
            doorOrigin:SetAngles(angles.x, angles.y, angles.z)
        end

        if callback then
            callback()
        end
    end)
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
    local this = self

    -- Spawn it
    util:spawnTemplateAndGrab('scary_monster_template', {
        corner = 'scary_monster_corner',
        rightTrigger = 'scary_monster_right_trigger',
        downTrigger = 'scary_monster_down_trigger',
        train = 'scary_monster_train',
        origin = 'scary_monster_origin',
        pathStart = 'scary_monster_start',
        pathRightEnd = 'scary_monster_right_end',
        pathDownEnd = 'scary_monster_down_end',
        soundMove = 'scary_monster_sound_move',
        soundClash = 'scary_monster_sound_clash',
        triggerClash = 'scary_monster_callback',
        triggerKillPly_down = 'scary_monster_ply_killzone_down',
        triggerKillPly_right = 'scary_monster_ply_killzone_right'
    }, function(parts)
        -- Can we activate?
        local canActivate = false
        local soundsEnabled = false
        local needsReset = false

        --[[
            The triggers to make the thing move
        ]]

        -- Hook the right trigger
        local scope = parts.rightTrigger:GetOrCreatePrivateScriptScope()
        scope.OnStartTouch = function(args)
            if not canActivate then return end
            canActivate = false

            -- Start the movement sound
            if not this.sliderMoveSound and soundsEnabled then
                DoEntFireByInstanceHandle(parts.soundMove, 'StartSound', '', 0.01, nil, nil)
                this.sliderMoveSound = true
            end

            -- Change the direction to move in
            DoEntFireByInstanceHandle(parts.corner, 'DisableAlternatePath', '', 0, nil, nil)

            -- Start moving
            DoEntFireByInstanceHandle(parts.train, 'StartForward', '', 0, nil, nil)
            DoEntFireByInstanceHandle(parts.train, 'SetSpeed', '1', 0, nil, nil)

            -- Disable triggers
            DoEntFireByInstanceHandle(parts.rightTrigger, 'Disable', '', 0, nil, nil)
            DoEntFireByInstanceHandle(parts.downTrigger, 'Disable', '', 0, nil, nil)

            -- Enable the killers
            DoEntFireByInstanceHandle(parts.triggerClash, 'Enable', '', 0, nil, nil)
            DoEntFireByInstanceHandle(parts.triggerKillPly_right, 'Enable', '', 0, nil, nil)
        end
        parts.rightTrigger:RedirectOutput('OnStartTouch', 'OnStartTouch', parts.rightTrigger)

        -- Hook the down trigger
        local scope = parts.downTrigger:GetOrCreatePrivateScriptScope()
        scope.OnStartTouch = function(args)
            if not canActivate then return end
            canActivate = false

            -- Start the movement sound
            if not this.sliderMoveSound and soundsEnabled then
                DoEntFireByInstanceHandle(parts.soundMove, 'StartSound', '', 0.01, nil, nil)
                this.sliderMoveSound = true
            end

            -- Change the direction to move in
            DoEntFireByInstanceHandle(parts.corner, 'EnableAlternatePath', '', 0, nil, nil)

            -- Start moving
            DoEntFireByInstanceHandle(parts.train, 'SetSpeed', '1', 0, nil, nil)
            DoEntFireByInstanceHandle(parts.train, 'StartForward', '', 0, nil, nil)

            -- Disable triggers
            DoEntFireByInstanceHandle(parts.rightTrigger, 'Disable', '', 0, nil, nil)
            DoEntFireByInstanceHandle(parts.downTrigger, 'Disable', '', 0, nil, nil)

            -- Enable the killers
            DoEntFireByInstanceHandle(parts.triggerClash, 'Enable', '', 0, nil, nil)
            DoEntFireByInstanceHandle(parts.triggerKillPly_down, 'Enable', '', 0, nil, nil)
        end
        parts.downTrigger:RedirectOutput('OnStartTouch', 'OnStartTouch', parts.downTrigger)

        --[[
            When the thing gets reset
        ]]

        local scope = parts.triggerClash:GetOrCreatePrivateScriptScope()
        scope.OnStartTouch = function(args)
            local activator = args.activator

            if activator:GetClassname() == 'func_tracktrain' then
                -- Clash
                DoEntFireByInstanceHandle(parts.soundMove, 'StopSound', '', 0, nil, nil)
                this.sliderMoveSound = false

                if soundsEnabled then
                    DoEntFireByInstanceHandle(parts.soundClash, 'StartSound', '', 0, nil, nil)
                end

                -- Disable killers
                DoEntFireByInstanceHandle(parts.triggerClash, 'Disable', '', 0, nil, nil)
                DoEntFireByInstanceHandle(parts.triggerKillPly_right, 'Disable', '', 0, nil, nil)
                DoEntFireByInstanceHandle(parts.triggerKillPly_down, 'Disable', '', 0, nil, nil)

                -- Reset
                DoEntFireByInstanceHandle(parts.train, 'StartBackward', '', 0, nil, nil)
                DoEntFireByInstanceHandle(parts.train, 'SetSpeed', '0.1', 0, nil, nil)

                -- We now need a reset
                needsReset = true
            end
        end
        parts.triggerClash:RedirectOutput('OnStartTouch', 'OnStartTouch', parts.triggerClash)

        --[[
            The Kill Zones
        ]]

        local scope = parts.triggerKillPly_down:GetOrCreatePrivateScriptScope()
        scope.OnStartTouch = function(args)
            local activator = args.activator

            -- Player
            if activator:GetClassname() == 'player' then
                this:killHero()
            end
        end
        parts.triggerKillPly_down:RedirectOutput('OnStartTouch', 'OnStartTouch', parts.triggerKillPly_down)

        local scope = parts.triggerKillPly_right:GetOrCreatePrivateScriptScope()
        scope.OnStartTouch = function(args)
            local activator = args.activator

            -- Player
            if activator:GetClassname() == 'player' then
                this:killHero()
            end
        end
        parts.triggerKillPly_right:RedirectOutput('OnStartTouch', 'OnStartTouch', parts.triggerKillPly_right)

        --[[
            Resetting
        ]]

        local scope = parts.pathStart:GetOrCreatePrivateScriptScope()
        scope.OnPass = function(args)
            if not needsReset then return end
            needsReset = false

            this.trapResetting = this.trapResetting or {}
            table.insert(this.trapResetting, function()
                -- Enable it again
                canActivate = true

                -- Enable triggers
                DoEntFireByInstanceHandle(parts.rightTrigger, 'Enable', '', 0, nil, nil)
                DoEntFireByInstanceHandle(parts.downTrigger, 'Enable', '', 0, nil, nil)
            end)

            -- Run callbacks
            timers:setTimeout(function()
                -- Reset callback list
                local callbacks = this.trapResetting
                this.trapResetting = {}

                -- Run all callbacks
                for _,func in pairs(callbacks) do
                    func()
                end
            end, 1)
        end
        parts.pathStart:RedirectOutput('OnPass', 'OnPass', parts.pathStart)

        --[[
            It went right to the end
        ]]

        local scope = parts.pathRightEnd:GetOrCreatePrivateScriptScope()
        scope.OnPass = function(args)
            -- Clash
            DoEntFireByInstanceHandle(parts.soundMove, 'StopSound', '', 0, nil, nil)
            this.sliderMoveSound = false

            if soundsEnabled then
                DoEntFireByInstanceHandle(parts.soundClash, 'StartSound', '', 0, nil, nil)
            end

            -- Disable killers
            DoEntFireByInstanceHandle(parts.triggerClash, 'Disable', '', 0, nil, nil)
            DoEntFireByInstanceHandle(parts.triggerKillPly_down, 'Disable', '', 0, nil, nil)
            DoEntFireByInstanceHandle(parts.triggerKillPly_right, 'Disable', '', 0, nil, nil)

            -- Reset
            DoEntFireByInstanceHandle(parts.train, 'StartBackward', '', 0, nil, nil)
            DoEntFireByInstanceHandle(parts.train, 'SetSpeed', '0.1', 0, nil, nil)

            -- We now need a reset
            needsReset = true
        end
        parts.pathRightEnd:RedirectOutput('OnPass', 'OnPass', parts.pathRightEnd)

        local scope = parts.pathDownEnd:GetOrCreatePrivateScriptScope()
        scope.OnPass = function(args)
            -- Clash
            DoEntFireByInstanceHandle(parts.soundMove, 'StopSound', '', 0, nil, nil)
            this.sliderMoveSound = false

            if soundsEnabled then
                DoEntFireByInstanceHandle(parts.soundClash, 'StartSound', '', 0, nil, nil)
            end

            -- Disable killers
            DoEntFireByInstanceHandle(parts.triggerClash, 'Disable', '', 0, nil, nil)
            DoEntFireByInstanceHandle(parts.triggerKillPly_down, 'Disable', '', 0, nil, nil)
            DoEntFireByInstanceHandle(parts.triggerKillPly_right, 'Disable', '', 0, nil, nil)

            -- Reset
            DoEntFireByInstanceHandle(parts.train, 'StartBackward', '', 0, nil, nil)
            DoEntFireByInstanceHandle(parts.train, 'SetSpeed', '0.1', 0, nil, nil)

            -- We now need a reset
            needsReset = true
        end
        parts.pathDownEnd:RedirectOutput('OnPass', 'OnPass', parts.pathDownEnd)

        --[[
            Move into position
        ]]

        -- Set origin
        parts.origin:SetOrigin(origin)
        parts.origin:SetAngles(angles.x, angles.y, angles.z)

        -- Start forward
        DoEntFireByInstanceHandle(parts.train, 'SetSpeed', '1', 0, nil, nil)
        DoEntFireByInstanceHandle(parts.train, 'StartForward', '', 0, nil, nil)

        -- Reset
        DoEntFireByInstanceHandle(parts.train, 'SetSpeed', '0.2', 0.1, nil, nil)
        DoEntFireByInstanceHandle(parts.train, 'StartBackward', '', 0.1, nil, nil)

        -- We can now activate
        canActivate = true

        -- Enable the sounds after a short delay
        timers:setTimeout(function()
            soundsEnabled = true
        end, 1)

        -- If we have a callback, run it
        if callback then
            callback()
        end
    end)
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

    -- Boss room
    self:spawnRoom({
        spawnPos = Entities:FindByName(nil, 'spawn_room_boss'):GetOrigin(),
        enemies = {
            boss = {
                count = 1,
                createEnemy = enemyBoss,
                needsKilling = true
            }
        },
        reward = 'special_unlock_boss_door'
    })


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
                createEnemy = enemyBlobFast,
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
        },
        reward = constants.reward_key
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

            if enemy.parts and enemy.parts.trigger then
                local deathTrigger = enemy.parts.trigger

                local scope = deathTrigger:GetOrCreatePrivateScriptScope()
                scope.OnStartTouch = function(args)
                    local activator = args.activator

                    -- Player
                    if activator:GetClassname() == 'player' then
                        -- Kill the player
                        this:killHero()
                    end
                end
                deathTrigger:RedirectOutput('OnStartTouch', 'OnStartTouch', deathTrigger)
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

                        -- Unlocks the boss door
                        if theReward == 'special_unlock_boss_door' then
                            local theDoor = Entities:FindByName(nil, 'slider_door_3a')
                            if theDoor then
                                DoEntFireByInstanceHandle(theDoor, 'Open', '', 0, nil, nil)
                            end

                            local theDoor = Entities:FindByName(nil, 'slider_door_3b')
                            if theDoor then
                                DoEntFireByInstanceHandle(theDoor, 'Open', '', 0, nil, nil)
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
    local this = self

    util:spawnTemplateAndGrab('explosion_sample_template', {
            explosion = 'explosion_sample'
        }, function(parts)
            -- Create the explosion
            local explosion = parts.explosion
            explosion:SetOrigin(origin)
            DoEntFireByInstanceHandle(explosion, 'Explode', '', 0, nil, nil)

            -- Play the sound
            local explodeSound = Entities:FindByName(nil, 'sound_explode')
            DoEntFireByInstanceHandle(explodeSound, 'StartSound', '', 0, nil, nil)

            local brokeSomething = false

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
                    ent:RemoveSelf()
                    brokeSomething = true
                end
            end

            -- If we broke something, regenerate the paths
            if brokeSomething then
                this:generatePaths(this.pathRemoveNextTime)
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

    -- Play a sound
    self:playCollectSound()
end

-- Plays the collect sound
function Gamemode:playCollectSound()
    -- Play the sound
    local theSound = Entities:FindByName(nil, 'sound_collect')
    DoEntFireByInstanceHandle(theSound, 'StartSound', '', 0, nil, nil)
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

                -- Play a sound
                self:playCollectSound()
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

    -- Play a sound
    self:playCollectSound()
end

-- Called when we enter a new room
function Gamemode:onEnterRoom(name)
    -- Highlight the room
    self.currentRoom = name;

    -- Ensure the room is unlocked
    self:unlockMapRoom(name);

    -- Boss start
    if name == 'map_5_right_right' then
        -- Make the boss look at the player the first time
        if _G.theBoss and _G.theBoss.lookAtPlayer then
            _G.theBoss:lookAtPlayer()
        end

        -- Set the checkpoint to the boss
        self.checkpointPos = Entities:FindByName(nil, 'checkpoint_boss_room'):GetOrigin()
    end

    -- Checkpoint before the smashers
    if name == 'map_6_mid' then
        self.checkpointPos = Entities:FindByName(nil, 'checkpoint_smashers'):GetOrigin()
    end

    -- End of game?
    if name == 'map_5_right_right_right' then
        music:onGameEnd()
    end
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

-- Kills the hero
function Gamemode:killHero()
    local hmdEnt = Entities:FindByClassname(nil, 'point_hmd_anchor')
    local marker = Entities:FindByName(nil, 'pathGenerationMarker')

    if hmdEnt and marker then
        hmdEnt:SetOrigin(self.checkpointPos)

        -- Generate the new path
        self:generatePaths(self.pathRemoveNextTime, self.checkpointPos)
    end

    -- Flash red
    local deathFade = Entities:FindByName(nil, 'death_fade')
    DoEntFireByInstanceHandle(deathFade, 'Fade', '', 0, nil, nil)

    -- Play the sound
    self.ply:EmitSound('hl1.fvox.flatline')
end

-- Export the gamemode
return Gamemode
