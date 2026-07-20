--!strict
-- Title / loading screen: "ISEKAI — in an Adventuring World".
-- Dusk-sky gradient, glowing sun, layered mountain silhouettes, drifting
-- embers, shimmering gold title. Click to begin -> fades to black and hands
-- off to the monologue.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local TitleScreen = {}

local function makeMountain(parent: Frame, xScale: number, size: number, color: Color3, yOffset: number)
	local peak = Instance.new("Frame")
	peak.AnchorPoint = Vector2.new(0.5, 0.5)
	peak.Position = UDim2.new(xScale, 0, 1, yOffset)
	peak.Size = UDim2.fromOffset(size, size)
	peak.Rotation = 45
	peak.BackgroundColor3 = color
	peak.BorderSizePixel = 0
	peak.Parent = parent
end

local function makeEmber(parent: Frame, xScale: number, delay: number, duration: number)
	local ember = Instance.new("Frame")
	ember.AnchorPoint = Vector2.new(0.5, 0.5)
	ember.Position = UDim2.new(xScale, 0, 1.05, 0)
	ember.Size = UDim2.fromOffset(5, 5)
	ember.BackgroundColor3 = Color3.fromRGB(255, 190, 100)
	ember.BackgroundTransparency = 0.2
	ember.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = ember
	ember.Parent = parent

	task.spawn(function()
		while ember.Parent do
			ember.Position = UDim2.new(xScale, 0, 1.05, 0)
			ember.BackgroundTransparency = 0.2
			task.wait(delay)
			local drift = TweenService:Create(ember, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
				Position = UDim2.new(xScale + 0.04, 0, -0.1, 0),
				BackgroundTransparency = 1,
			})
			drift:Play()
			drift.Completed:Wait()
		end
	end)
end

