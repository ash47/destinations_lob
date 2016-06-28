-- Imports
local errorlib = require('util.errorlib')
local timers = require('util.timers')
local util = require('util')

-- Define a new class
local enemyController = class({})

-- Init enemy controller
function enemyController:init(callback)
    -- Create the movement framework
    local spawner = Entities:FindByName(nil, 'template_enemy_tracks')
    DoEntFireByInstanceHandle(spawner, 'ForceSpawn', '', 0, nil, nil)

    -- Grab a reference to this entity
    local this = self

    -- How long it takes to move
    self.moveTime = 1.0

    timers:setTimeout(function()
        -- Gran the tracks
        this.origin = Entities:FindByName(nil, 'template_enemy_tracks_origin')
        this.horzTracks = Entities:FindByName(nil, 'template_enemy_tracks_horizontal')
        this.vertTracks = Entities:FindByName(nil, 'template_enemy_tracks_vertical')

        -- Store the attachment ent
        this.attachTo = this.vertTracks

        -- Do we have a callback?
        if callback then
            -- Run the callback
            callback(this)
        end
    end, 0.1)
end

-- Movement
function enemyController:east(callback)
    -- Do the movement
    DoEntFireByInstanceHandle(self.horzTracks, 'ResetPosition', '0', 0, nil, nil)
    DoEntFireByInstanceHandle(self.horzTracks, 'Open', '', 0, nil, nil)

    -- Run the callback when it moves
    timers:setTimeout(function()
        -- Check if it has a callback
        if callback then
            -- Run the callback
            callback()
        end
    end, self.moveTime)
end

function enemyController:west(callback)
    -- Do the movement
    DoEntFireByInstanceHandle(self.horzTracks, 'ResetPosition', '1', 0, nil, nil)
    DoEntFireByInstanceHandle(self.horzTracks, 'Close', '', 0, nil, nil)

    -- Run the callback when it moves
    timers:setTimeout(function()
        -- Check if it has a callback
        if callback then
            -- Run the callback
            callback()
        end
    end, self.moveTime)
end

function enemyController:north(callback)
    -- Do the movement
    DoEntFireByInstanceHandle(self.vertTracks, 'ResetPosition', '0', 0, nil, nil)
    DoEntFireByInstanceHandle(self.vertTracks, 'Open', '', 0, nil, nil)

    -- Run the callback when it moves
    timers:setTimeout(function()
        -- Check if it has a callback
        if callback then
            -- Run the callback
            callback()
        end
    end, self.moveTime)
end

function enemyController:south(callback)
    -- Do the movement
    DoEntFireByInstanceHandle(self.vertTracks, 'ResetPosition', '1', 0, nil, nil)
    DoEntFireByInstanceHandle(self.vertTracks, 'Close', '', 0, nil, nil)

    -- Run the callback when it moves
    timers:setTimeout(function()
        -- Check if it has a callback
        if callback then
            -- Run the callback
            callback()
        end
    end, self.moveTime)
end

-- Performs random movement
function enemyController:randomMovement(options)
    local this = self

    options = options or {}

    local possibleDirs = {}

    local ourPos = self.attachTo:GetOrigin()

    for i=1,4 do
        if not util:isSolid(ourPos, i) then
            table.insert(possibleDirs, i)
        end
    end

    if #possibleDirs <= 0 then
        errorlib:error('Failed to find a random direction to move in!')
        return
    end

    -- Pick a direction to walk
    local dir = possibleDirs[math.random(1, #possibleDirs)]

    local onWalkFinished = function()
        local delay = options.delay or 3

        -- Start the next movement after a delay
        timers:setTimeout(function()
            this:randomMovement()
        end, delay)
    end

    if dir == 1 then
        -- Walk north
        self:north(onWalkFinished)
    elseif dir == 2 then
        -- Walk East
        self:east(onWalkFinished)
    elseif dir == 3 then
        -- Walk South
        self:south(onWalkFinished)
    else
        -- Walk West
        self:west(onWalkFinished)
    end
end

-- Export the enemy controller
return enemyController
