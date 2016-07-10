-- Imports
local errorlib = require('util.errorlib')
local timers = require('util.timers')
local util = require('util')
local enemyController = require('enemy_controller')

-- Define a new class
local enemyBlob = class(enemyController)

function enemyBlob:subInit(callback)
    local this = self

    -- Only two hits to kill this guy
    self.hp = 2

    util:spawnTemplateAndGrab('template_enemy_blob_template', {
        origin = 'template_enemy_blob_origin',
        model = 'template_enemy_blob_model'
    }, function(parts)
        -- Move the model into place
        parts.origin:SetParent(this.attachTo, '')
        parts.origin:SetOrigin(this.attachTo:GetOrigin())

        -- Store the enemy reference
        parts.model.enemy = this

        -- Run the callback
        if callback then
            callback(this)
        end
    end)
end

function enemyBlob:onReady()
    -- Start moving
    self:doMovement({
        delay = 3
    })
end

-- Return the new enemy
return enemyBlob