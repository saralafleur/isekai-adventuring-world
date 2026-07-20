--!strict
-- Single source of truth for RemoteEvents. Server creates them; client waits for them.

local RunService = game:GetService("RunService")

local REMOTE_NAMES = {
	"DialogueOpen", -- server -> client: (treeId, nodeId)
	"DialogueAdvance", -- client -> server: (treeId, nodeId, choiceIndex?)
	"DialogueClose", -- both directions
	"QuestUpdated", -- server -> client: (questState)
	"QuestCompleted", -- server -> client: (questId, reward)
	"InventoryUpdated", -- server -> client: ({ [itemId]: count }, coins)
	"Notify", -- server -> client: (message, kind)
	"IntroFinished", -- client -> server: player closed the intro sequence
	"ShopOpen", -- server -> client: (shopId, shopName, entries)
	"ShopBuy", -- client -> server: (shopId, itemId)
}

local Remotes = {}

local function getFolder(): Folder
	if RunService:IsServer() then
		local folder = script.Parent:FindFirstChild("RemoteFolder") :: Folder?
		if not folder then
			local newFolder = Instance.new("Folder")
			newFolder.Name = "RemoteFolder"
			newFolder.Parent = script.Parent
			for _, name in REMOTE_NAMES do
				local remote = Instance.new("RemoteEvent")
				remote.Name = name
				remote.Parent = newFolder
			end
			folder = newFolder
		end
		return folder :: Folder
	else
		return script.Parent:WaitForChild("RemoteFolder") :: Folder
	end
end

function Remotes.get(name: string): RemoteEvent
	local folder = getFolder()
	if RunService:IsServer() then
		return folder:FindFirstChild(name) :: RemoteEvent
	end
	return folder:WaitForChild(name) :: RemoteEvent
end

return Remotes
