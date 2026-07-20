--!strict
-- Spoken dialogue. Each character gets an AudioTextToSpeech wired into an
-- AudioEmitter on their head, so lines are heard positionally — you hear Mira
-- from where Mira is standing, and the voice falls off with distance.
--
-- Characters are told apart by pitch and pace rather than by VoiceId: the
-- available voice ids are a server-side catalogue we can't enumerate from
-- here, so leaving VoiceId empty uses the default voice and the profile
-- below shapes it. Set `voiceId` in a profile once you know a specific id.

local VoiceLines = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Data.VoiceLines)

local Voice = {}

export type Profile = { pitch: number, speed: number, volume: number?, voiceId: string? }

local PROFILES: { [string]: Profile } = {
	-- Mother: warm, a touch higher, unhurried
	Mira = { pitch = 1.18, speed = 0.98 },
	-- Father: low and deliberate — he says little and means it
	Daren = { pitch = 0.78, speed = 0.88 },
	-- Kael himself (the player's own lines)
	Kael = { pitch = 1.08, speed = 1.0 },
	-- Village baker: brisk and cheerful
	["Baker Hobb"] = { pitch = 0.92, speed = 1.08 },
	["Elder Bram"] = { pitch = 0.72, speed = 0.82 },
	Tarin = { pitch = 1.12, speed = 1.12 },
	Lyra = { pitch = 1.25, speed = 1.0 },
}

local DEFAULT: Profile = { pitch = 1, speed = 1 }

-- Roblox text-to-speech is a cloud service billed to a universe. In an
-- unpublished place (universeId 0) every request comes back empty with
-- `remainingQuota: null`, so speech is silent through no fault of the code.
-- Warn once, clearly, rather than spamming a line per spoken sentence.
local warnedUnavailable = false
local function warnUnavailable(detail: string)
	if warnedUnavailable then
		return
	end
	warnedUnavailable = true
	warn(
		"[Voice] Text-to-speech returned no audio (" .. detail .. "). "
			.. "Roblox TTS requires a PUBLISHED experience — in an unpublished place it "
			.. "always fails. Prefer the pre-recorded clips: generate with "
			.. "scripts/generate-voice-lines.py, upload audio/lines/*.mp3, and put the asset "
			.. "ids in src/shared/Data/VoiceLines.luau. Dialogue works silently until then."
	)
end

-- One TTS rig per model, built lazily and reused.
local rigs: { [Model]: AudioTextToSpeech } = {}
setmetatable(rigs :: any, { __mode = "k" })

local function rigFor(model: Model): AudioTextToSpeech?
	local existing = rigs[model]
	if existing and existing.Parent then
		return existing
	end

	local head = model:FindFirstChild("Head") or model.PrimaryPart
	if not head or not head:IsA("BasePart") then
		return nil
	end

	local ok, tts = pcall(function()
		local speech = Instance.new("AudioTextToSpeech")
		speech.Volume = 3
		speech.Parent = head

		local emitter = Instance.new("AudioEmitter")
		emitter.Parent = head

		local wire = Instance.new("Wire")
		wire.SourceInstance = speech
		wire.SourceName = "Output"
		wire.TargetInstance = emitter
		wire.TargetName = "Input"
		wire.Parent = head

		return speech
	end)
	if not ok or not tts then
		warn(`[Voice] could not build a TTS rig for {model.Name}`)
		return nil
	end

	rigs[model] = tts
	return tts
end

-- Pre-recorded clips are the primary path: they cost nothing per play, need no
-- quota, and work in an unpublished place. One Sound per model, reused.
local clips: { [Model]: Sound } = {}
setmetatable(clips :: any, { __mode = "k" })

local function playClip(model: Model, assetId: number): boolean
	local head = model:FindFirstChild("Head") or model.PrimaryPart
	if not head or not head:IsA("BasePart") then
		return false
	end
	local existing = clips[model]
	local sound: Sound
	if existing and existing.Parent then
		sound = existing
	else
		sound = Instance.new("Sound")
		sound.Name = "VoiceClip"
		sound.RollOffMaxDistance = 70
		sound.RollOffMinDistance = 8
		sound.Volume = 3
		sound.Parent = head
		clips[model] = sound
	end
	-- the clip is already voiced by its own speaker, so it plays unaltered
	sound.SoundId = `rbxassetid://{assetId}`
	sound:Play()
	return true
end

-- Speaks `text` from `model` in `speaker`'s voice. `lineKey` selects a
-- pre-recorded clip when one has been uploaded. Non-blocking; a new line
-- interrupts the previous so dialogue keeps pace with the player clicking.
function Voice.speak(model: Model, speaker: string, text: string, lineKey: string?)
	-- stop whatever this character was saying
	local playing = clips[model]
	if playing and playing.IsPlaying then
		playing:Stop()
	end

	local assetId = if lineKey then VoiceLines[lineKey] else nil
	if assetId and assetId > 0 and playClip(model, assetId) then
		return
	end

	local tts = rigFor(model)
	if not tts then
		return
	end
	local profile = PROFILES[speaker] or DEFAULT
	tts.Pitch = profile.pitch
	tts.Speed = profile.speed
	if profile.volume then
		tts.Volume = profile.volume
	end
	if profile.voiceId then
		tts.VoiceId = profile.voiceId
	end

	task.spawn(function()
		if tts.IsPlaying then
			pcall(function()
				tts:Pause()
			end)
		end
		tts.Text = text
		-- LoadAsync returns an AssetFetchStatus; a pcall success does NOT mean
		-- the speech actually loaded, so check the status itself.
		local ok, status = pcall(function()
			return tts:LoadAsync()
		end)
		if not ok then
			warn(`[Voice] {speaker}: LoadAsync errored — {status}`)
			return
		end
		if status ~= Enum.AssetFetchStatus.Success then
			warnUnavailable(`status {tostring(status)}`)
			return
		end
		-- LoadAsync can report Success while the cloud fetch still yields nothing,
		-- so confirm audio actually arrived before trying to play it.
		if not tts.IsLoaded then
			warnUnavailable("no audio returned")
			return
		end
		if tts.Parent then
			local played = pcall(function()
				tts:Play()
			end)
			if not played then
				warn(`[Voice] {speaker}: Play() failed`)
			end
		end
	end)
end

function Voice.stop(model: Model)
	local clip = clips[model]
	if clip and clip.IsPlaying then
		clip:Stop()
	end
	local tts = rigs[model]
	if tts and tts.IsPlaying then
		pcall(function()
			tts:Pause()
		end)
	end
end

return Voice
