--!strict
-- Scene 3 opening beat: wake from the recurring dream, internal monologue, then hand over control.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local MONOLOGUE = {
	"That dream again.",
	"Rain. Lights. A voice.",
	"Why does it feel like a memory?",
}

local IntroSequence = {}

function IntroSequence.play()
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
	line.Size = UDim2.new(0.8, 0, 0, 60)
	line.BackgroundTransparency = 1
	line.TextColor3 = Color3.fromRGB(220, 220, 230)
	line.Font = Enum.Font.Merriweather
	line.TextSize = 28
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
	hint.Text = "Click to continue"
	hint.TextTransparency = 1
	hint.Parent = black

	gui.Parent = player:WaitForChild("PlayerGui")

	local function waitForClick()
		local done = false
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
				done = true
				conn:Disconnect()
			end
		end)
		while not done do
			task.wait()
		end
	end

	task.wait(1)
	TweenService:Create(hint, TweenInfo.new(1), { TextTransparency = 0.4 }):Play()

	for _, text in MONOLOGUE do
		line.Text = text
		line.TextTransparency = 1
		TweenService:Create(line, TweenInfo.new(0.8), { TextTransparency = 0 }):Play()
		waitForClick()
	end

	local fadeOut = TweenService:Create(black, TweenInfo.new(2), { BackgroundTransparency = 1 })
	TweenService:Create(line, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
	TweenService:Create(hint, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
	fadeOut:Play()
	fadeOut.Completed:Wait()
	gui:Destroy()
end

return IntroSequence
