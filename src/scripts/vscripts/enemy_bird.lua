-- Imports
local errorlib = require('util.errorlib')
local timers = require('util.timers')
local util = require('util')
local enemyController = require('enemy_controller')

-- Define a new class
local enemyBird = class(enemyController)

function enemyBird:subInit(callback)
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

-- Return the new enemy
return enemyBird