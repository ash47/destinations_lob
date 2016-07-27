-- Imports
local errorlib = require('util.errorlib')
local timers = require('util.timers')
local util = require('util')

-- Define a new class
local enemyBoss = class({})

-- Init
function enemyBoss:init(_, callback)
    -- Grab a reference to this entity
    local this = self

    -- Stores callbacks for when something happens
    self.callbacks = {}

    -- Grab all references
    self.logicCharge = Entities:FindByName(nil, 'boss_logic_charge')
    self.logicWalk = Entities:FindByName(nil, 'boss_logic_walk')
    self.logicLookAtPlayer = Entities:FindByName(nil, 'boss_logic_look_at_player')
    self.logicOpenMouth = Entities:FindByName(nil, 'boss_logic_open_mouth')
    self.logicStomp = Entities:FindByName(nil, 'boss_logic_stomp')
    self.logicPain = Entities:FindByName(nil, 'boss_logic_pain')
    self.logicDie = Entities:FindByName(nil, 'boss_logic_die')

    self.triggerStomp = Entities:FindByName(nil, 'boss_trigger_stomp')
    self.triggerCharge = Entities:FindByName(nil, 'boss_trigger_charge')
    self.triggerChargeDeath = Entities:FindByName(nil, 'boss_trigger_charge_death')

    -- Body parts
    self.bossHead = Entities:FindByName(nil, 'boss_head')
    self.mainBody = Entities:FindByName(nil, 'boss_rot_body')
    self.movementWalk = Entities:FindByName(nil, 'boss_movement_walk')

    -- Store parts for external use
    self.parts = {
        trigger = self.triggerChargeDeath
    }

    -- Store the reference
    self.bossHead.enemy = self

    -- Store a reference to this boss
    _G.theBoss = self

    -- Done spawning the boss
    callback(self)
end

-- When the game is ready
function enemyBoss:onReady()
    -- Hook stuff
    self:hookTriggers()
end

-- When we are hit
function enemyBoss:onHit()
    -- Prevent spam
    if not self.canTakeDamage then return end
    self.canTakeDamage = false

    self.hp = self.hp - 1

    local this = self

    if self.hp <= 0 then
        -- Die
        DoEntFireByInstanceHandle(self.logicDie, 'Trigger', '', 0, nil, nil)

        -- Do massive explosions
        self.dead = true
        self.canPerformAction = false
        self:doMassiveExplosions()
    else
        -- Take damage
        DoEntFireByInstanceHandle(self.logicPain, 'Trigger', '', 0, nil, nil)

        -- Allow more damage after a delay
        timers:setTimeout(function()
            -- We can now take damge again
            this.canTakeDamage = true
        end, 2)
    end
end

-- Does a whole bunch of explosions to look pretty
function enemyBoss:doMassiveExplosions()
    local headPos = self.bossHead:GetOrigin()

    local maxMove = 128

    local randomExplosionDelay = function(delay)
        timers:setTimeout(function()
            _G.theGamemode:createExplosion(headPos + Vector(math.random(-maxMove, maxMove), math.random(-maxMove, maxMove), math.random(-maxMove, maxMove)))
        end, delay)
    end

    for i=1,20 do
        randomExplosionDelay(0.1 * i)
    end

    local this = self

    timers:setTimeout(function()
        -- Tell the gamemode that we died
        this:runCallback('onDie', {
            unit = this,
            deathOrigin = this.bossHead:GetOrigin()
        })

        -- Kill the boss
        this.mainBody:RemoveSelf()
        this.movementWalk:RemoveSelf()
    end, 2)
end

-- Looks at the player
function enemyBoss:lookAtPlayer()
    -- Only look at the player once
    if self.lookedAtPlayer then return end
    self.lookedAtPlayer = true

    -- Trigger the look at player
    DoEntFireByInstanceHandle(self.logicLookAtPlayer, 'Trigger', '', 0, nil, nil)

    local this = self

    -- Allow 3 seconds to look at the player
    timers:setTimeout(function()
        -- Stop ourselves from remaining idle for too long
        this:idleCheck()
    end, 3)
end

-- Hooks triggers to perform actions
function enemyBoss:hookTriggers()
    -- Can we enter into a new action?
    self.canPerformAction = true
    self.canTakeDamage = true
    self.hp = 10

    local this = self

    -- Charge Trigger
    local scope = self.triggerCharge:GetOrCreatePrivateScriptScope()
    scope.OnStartTouch = function(args)
        -- Only handle players
        if not args.activator:GetClassname() == 'player' then return end

        this:performCharge()
    end
    self.triggerCharge:RedirectOutput('OnStartTouch', 'OnStartTouch', self.triggerCharge)

    -- Stomp Trigger
    local scope = self.triggerStomp:GetOrCreatePrivateScriptScope()
    scope.OnStartTouch = function(args)
        -- Only handle players
        if not args.activator:GetClassname() == 'player' then return end

        -- The stomp will kill
        this.stompWillKill = true

        this:performStompAttack()
    end
    self.triggerStomp:RedirectOutput('OnStartTouch', 'OnStartTouch', self.triggerStomp)

    -- Stomp - player moves to safety
    scope.OnEndTouch = function(args)
        -- Only handle players
        if not args.activator:GetClassname() == 'player' then return end

        -- The stomp will kill
        this.stompWillKill = false
    end
    self.triggerStomp:RedirectOutput('OnEndTouch', 'OnEndTouch', self.triggerStomp)
