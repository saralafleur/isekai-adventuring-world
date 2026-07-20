--!strict
-- Background music: a fantasy title theme through the title screen, monologue
-- and flyby, crossfading into a calmer village theme for gameplay.
-- Tracks are licensed Creator Store music (swappable asset IDs).

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local TITLE_THEME = "rbxassetid://120826832167033" -- "Legends in Flow"
local VILLAGE_THEME = "rbxassetid://136984033293818" -- "Heart Of Wood" (Celtic)

local TITLE_VOLUME = 0.45
local VILLAGE_VOLUME = 0.3

local MusicController = {}

local titleSound: Sound
local villageSound: Sound

local function makeTrack(name: string, id: string): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.Looped = true
	sound.Volume = 0
	sound.Parent = SoundService
	return sound
end

function MusicController.init()
	titleSound = makeTrack("TitleTheme", TITLE_THEME)
	villageSound = makeTrack("VillageTheme", VILLAGE_THEME)
end

function MusicController.playTitle()
	titleSound:Play()
	TweenService:Create(titleSound, TweenInfo.new(2), { Volume = TITLE_VOLUME }):Play()
end

-- Crossfade from the title theme into the village ambience
function MusicController.toVillage()
	local fadeOut = TweenService:Create(titleSound, TweenInfo.new(3), { Volume = 0 })
	fadeOut:Play()
	fadeOut.Completed:Once(function()
		titleSound:Stop()
	end)
	villageSound:Play()
	TweenService:Create(villageSound, TweenInfo.new(3), { Volume = VILLAGE_VOLUME }):Play()
end

return MusicController
