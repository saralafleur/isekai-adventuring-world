--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local Quests = require(Shared.Data.Quests)

local player = Players.LocalPlayer

local QuestTracker = {}

local gui: ScreenGui
local listFrame: Frame

local questFrames: { [string]: Frame } = {}

local function buildGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "QuestTrackerGui"
	gui.ResetOnSpawn = false

	listFrame = Instance.new("Frame")
	listFrame.Name = "QuestList"
	listFrame.AnchorPoint = Vector2.new(1, 0)
	listFrame.Position = UDim2.new(1, -16, 0, 80)
	listFrame.Size = UDim2.new(0, 280, 0, 400)
	listFrame.BackgroundTransparency = 1
	listFrame.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = listFrame

	gui.Parent = player:WaitForChild("PlayerGui")
end

local function renderQuest(state: Types.QuestState)
	local def = Quests[state.id]
	if not def then
		return
	end

	local existing = questFrames[state.id]
	if existing then
		existing:Destroy()
		questFrames[state.id] = nil
	end

	if state.status == "Completed" then
		return
	end

	local qFrame = Instance.new("Frame")
	qFrame.Name = state.id
	qFrame.Size = UDim2.new(1, 0, 0, 34 + #state.objectives * 22)
	qFrame.BackgroundColor3 = Color3.fromRGB(25, 22, 30)
	qFrame.BackgroundTransparency = 0.25

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = qFrame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 0, 28)
	title.Position = UDim2.new(0, 10, 0, 4)
	title.BackgroundTransparency = 1
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = def.name
	title.TextColor3 = Color3.fromRGB(240, 205, 110)
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 18
	title.Parent = qFrame

	for index, objDef in def.objectives do
		local progress = state.objectives[index]
		local line = Instance.new("TextLabel")
		line.Size = UDim2.new(1, -28, 0, 20)
		line.Position = UDim2.new(0, 18, 0, 30 + (index - 1) * 22)
		line.BackgroundTransparency = 1
		line.TextXAlignment = Enum.TextXAlignment.Left
		line.TextWrapped = true
		line.Font = Enum.Font.Gotham
		line.TextSize = 14
		if progress.done then
			line.Text = `✓ {objDef.description}`
			line.TextColor3 = Color3.fromRGB(130, 220, 130)
		else
			line.Text = `• {objDef.description} ({progress.current}/{progress.required})`
			line.TextColor3 = Color3.fromRGB(230, 230, 230)
		end
		line.Parent = qFrame
	end

	qFrame.Parent = listFrame
	questFrames[state.id] = qFrame
end

function QuestTracker.init()
	buildGui()
	Remotes.get("QuestUpdated").OnClientEvent:Connect(renderQuest)
end

return QuestTracker
