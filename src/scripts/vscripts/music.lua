local timers = require('util.timers')

local music = {}

function music:init()
    -- Define all the music entity names
    self.allMusic = {
        music_end = 'music_end',
        --music_song1 = 'music_song1',
        --music_song2 = 'music_song2',
        music_song3 = 'music_song3',
        music_song4 = 'music_song4',
        --music_song5 = 'music_song5',
        --music_song6 = 'music_song6',
        --music_song7 = 'music_song7',
        --music_song8 = 'music_song8',
        music_song9 = 'music_song9',
    }

    -- Load in the ents
    for k,v in pairs(self.allMusic) do
        self.allMusic[k] = Entities:FindByName(nil, v)
    end

    -- List of random songs
    self.randomSongs = {}
    --table.insert(self.randomSongs, self.allMusic.music_song1)
    --table.insert(self.randomSongs, self.allMusic.music_song2)
    table.insert(self.randomSongs, self.allMusic.music_song3)
    table.insert(self.randomSongs, self.allMusic.music_song4)
    --table.insert(self.randomSongs, self.allMusic.music_song5)
    --table.insert(self.randomSongs, self.allMusic.music_song6)
    --table.insert(self.randomSongs, self.allMusic.music_song7)
    --table.insert(self.randomSongs, self.allMusic.music_song8)
    table.insert(self.randomSongs, self.allMusic.music_song9)

    self.songLength = {
        --[self.allMusic.music_song1] = 120,
        --[self.allMusic.music_song2] = 123,
        [self.allMusic.music_song3] = 65,
        [self.allMusic.music_song4] = 73,
        --[self.allMusic.music_song5] = 120,
        --[self.allMusic.music_song6] = 120,
        --[self.allMusic.music_song7] = 120,
        --[self.allMusic.music_song8] = 120,
        [self.allMusic.music_song9] = 98,

    }
end

-- Stops all music
function music:stopAll()
    for k,v in pairs(self.allMusic) do
        DoEntFireByInstanceHandle(v, 'StopSound', '', 0, nil, nil)
    end
end

-- Plays a random song
function music:playRandom()
    -- Are we allowed to play music?
   if self.noMoreMusic and not force then return end

   local mySong = self.randomSongs[math.random(#self.randomSongs)]

   local songLength = self.songLength[mySong]

   self:playSong(mySong)

   local this = self

   if songLength ~= nil then
       timers:setTimeout(function()
            this:playRandom()
        end, songLength)
    end
end

-- Plays the given song
function music:playSong(songEnt, force)
    -- Are we allowed to play music?
   if self.noMoreMusic and not force then return end

   -- Stop all other music
   self:stopAll()

   -- Play the music after a short delay
   DoEntFireByInstanceHandle(songEnt, 'StartSound', '', 0.1, nil, nil)
end

function music:onGameEnd()
    if self.doneEndMusic then return end
    self.doneEndMusic = true

    self.noMoreMusic = true

    -- Play the end game song
    self:playSong(self.allMusic.music_end, true)
end

-- Export
return music