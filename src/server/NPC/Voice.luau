--!strict
-- Spoken dialogue. Each character gets an AudioTextToSpeech wired into an
-- AudioEmitter on their head, so lines are heard positionally — you hear Mira
-- from where Mira is standing, and the voice falls off with distance.
--
-- Characters are told apart by pitch and pace rather than by VoiceId: the
-- available voice ids are a server-side catalogue we can't enumerate from
-- here, so leaving VoiceId empty uses the default voice and the profile
-- below shapes it. Set `voiceId` in a profile once you know a specific id.

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

-- Speaks `text` from `model`, in `speaker`'s voice. Non-blocking; a new line
-- interrupts the previous one so dialogue keeps pace with the player clicking.
function Voice.speak(model: Model, speaker: string, text: string)
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
			warn(`[Voice] {speaker}: speech did not load (status {tostring(status)}). `
				.. "Text-to-speech may need enabling for this experience.")
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
	local tts = rigs[model]
	if tts and tts.IsPlaying then
		pcall(function()
			tts:Pause()
		end)
	end
end

return Voice