end

-- Performs general walking
function enemyBoss:performWalk()
    if not self.canPerformAction then return end
    if self.wontPerformWalk then return end
    if self.dead then return end
    self.canPerformAction = false
    self.performingWalk = true
    self.wontPerformWalk = true

    local this = self

    -- Perform the walking
    DoEntFireByInstanceHandle(self.logicWalk, 'Trigger', '', 0, nil, nil)

    -- Allow time for the walk to be performed
    timers:setTimeout(function()
        -- We can now perform an action
        this.canPerformAction = true
        this.performingWalk = false

        -- Stop ourselves from remaining idle for too long
        this:idleCheck()
    end, 20)

    -- Wait before considering walking again
    timers:setTimeout(function()
        -- We will now consider performing a charge again
        this.wontPerformWalk = false
    end, 30)
end

-- Performs a stomp attack
function enemyBoss:performStompAttack()
    -- Can stomp during other actions, as long as not charging
    if self.performingCharge then return end
    if self.wontPerformStomp then return end
    if self.dead then return end
    self.canPerformAction = false
    self.wontPerformStomp = true
    self.performingStomp = true

    local this = self

    -- Perform the charge
    DoEntFireByInstanceHandle(self.logicStomp, 'Trigger', '', 0, nil, nil)

    -- Allow 2.5 seconds for the stomp to be performed
    timers:setTimeout(function()
        -- We can now perform an action
        this.canPerformAction = true
        this.performingStomp = false

        -- Should it kill the player?
        if this.stompWillKill then
            this.stompWillKill = false
            theGamemode:killHero()
        end

        -- Stop ourselves from remaining idle for too long
        this:idleCheck()
    end, 2.5)

    -- Wait at least 5 seconds before considering another stomp
    timers:setTimeout(function()
        -- We will now consider performing a charge again
        this.wontPerformStomp = false
    end, 10)
end

-- Performs a charge attack
function enemyBoss:performCharge()
    if not self.canPerformAction then return end
    if self.wontPerformCharge then return end
    if self.dead then return end
    self.canPerformAction = false
    self.wontPerformCharge = true
    self.performingCharge = true

    local this = self

    -- Perform the charge
    DoEntFireByInstanceHandle(self.logicCharge, 'Trigger', '', 0, nil, nil)

    -- Allow 10 seconds for the charge to be performed
    timers:setTimeout(function()
        -- We can now perform an action
        this.canPerformAction = true
        this.performingCharge = false

        -- Stop ourselves from remaining idle for too long
        this:idleCheck()
    end, 10)

    -- Wait at least 15 seconds before considering another charge
    timers:setTimeout(function()
        -- We will now consider performing a charge again
        this.wontPerformCharge = false
    end, 20)
end

-- Stops us from remaining idle for too long
function enemyBoss:idleCheck()
    if self.dead then return end

    -- Used to check if this was the last action performed or not
    self.actionCount = (self.actionCount or 0) + 1
    local myActionNumber = self.actionCount

    -- Can we even perform an action?
    if not self.canPerformAction then return end

    local this = self

    -- Don't remain idle for more than 5 seconds
    timers:setTimeout(function()
        -- Have we started something since we last checked?
        if not this.canPerformAction then return end

        -- Is this timer still relevant
        if this.actionCount ~= myActionNumber then return end

        -- Perform a random action
        this:performRandomAction()
    end, 2.5)
end

-- Performs a random action
function enemyBoss:performRandomAction()
    if self.dead then return end

    local opts = {}

    -- Can we walk?
    if not self.wontPerformWalk then table.insert(opts, 'walk') end

    -- Can we charge?
    if not self.wontPerformCharge then table.insert(opts, 'charge') end

    -- Can we stomp?
    if not self.wontPerformStomp then table.insert(opts, 'stomp') end

    if #opts == 0 then
        -- Check again for idle issues
        self:idleCheck()
    else
        local action = opts[math.random(#opts)]

        if action == 'walk' then
            self:performWalk()
        elseif action == 'charge' then
            self:performCharge()
        elseif action == 'stomp' then
            self:performStompAttack()
        end
    end
end

-- Adds a callback
function enemyBoss:addCallback(event, callback)
    self.callbacks[event] = self.callbacks[event] or {}
    table.insert(self.callbacks[event], callback)
end

-- Runs an event callback
function enemyBoss:runCallback(event, data)
    if self.callbacks[event] then
        for _,callback in pairs(self.callbacks[event]) do
            callback(data)
        end
    end
end

-- Export the boss
return enemyBoss