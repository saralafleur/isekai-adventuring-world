--!strict
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Items = require(Shared.Data.Items)

local QuestService = require(script.Parent.QuestService)
local InventoryService = require(script.Parent.InventoryService)

local RESPAWN_SECONDS = 12

local GatherService = {}

local function setNodeActive(node: Part, active: boolean)
	node.Transparency = if active then 0 else 1
	node.CanCollide = active
	local prompt = node:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = active
	end
end

local function onGather(node: Part, player: Player)
	local itemId = node:GetAttribute("ItemId") :: string?
	if not itemId then
		return
	end

	if not QuestService.wantsProgress(player, "Gather", itemId) then
		Remotes.get("Notify"):FireClient(player, "I don't need this right now.", "info")
		return
	end

	InventoryService.addItem(player, itemId, 1)
	QuestService.recordProgress(player, "Gather", itemId, 1)
	local itemName = if Items[itemId] then Items[itemId].name else itemId
	Remotes.get("Notify"):FireClient(player, `Gathered {itemName}`, "item")

	setNodeActive(node, false)
	task.delay(RESPAWN_SECONDS, function()
		if node.Parent then
			setNodeActive(node, true)
		end
	end)
end

local function hookNode(node: Instance)
	if not node:IsA("Part") then
		return
	end
	local prompt = node:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Triggered:Connect(function(player)
			onGather(node, player)
		end)
	end
end

function GatherService.init()
	for _, node in CollectionService:GetTagged("GatherNode") do
		hookNode(node)
	end
	CollectionService:GetInstanceAddedSignal("GatherNode"):Connect(hookNode)
end

return GatherService
