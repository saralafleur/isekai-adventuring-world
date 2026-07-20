--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local Quests = require(Shared.Data.Quests)

local InventoryService = require(script.Parent.InventoryService)

type QuestState = Types.QuestState

local QuestService = {}

local playerQuests: { [Player]: { [string]: QuestState } } = {}

local function replicate(player: Player, state: QuestState)
	Remotes.get("QuestUpdated"):FireClient(player, state)
end

function QuestService.setup(player: Player)
	playerQuests[player] = {}
end

function QuestService.cleanup(player: Player)
	playerQuests[player] = nil
end

function QuestService.getState(player: Player, questId: string): QuestState?
	local quests = playerQuests[player]
	return if quests then quests[questId] else nil
end

function QuestService.isActive(player: Player, questId: string): boolean
	local state = QuestService.getState(player, questId)
	return state ~= nil and state.status == "Active"
end

function QuestService.startQuest(player: Player, questId: string)
	local def = Quests[questId]
	local quests = playerQuests[player]
	if not def or not quests or quests[questId] then
		return
	end

	local objectives = {}
	for _, objDef in def.objectives do
		table.insert(objectives, {
			id = objDef.id,
			current = 0,
			required = objDef.count,
			done = false,
		})
	end

	local state: QuestState = {
		id = questId,
		status = "Active",
		objectives = objectives,
	}
	quests[questId] = state
	replicate(player, state)
	Remotes.get("Notify"):FireClient(player, `Quest started: {def.name}`, "quest")
end

local function checkCompletion(player: Player, state: QuestState)
	for _, obj in state.objectives do
		if not obj.done then
			return
		end
	end

	local def = Quests[state.id]
	state.status = "Completed"

	InventoryService.addXp(player, def.reward.xp)
	InventoryService.addCoins(player, def.reward.coins)
	for itemId, count in def.reward.items do
		InventoryService.addItem(player, itemId, count)
	end

	replicate(player, state)
	Remotes.get("QuestCompleted"):FireClient(player, state.id, def.reward)
	Remotes.get("Notify"):FireClient(player, `Quest completed: {def.name}`, "quest")

	if def.nextQuest then
		QuestService.startQuest(player, def.nextQuest)
	end
end

-- Records progress toward objectives of the given kind+target on all active quests.
function QuestService.recordProgress(player: Player, kind: Types.ObjectiveKind, target: string, amount: number)
	local quests = playerQuests[player]
	if not quests then
		return
	end

	for _, state in quests do
		if state.status ~= "Active" then
			continue
		end
		local def = Quests[state.id]
		local changed = false
		for index, objDef in def.objectives do
			local progress = state.objectives[index]
			if objDef.kind == kind and objDef.target == target and not progress.done then
				progress.current = math.min(progress.current + amount, progress.required)
				progress.done = progress.current >= progress.required
				changed = true
			end
		end
		if changed then
			replicate(player, state)
			checkCompletion(player, state)
		end
	end
end

-- True if any active quest has an unfinished objective of this kind+target.
function QuestService.wantsProgress(player: Player, kind: Types.ObjectiveKind, target: string): boolean
	local quests = playerQuests[player]
	if not quests then
		return false
	end
	for _, state in quests do
		if state.status ~= "Active" then
			continue
		end
		local def = Quests[state.id]
		for index, objDef in def.objectives do
			if objDef.kind == kind and objDef.target == target and not state.objectives[index].done then
				return true
			end
		end
	end
	return false
end

Players.PlayerRemoving:Connect(QuestService.cleanup)

return QuestService
