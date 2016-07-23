-- Imports
local errorlib = require('util.errorlib')
local timers = require('util.timers')
local util = require('util')
local enemyController = require('enemy_controller')

-- Define a new class
local enemyBlobFast = class(enemyController)

function enemyBlobFast:subInit(callback)
    local this = self

    -- Only three hits to kill this guy
    self.hp = 3

    util:spawnTemplateAndGrab('template_enemy_blob_template', {
        origin = 'template_enemy_blob_origin',
        model = 'template_enemy_blob_model',
        trigger = 'template_enemy_blob_kill_zone'
    }, function(parts)
        -- Move the model into place
        parts.origin:SetParent(this.attachTo, '')
        parts.origin:SetOrigin(this.attachTo:GetOrigin())

        -- Store the enemy reference
        parts.model.enemy = this

        -- Store the parts
        this.parts = parts

        -- Run the callback
        if callback then
            callback(this)
        end
    end)
end

function enemyBlobFast:onReady()
    -- Start moving
    self:doMovement({
        delay = 1
    })
end

-- Return the new enemy
return enemyBlobFast