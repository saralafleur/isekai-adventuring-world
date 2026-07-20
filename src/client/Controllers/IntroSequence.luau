--!strict
-- Opening beat: the Chronicler narrates the backstory over black, one phrase at
-- a time, then hands over to the flyby. Each phrase is shown while its own clip
-- plays and gives way when the clip ends, so text and voice stay in step
-- without any hardcoded timing. Clicking skips the whole narration.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Prologue = require(Shared.Data.Prologue)
local VoiceLines = require(Shared.Data.VoiceLines)

local player = Players.LocalPlayer

local FADE = 0.8
-- beat of silence between phrases, so the narration breathes
local GAP = 0.35

local IntroSequence = {}

-- Plays the narration over black. If keepBlack is true the black overlay is
-- returned (still opaque) instead of fading out — the flyby cinematic that
-- follows owns the fade-in.
function IntroSequence.play(keepBlack: boolean?): ScreenGui?
	local gui = Instance.new("ScreenGui")
	gui.Name = "IntroGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 100

	local black = Instance.new("Frame")
	black.Size = UDim2.fromScale(1, 1)
	black.BackgroundColor3 = Color3.new(0, 0, 0)
	black.Parent = gui

	local line = Instance.new("TextLabel")
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Position = UDim2.fromScale(0.5, 0.5)
	line.Size = UDim2.new(0.8, 0, 0, 120)
	line.BackgroundTransparency = 1
	line.TextColor3 = Color3.fromRGB(220, 220, 230)
	line.Font = Enum.Font.Merriweather
	line.TextSize = 28
	line.TextWrapped = true
	line.TextTransparency = 1
	line.Text = ""
	line.Parent = black

	local hint = Instance.new("TextLabel")
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -30)
	hint.Size = UDim2.new(0.5, 0, 0, 20)
	hint.BackgroundTransparency = 1
	hint.TextColor3 = Color3.fromRGB(120, 120, 130)
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 14
	hint.Text = "Click to skip"
	hint.TextTransparency = 1
	hint.Parent = black

	gui.Parent = player:WaitForChild("PlayerGui")

	-- The narrator is not in the world, so the clip plays flat from
	-- SoundService rather than positionally from a character's head.
	local voice = Instance.new("Sound")
	voice.Name = "NarratorVoice"
	voice.Volume = 1
	voice.Parent = SoundService

	local skipped = false
	local conn: RBXScriptConnection
	conn = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.E
		then
			skipped = true
		end
	end)

	-- Waits out `seconds`, returning early the moment the player skips.
	local function waitOrSkip(seconds: number)
		local elapsed = 0
		while elapsed < seconds and not skipped do
			elapsed += task.wait()
		end
	end

	task.wait(1)
	TweenService:Create(hint, TweenInfo.new(1), { TextTransparency = 0.4 }):Play()

	for _, entry in Prologue do
		if skipped then
			break
		end

		line.Text = entry.text
		line.TextTransparency = 1
		TweenService:Create(line, TweenInfo.new(FADE), { TextTransparency = 0 }):Play()

		local assetId = VoiceLines[`Prologue__{entry.key}__1`]
		if assetId and assetId > 0 then
			voice.SoundId = `rbxassetid://{assetId}`
			voice.TimePosition = 0
			voice:Play()
			-- TimeLength is 0 until the asset streams in; wait for it, but not
			-- forever — an unmoderated or failed clip must not stall the intro.
			local waited = 0
			while voice.TimeLength == 0 and waited < 2 and not skipped do
				waited += task.wait()
			end
			if voice.TimeLength > 0 then
				waitOrSkip(voice.TimeLength - voice.TimePosition)
			else
				waitOrSkip(entry.hold)
			end
		else
			-- no clip uploaded for this line: fall back to reading time
			waitOrSkip(entry.hold)
		end

		voice:Stop()
		TweenService:Create(line, TweenInfo.new(FADE * 0.5), { TextTransparency = 1 }):Play()
		waitOrSkip(GAP)
	end

	conn:Disconnect()
	voice:Stop()
	voice:Destroy()

	TweenService:Create(line, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
	TweenService:Create(hint, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
	task.wait(0.5)

	if keepBlack then
		return gui
	end

	local fadeOut = TweenService:Create(black, TweenInfo.new(2), { BackgroundTransparency = 1 })
	fadeOut:Play()
	fadeOut.Completed:Wait()
	gui:Destroy()
	return nil
end

return IntroSequence
