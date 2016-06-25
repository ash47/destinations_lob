local worldSpawn

-- Create the class
local Timers = {}

function Timers:setTimeout(callback, delay, args)
    if not worldSpawn then
        worldSpawn = Entities:FindByClassname(nil, 'worldspawn')

        if not worldSpawn then
            print('ERROR: Timer failed to get worldspawn!')
            return
        end
    end

    -- Create a name for this timer
    local timerName = DoUniqueString('timer')

    -- Add the timer
    worldSpawn:SetThink(callback, args, timerName, delay)

    -- Return a refernce so the timer can be killed later
    return timerName
end

-- Define the export
return Timers
