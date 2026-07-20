--!strict
local CollectionService = game:GetService("CollectionService")

local DialogueService = require(script.Parent.DialogueService)

local NpcService = {}

local function hookNpc(model: Instance)
	local npcName = model:GetAttribute("NpcName") :: string?
	if not npcName then
		return
	end
	local function bind(prompt: Instance)
		if prompt:IsA("ProximityPrompt") then
			prompt.Triggered:Connect(function(player)
				DialogueService.openForNpc(player, npcName)
			end)
		end
	end
	for _, descendant in model:GetDescendants() do
		bind(descendant)
	end
	-- avatar models finish building asynchronously; catch prompts added later
	model.DescendantAdded:Connect(bind)
end

function NpcService.init()
	for _, model in CollectionService:GetTagged("NPC") do
		hookNpc(model)
	end
	CollectionService:GetInstanceAddedSignal("NPC"):Connect(hookNpc)
end

return NpcService
