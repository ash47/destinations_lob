-- Define class
local Errorlib = {}

-- Called when an error occured
function Errorlib:error(msg)
    print('LOZ ERROR: ' .. msg)
end

-- A debug level log
function Errorlib:debug(msg)
    print('LOZ DEBUG: ' .. msg)
end

-- A notification level log
function Errorlib:notify(msg)
    print('LOZ: ' .. msg)
end

return Errorlib
-- Return class