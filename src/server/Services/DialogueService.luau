--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Dialogue = require(Shared.Data.Dialogue)

local QuestService = require(script.Parent.QuestService)
local InventoryService = require(script.Parent.InventoryService)

local DialogueService = {}

-- Tracks which tree each player currently has open, for server-side validation.
local activeTree: { [Player]: string } = {}

local function runAction(player: Player, action: string)
	local verb, arg = string.match(action, "^(%w+):(%w+)$")
	if verb == "StartQuest" and arg then
		QuestService.startQuest(player, arg)
		if arg == "HarvestMorning" then
			InventoryService.addItem(player, "FestivalBasket", 1)
			Remotes.get("Notify"):FireClient(player, "Mira handed you the festival basket.", "item")
		end
	elseif verb == "Deliver" and arg then
		if
			QuestService.wantsProgress(player, "Deliver", arg)
			and InventoryService.removeItem(player, "FestivalBasket", 1)
		then
			QuestService.recordProgress(player, "Deliver", arg, 1)
		end
	end
end

-- Picks which dialogue tree an NPC should show this player right now.
local function selectTree(player: Player, npcName: string): string?
	if npcName == "Mira" then
		local state = QuestService.getState(player, "HarvestMorning")
		if not state then
			return "MiraBreakfast"
		end
		return "MiraQuestActive"
	elseif npcName == "Daren" then
		return "DarenBracer"
	elseif npcName == "Baker" then
		local state = QuestService.getState(player, "HarvestMorning")
		if state and state.status == "Active" then
			local gathersDone = state.objectives[1].done and state.objectives[2].done
			if gathersDone and InventoryService.getCount(player, "FestivalBasket") > 0 then
				return "Baker"
			end
		end
		return "BakerNoBasket"
	end
	return nil
end

function DialogueService.openForNpc(player: Player, npcName: string)
	local treeId = selectTree(player, npcName)
	if not treeId then
		return
	end
	local tree = Dialogue[treeId]
	activeTree[player] = treeId

	local rootNode = tree.nodes[tree.rootNode]
	if rootNode.action then
		runAction(player, rootNode.action)
	end
	Remotes.get("DialogueOpen"):FireClient(player, treeId, tree.rootNode)
end

local function onAdvance(player: Player, treeId: string, nodeId: string, choiceIndex: number?)
	if activeTree[player] ~= treeId then
		return
	end
	local tree = Dialogue[treeId]
	local node = tree.nodes[nodeId]
	if not node then
		return
	end

	local nextId: string? = nil
	if node.choices and choiceIndex then
		local choice = node.choices[choiceIndex]
		nextId = if choice then choice.nextNode else nil
	else
		nextId = node.nextNode
	end

	if nextId and tree.nodes[nextId] then
		local nextNode = tree.nodes[nextId]
		if nextNode.action then
			runAction(player, nextNode.action)
		end
		Remotes.get("DialogueOpen"):FireClient(player, treeId, nextId)
	else
		activeTree[player] = nil
		Remotes.get("DialogueClose"):FireClient(player)
	end
end

function DialogueService.init()
	Remotes.get("DialogueAdvance").OnServerEvent:Connect(onAdvance)
	Remotes.get("DialogueClose").OnServerEvent:Connect(function(player)
		activeTree[player] = nil
	end)
	Players.PlayerRemoving:Connect(function(player)
		activeTree[player] = nil
	end)
end

return DialogueService
