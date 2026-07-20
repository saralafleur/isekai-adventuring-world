--!strict
-- Opening flyby: after the monologue, the camera sweeps over the whole village
-- (farm hamlet, fields, windmill, market plaza, town hall) and then descends
-- to the Rowan cottage, ending behind the player. Skippable with a click.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local FlybyCinematic = {}

type Keyframe = { pos: Vector3, look: Vector3, duration: number }

local KEYFRAMES: { Keyframe } = {
	-- start high over the southern farmland (set instantly, screen still black)
	{ pos = Vector3.new(0, 150, -230), look = Vector3.new(0, 0, -40), duration = 0 },
	{ pos = Vector3.new(-130, 70, -120), look = Vector3.new(-85, 8, -110), duration = 4.5 }, -- fields + windmill
	{ pos = Vector3.new(-25, 35, -80), look = Vector3.new(0, 6, -40), duration = 4 }, -- the cottage
	{ pos = Vector3.new(0, 42, -5), look = Vector3.new(0, 4, 50), duration = 3.5 }, -- up the road
	{ pos = Vector3.new(48, 30, 50), look = Vector3.new(0, 6, 52), duration = 3.5 }, -- market plaza + guilds
	{ pos = Vector3.new(0, 58, 168), look = Vector3.new(0, 18, 120), duration = 4 }, -- town hall
	{ pos = Vector3.new(-60, 45, 55), look = Vector3.new(-15, 5, 15), duration = 3.5 }, -- sweep back west
}

function FlybyCinematic.play(blackGui: ScreenGui?)
	local camera = workspace.CurrentCamera
	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart

	-- Hold the player still during the cinematic
	root.Anchored = true
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(KEYFRAMES[1].pos, KEYFRAMES[1].look)

	-- Skip support
	local skipped = false
	local skipHint: ScreenGui? = nil
	do
		local gui = Instance.new("ScreenGui")
		gui.Name = "FlybySkipGui"
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 90
		local label = Instance.new("TextLabel")
		label.AnchorPoint = Vector2.new(1, 1)
		label.Position = UDim2.new(1, -24, 1, -20)
		label.Size = UDim2.fromOffset(220, 24)
		label.BackgroundTransparency = 1
		label.Text = "Click to skip"
		label.TextXAlignment = Enum.TextXAlignment.Right
		label.TextColor3 = Color3.fromRGB(230, 230, 230)
		label.TextStrokeTransparency = 0.5
		label.Font = Enum.Font.Gotham
		label.TextSize = 16
		label.Parent = gui
		gui.Parent = player:WaitForChild("PlayerGui")
		skipHint = gui
	end
	local conn = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			skipped = true
		end
	end)

	-- Fade in from black while the first sweep is already moving
	if blackGui then
		local frame = blackGui:FindFirstChildOfClass("Frame")
		if frame then
			local fade = TweenService:Create(frame, TweenInfo.new(2), { BackgroundTransparency = 1 })
			fade:Play()
			task.delay(2.1, function()
				blackGui:Destroy()
			end)
		end
	end

	-- Fly the keyframe route
	for index = 2, #KEYFRAMES do
		if skipped then
			break
		end
		local kf = KEYFRAMES[index]
		local tween = TweenService:Create(
			camera,
			TweenInfo.new(kf.duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
			{ CFrame = CFrame.lookAt(kf.pos, kf.look) }
		)
		tween:Play()
		local done = false
		tween.Completed:Once(function()
			done = true
		end)
		while not done and not skipped do
			task.wait()
		end
		if skipped then
			tween:Cancel()
		end
	end

	-- Final descent to the player at the cottage (also plays when skipping,
	-- shortened, so the transition never pops)
	local home = CFrame.lookAt(root.Position + Vector3.new(2, 12, 16), root.Position)
	local descent = TweenService:Create(
		camera,
		TweenInfo.new(if skipped then 1.2 else 3.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ CFrame = home }
	)
	descent:Play()
	descent.Completed:Wait()

	conn:Disconnect()
	if skipHint then
		skipHint:Destroy()
	end
	camera.CameraType = Enum.CameraType.Custom
	root.Anchored = false
end

return FlybyCinematic
