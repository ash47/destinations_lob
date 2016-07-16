-- Imports
local errorlib = require('util.errorlib')
local timers = require('util.timers')
local util = require('util')

-- Define a new class
local enemyController = class({})

-- Init enemy controller
function enemyController:init(startingPos, callback)
    -- Create the movement framework
    local spawner = Entities:FindByName(nil, 'template_enemy_tracks')
    DoEntFireByInstanceHandle(spawner, 'ForceSpawn', '', 0, nil, nil)

    -- Grab a reference to this entity
    local this = self

    -- How long it takes to move
    self.moveTime = 1.0

    -- Default amount of life
    self.hp = 3

    -- We are not dead
    self.dead = false

    -- Stores callbacks for when something happens
    self.callbacks = {}

    timers:setTimeout(function()
        -- Gran the tracks
        this.origin = Entities:FindByName(nil, 'template_enemy_tracks_origin')
        this.horzTracks = Entities:FindByName(nil, 'template_enemy_tracks_horizontal')
        this.vertTracks = Entities:FindByName(nil, 'template_enemy_tracks_vertical')

        -- Store the attachment ent
        this.attachTo = this.vertTracks

        -- Move it into position
        this.origin:SetOrigin(startingPos)

        -- Call sub init stuff
        if this.subInit then
            this:subInit(callback)
        else
            -- Do we have a callback?
            if callback then
                -- Run the callback
                callback(this)
            end
        end
    end, 0.1)


end

-- Adds a callback
function enemyController:addCallback(event, callback)
    self.callbacks[event] = self.callbacks[event] or {}
    table.insert(self.callbacks[event], callback)
end

-- Runs an event callback
function enemyController:runCallback(event, data)
    if self.callbacks[event] then
        for _,callback in pairs(self.callbacks[event]) do
            callback(data)
        end
    end
end

-- Movement
function enemyController:east(callback)
    if self.dead then return end

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
    if self.dead then return end

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
    if self.dead then return end

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
    if self.dead then return end

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

-- When this enemy is hit
function enemyController:onHit()
    if self.dead then return end

    local this = self

    -- Prevent Instant Death
    if self.cantHurt then return end
    self.cantHurt = true

    timers:setTimeout(function()
        this.cantHurt = false
    end, 0.1)

    -- Take damage
    self.hp = self.hp - 1

    if self.hp <= 0 then
        local deathOrigin = self.attachTo:GetOrigin()

        -- Kill self
        self.dead = true
        self.origin:RemoveSelf()

        -- Run any callbacks
        self:runCallback('onDie', {
            unit = self,
            deathOrigin = deathOrigin
        })

        return
    end

    -- Move away when hit
    local ply = Entities:FindByClassname(nil, 'player')
    if not ply then return end

    local plyPos = ply:GetOrigin()
    local ourPos = self.attachTo:GetOrigin()

    local dif = plyPos - ourPos

    local backx = false
    local backy = false

    if math.abs(dif.x) > 32 then
        backx = true
    end

    if math.abs(dif.y) > 32 then
        backy = true
    end

    if not backx and not backy then
        if math.abs(dif.x) > math.abs(dif.y) then
            backx = true
        else
            backy = true
        end
    end

    ourPos = ourPos + Vector(0, 0, 64)

    if backx then
        if dif.x < 0 then
            if not util:isSolid(ourPos, 2, 64) and not util:isSolid(ourPos, 2, 128) and not util:isSolid(ourPos, 2, 256) then
                self:east()
            end
        else
            if not util:isSolid(ourPos, 4, 64) and not util:isSolid(ourPos, 4, 128) and not util:isSolid(ourPos, 4, 256) then
                self:west()
            end
        end
    end

    if backy then
        if dif.y > 0 then
            if not util:isSolid(ourPos, 3, 64) and not util:isSolid(ourPos, 3, 128) and not util:isSolid(ourPos, 3, 256) then
                self:south()
            end
        else
            if not util:isSolid(ourPos, 1, 64) and not util:isSolid(ourPos, 1, 128) and not util:isSolid(ourPos, 1, 256) then
                self:north()
            end
        end
    end
end

-- Performs random movement
function enemyController:doMovement(options)
    if self.dead then return end

    local this = self

    options = options or {}

    local possibleDirs = {}

    local ourPos = self.attachTo:GetOrigin() + Vector(0, 0, 64)
    for i=1,4 do
        if not util:isSolid(ourPos, i, 64) and not util:isSolid(ourPos, i, 128) and not util:isSolid(ourPos, i, 256) then
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
            this:doMovement(options)
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

-- Called when the game is ready for this mob to come alive
function enemyController:onReady()
end

-- Export the enemy controller
return enemyController
