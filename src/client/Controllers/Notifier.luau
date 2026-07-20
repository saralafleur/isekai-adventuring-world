--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local player = Players.LocalPlayer

local Notifier = {}

local gui: ScreenGui
local container: Frame

local KIND_COLORS: { [string]: Color3 } = {
	quest = Color3.fromRGB(240, 205, 110),
	item = Color3.fromRGB(130, 200, 255),
	info = Color3.fromRGB(220, 220, 220),
}

local function buildGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "NotifierGui"
	gui.ResetOnSpawn = false

	container = Instance.new("Frame")
	container.AnchorPoint = Vector2.new(0.5, 0)
	container.Position = UDim2.new(0.5, 0, 0, 20)
	container.Size = UDim2.new(0, 400, 0, 300)
	container.BackgroundTransparency = 1
	container.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.Parent = container

	gui.Parent = player:WaitForChild("PlayerGui")
end

local function show(message: string, kind: string?)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 30)
	label.BackgroundColor3 = Color3.fromRGB(25, 22, 30)
	label.BackgroundTransparency = 0.25
	label.Text = message
	label.TextColor3 = KIND_COLORS[kind or "info"] or KIND_COLORS.info
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 16

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	label.Parent = container

	task.delay(3.5, function()
		local tween = TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1, BackgroundTransparency = 1 })
		tween:Play()
		tween.Completed:Wait()
		label:Destroy()
	end)
end

function Notifier.init()
	buildGui()
	Remotes.get("Notify").OnClientEvent:Connect(show)
end

return Notifier