function TitleScreen.play()
	local gui = Instance.new("ScreenGui")
	gui.Name = "TitleGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 200

	local sky = Instance.new("Frame")
	sky.Size = UDim2.fromScale(1, 1)
	sky.BorderSizePixel = 0
	sky.BackgroundColor3 = Color3.new(1, 1, 1)
	sky.ClipsDescendants = true
	sky.Parent = gui

	local skyGradient = Instance.new("UIGradient")
	skyGradient.Rotation = 90
	skyGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 16, 44)),
		ColorSequenceKeypoint.new(0.45, Color3.fromRGB(66, 40, 92)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(180, 100, 90)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(240, 180, 110)),
	})
	skyGradient.Parent = sky

	-- Glowing sun low on the horizon
	local sun = Instance.new("Frame")
	sun.AnchorPoint = Vector2.new(0.5, 0.5)
	sun.Position = UDim2.fromScale(0.5, 0.78)
	sun.Size = UDim2.fromOffset(190, 190)
	sun.BackgroundColor3 = Color3.fromRGB(255, 214, 130)
	sun.BackgroundTransparency = 0.15
	sun.BorderSizePixel = 0
	local sunCorner = Instance.new("UICorner")
	sunCorner.CornerRadius = UDim.new(1, 0)
	sunCorner.Parent = sun
	local sunGlow = Instance.new("UIStroke")
	sunGlow.Color = Color3.fromRGB(255, 230, 170)
	sunGlow.Thickness = 14
	sunGlow.Transparency = 0.55
	sunGlow.Parent = sun
	sun.Parent = sky
	-- slow pulse
	task.spawn(function()
		while sun.Parent do
			local grow = TweenService:Create(sun, TweenInfo.new(2.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Size = UDim2.fromOffset(210, 210) })
			grow:Play()
			grow.Completed:Wait()
			local shrink = TweenService:Create(sun, TweenInfo.new(2.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Size = UDim2.fromOffset(190, 190) })
			shrink:Play()
			shrink.Completed:Wait()
		end
	end)

	-- Mountain silhouettes: far (lighter) and near (darker) ranges
	makeMountain(sky, 0.1, 300, Color3.fromRGB(52, 36, 66), 60)
	makeMountain(sky, 0.32, 380, Color3.fromRGB(52, 36, 66), 90)
	makeMountain(sky, 0.62, 340, Color3.fromRGB(52, 36, 66), 80)
	makeMountain(sky, 0.88, 300, Color3.fromRGB(52, 36, 66), 70)
	makeMountain(sky, 0.0, 340, Color3.fromRGB(30, 22, 44), 120)
	makeMountain(sky, 0.24, 420, Color3.fromRGB(30, 22, 44), 150)
	makeMountain(sky, 0.5, 360, Color3.fromRGB(30, 22, 44), 130)
	makeMountain(sky, 0.76, 440, Color3.fromRGB(30, 22, 44), 160)
	makeMountain(sky, 1.0, 380, Color3.fromRGB(30, 22, 44), 140)

	-- Drifting embers
	for i = 1, 10 do
		makeEmber(sky, 0.06 + i * 0.09, i * 0.7, 5 + (i % 3) * 1.6)
	end

	-- Title block
	local title = Instance.new("TextLabel")
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.34)
	title.Size = UDim2.new(0.9, 0, 0, 130)
	title.BackgroundTransparency = 1
	title.Text = "ISEKAI"
	title.Font = Enum.Font.LuckiestGuy
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 220, 130)
	title.TextTransparency = 1
	title.Parent = sky
	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = Color3.fromRGB(40, 24, 12)
	titleStroke.Thickness = 4
	titleStroke.Transparency = 1
	titleStroke.Parent = title
	local titleGradient = Instance.new("UIGradient")
	titleGradient.Rotation = 90
	titleGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 190)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(250, 200, 100)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 120, 50)),
	})
	titleGradient.Parent = title

	local subtitle = Instance.new("TextLabel")
	subtitle.AnchorPoint = Vector2.new(0.5, 0.5)
	subtitle.Position = UDim2.fromScale(0.5, 0.47)
	subtitle.Size = UDim2.new(0.8, 0, 0, 40)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "~ in an Adventuring World ~"
	subtitle.Font = Enum.Font.Merriweather
	subtitle.TextScaled = true
	subtitle.TextColor3 = Color3.fromRGB(235, 220, 235)
	subtitle.TextTransparency = 1
	subtitle.Parent = sky

	local prompt = Instance.new("TextLabel")
	prompt.AnchorPoint = Vector2.new(0.5, 1)
	prompt.Position = UDim2.new(0.5, 0, 1, -60)
	prompt.Size = UDim2.new(0.5, 0, 0, 28)
	prompt.BackgroundTransparency = 1
	prompt.Text = "Click to begin your adventure"
	prompt.Font = Enum.Font.Gotham
	prompt.TextSize = 20
	prompt.TextColor3 = Color3.fromRGB(255, 245, 220)
	prompt.TextTransparency = 1
	prompt.Parent = sky

	gui.Parent = player:WaitForChild("PlayerGui")

	-- Entrance: title drops in with a shimmer, subtitle follows, prompt pulses
	TweenService:Create(title, TweenInfo.new(1.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { TextTransparency = 0 }):Play()
	TweenService:Create(titleStroke, TweenInfo.new(1.4), { Transparency = 0.1 }):Play()
	task.wait(0.7)
	TweenService:Create(subtitle, TweenInfo.new(1.2), { TextTransparency = 0.05 }):Play()
	task.wait(0.8)
	task.spawn(function()
		while prompt.Parent do
			local fadeIn = TweenService:Create(prompt, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { TextTransparency = 0.1 })
			fadeIn:Play()
			fadeIn.Completed:Wait()
			local fadeOut = TweenService:Create(prompt, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { TextTransparency = 0.75 })
			fadeOut:Play()
			fadeOut.Completed:Wait()
		end
	end)
	-- Gold shimmer sweeping across the title
	task.spawn(function()
		while titleGradient.Parent do
			titleGradient.Offset = Vector2.new(-1, 0)
			local sweep = TweenService:Create(titleGradient, TweenInfo.new(2.6, Enum.EasingStyle.Sine), { Offset = Vector2.new(1, 0) })
			sweep:Play()
			sweep.Completed:Wait()
			task.wait(1.2)
		end
	end)

	-- Wait for click / tap / key
	local clicked = false
	local conn: RBXScriptConnection
	conn = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.Return
			or input.KeyCode == Enum.KeyCode.ButtonA
		then
			clicked = true
			conn:Disconnect()
		end
	end)
	while not clicked do
		task.wait()
	end

	-- Fade everything to black, then hand off (the monologue plays over black)
	local blackout = Instance.new("Frame")
	blackout.Size = UDim2.fromScale(1, 1)
	blackout.BackgroundColor3 = Color3.new(0, 0, 0)
	blackout.BackgroundTransparency = 1
	blackout.BorderSizePixel = 0
	blackout.ZIndex = 50
	blackout.Parent = sky
	local toBlack = TweenService:Create(blackout, TweenInfo.new(1.2), { BackgroundTransparency = 0 })
	toBlack:Play()
	toBlack.Completed:Wait()
	gui:Destroy()
end

return TitleScreen
