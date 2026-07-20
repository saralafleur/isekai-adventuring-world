--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

-- Creating the remotes must happen before anything requires them
Remotes.get("Notify")

local VillageBuilder = require(script.World.VillageBuilder)
local InventoryService = require(script.Services.InventoryService)
local QuestService = require(script.Services.QuestService)
local DialogueService = require(script.Services.DialogueService)
local GatherService = require(script.Services.GatherService)
local NpcService = require(script.Services.NpcService)
local ShopService = require(script.Services.ShopService)
local VillagerService = require(script.NPC.VillagerService)

VillageBuilder.build()

DialogueService.init()
GatherService.init()
NpcService.init()
ShopService.init()
VillagerService.init()

local function onPlayerAdded(player: Player)
	InventoryService.setup(player)
	QuestService.setup(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

print("[Server] Echoes of Aetheria — Briar Glen ready")
