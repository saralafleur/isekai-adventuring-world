--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Dialogue = require(Shared.Data.Dialogue)

local player = Players.LocalPlayer

local DialogueUI = {}

local gui: ScreenGui
local frame: Frame
local speakerLabel: TextLabel
local bodyLabel: TextLabel
local continueLabel: TextLabel

local currentTreeId: string? = nil
local currentNodeId: string? = nil
local currentLineIndex = 1

local function buildGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "DialogueGui"
	gui.ResetOnSpawn = false
	gui.Enabled = false

	frame = Instance.new("Frame")
	frame.Name = "DialogueFrame"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -30)
	frame.Size = UDim2.new(0.6, 0, 0, 140)
	frame.BackgroundColor3 = Color3.fromRGB(25, 22, 30)
	frame.BackgroundTransparency = 0.1
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(200, 170, 90)
	stroke.Thickness = 2
	stroke.Parent = frame

	speakerLabel = Instance.new("TextLabel")
	speakerLabel.Name = "Speaker"
	speakerLabel.Position = UDim2.new(0, 20, 0, 10)
	speakerLabel.Size = UDim2.new(1, -40, 0, 26)
	speakerLabel.BackgroundTransparency = 1
	speakerLabel.TextXAlignment = Enum.TextXAlignment.Left
	speakerLabel.TextColor3 = Color3.fromRGB(240, 205, 110)
	speakerLabel.Font = Enum.Font.FredokaOne
	speakerLabel.TextSize = 22
	speakerLabel.Parent = frame

	bodyLabel = Instance.new("TextLabel")
	bodyLabel.Name = "Body"
	bodyLabel.Position = UDim2.new(0, 20, 0, 40)
	bodyLabel.Size = UDim2.new(1, -40, 1, -70)
	bodyLabel.BackgroundTransparency = 1
	bodyLabel.TextXAlignment = Enum.TextXAlignment.Left
	bodyLabel.TextYAlignment = Enum.TextYAlignment.Top
	bodyLabel.TextWrapped = true
	bodyLabel.TextColor3 = Color3.new(1, 1, 1)
	bodyLabel.Font = Enum.Font.Gotham
	bodyLabel.TextSize = 18
	bodyLabel.Parent = frame

	continueLabel = Instance.new("TextLabel")
	continueLabel.Name = "Continue"
	continueLabel.AnchorPoint = Vector2.new(1, 1)
	continueLabel.Position = UDim2.new(1, -16, 1, -8)
	continueLabel.Size = UDim2.new(0, 220, 0, 18)
	continueLabel.BackgroundTransparency = 1
	continueLabel.TextXAlignment = Enum.TextXAlignment.Right
	continueLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	continueLabel.Font = Enum.Font.Gotham
	continueLabel.TextSize = 14
	continueLabel.Text = "Click or press E to continue"
	continueLabel.Parent = frame

	gui.Parent = player:WaitForChild("PlayerGui")
end

local function showCurrentLine()
	local treeId = currentTreeId
	local nodeId = currentNodeId
	if not treeId or not nodeId then
		return
	end
	local node = Dialogue[treeId].nodes[nodeId]
	speakerLabel.Text = node.speaker
	bodyLabel.Text = node.lines[currentLineIndex] or ""
	gui.Enabled = true
end

local function advance()
	local treeId = currentTreeId
	local nodeId = currentNodeId
	if not treeId or not nodeId then
		return
	end
	local node = Dialogue[treeId].nodes[nodeId]
	if currentLineIndex < #node.lines then
		currentLineIndex += 1
		showCurrentLine()
	else
		Remotes.get("DialogueAdvance"):FireServer(treeId, nodeId)
	end
end

local function onOpen(treeId: string, nodeId: string)
	currentTreeId = treeId
	currentNodeId = nodeId
	currentLineIndex = 1
	showCurrentLine()
end

local function onClose()
	currentTreeId = nil
	currentNodeId = nil
	gui.Enabled = false
end

function DialogueUI.isOpen(): boolean
	return gui.Enabled
end

function DialogueUI.init()
	buildGui()
	Remotes.get("DialogueOpen").OnClientEvent:Connect(onOpen)
	Remotes.get("DialogueClose").OnClientEvent:Connect(onClose)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not gui.Enabled then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.KeyCode == Enum.KeyCode.E
			or input.KeyCode == Enum.KeyCode.ButtonA
		then
			advance()
		end
	end)
end

return DialogueUI
