-- Libs
local constants = require('constants')
local timers = require('util.timers')
local errorlib = require('util.errorlib')

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

    -- Generate paths
    self:generatePaths()

    --print(self.tpDevice0)

    --DeepPrintTable(getmetatable(self.tpDevice0))

    -- Try out a sword
    --self:swordTest()

    -- Start thinking
    timers:setTimeout('onThink', 0.1, self)

    -- All good
    errorlib:notify('Gamemode has started successfully!')
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

    -- Spawn new nodes
    --table.insert(self.generatedNodes, self:generatePathNode(middle))
    table.insert(self.generatedNodes, self:generatePathNode(middle + Vector(128, 0, 0)))
    table.insert(self.generatedNodes, self:generatePathNode(middle + Vector(-128, 0, 0)))
    table.insert(self.generatedNodes, self:generatePathNode(middle + Vector(0, 128, 0)))
    table.insert(self.generatedNodes, self:generatePathNode(middle + Vector(0, -128, 0)))
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
        print('onTeleport!')

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

                    self:spawnMelon(handID)
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
        [2] = constants.item_sword
    }

    -- Define the reverse lookup table
    self.reverseItemOrder = {}
    for posNum, itemID in pairs(self.itemOrderList) do
        self.reverseItemOrder[itemID] = posNum
    end

    -- Defines which items we actually own
    self.myItems = {}

    -- DEBUG: Give all items
    for posNum, itemID in pairs(self.itemOrderList) do
        self.myItems[itemID] = true
    end
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
    while true do
        local tempItemID = self.itemOrderList[nextItemID]
        if tempItemID then
            if self.myItems[tempItemID] then
                -- Found the next item
                break
            else
                nextItemID = nextItemID + 1
            end
        else
            nextItemID = 1
        end
    end

    -- Put this item into our hand
    self:setHandItem(handID, nextItemID)
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

    -- Destroy old item
    local oldItem = self['entityItem' .. handID]
    if oldItem then
        oldItem:RemoveSelf()
        self['entityItem' .. handID] = nil
    end

    -- Create the new item
    local item = self:createHandItem(itemID)

    if item then
        -- Store it
        self['entityItem' .. handID] = item

        local angles = hand:GetAnglesAsVector()

        -- Attach
        item:SetOrigin(hand:GetOrigin())
        item:SetParent(hand, '')
        item:SetAngles(angles.x, angles.y, angles.z)
    end

    -- Store the ID that is now in our hand
    self['hand' .. handID .. 'Item'] = itemID
end

-- Creates an instance of a given item
function Gamemode:createHandItem(itemID)
    if itemID == constants.item_sword then
        local ent = Entities:CreateByClassname('prop_physics')
        ent:SetModel('models/weapons/sword1/sword1.vmdl')

        local mins = ent:GetBoundingMins()
        local maxs = ent:GetBoundingMaxs()

        local trigger = CreateTrigger(mins, maxs, Vector(0, 0, 0))
        trigger:SetParent(ent, '')


        trigger.test = function()
            print('ttest')
        end

        trigger:ConnectOutput('OnStartTouch', 'test')


        return ent
    end
end

-- Sword debug function
function Gamemode:swordTest()
    -- Grab hand
    local hand0 = self.hand0
    local angles = hand0:GetAnglesAsVector()

    --self.tpDevice0:SetModel('models/weapons/sword1/sword1.vmdl')
    --self.hand0:SetModel('models/weapons/sword1/sword1.vmdl')

    -- Remove old item
    --hand0:SetHandAttachment(nil)

    -- Create the sword
    --[[local ent = Entities:CreateByClassname('prop_physics')
    ent:SetModel('models/weapons/sword1/sword1.vmdl')
    ent:SetOrigin(hand0:GetOrigin())
    ent:SetParent(hand0, '')
    ent:SetAngles(angles.x, angles.y, angles.z)]]
end

-- Export the gamemode
return Gamemode
