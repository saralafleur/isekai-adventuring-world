--!strict
-- Guild shops: talking to a tagged Shopkeeper opens the shop UI; purchases are
-- validated server-side against the shop's stock and the player's coins.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Items = require(Shared.Data.Items)

local InventoryService = require(script.Parent.InventoryService)

type ShopEntry = { itemId: string, price: number }
type ShopDef = { name: string, stock: { ShopEntry } }

local SHOPS: { [string]: ShopDef } = {
	AdventurersGuild = {
		name = "Adventurers' Guild",
		stock = {
			{ itemId = "IronSword", price = 80 },
			{ itemId = "LeatherArmor", price = 60 },
			{ itemId = "WoodenShield", price = 40 },
			{ itemId = "CampKit", price = 25 },
			{ itemId = "HealingTonic", price = 10 },
			{ itemId = "Rope", price = 8 },
			{ itemId = "Torch", price = 5 },
		},
	},
	MerchantsGuild = {
		name = "Merchants' Guild",
		stock = {
			{ itemId = "TradePass", price = 100 },
			{ itemId = "SkillSwordBasics", price = 50 },
			{ itemId = "SkillHerbLore", price = 50 },
			{ itemId = "SkillHaggling", price = 50 },
			{ itemId = "ValedornMap", price = 20 },
			{ itemId = "BanditRumors", price = 15 },
			{ itemId = "LedgerPaper", price = 5 },
		},
	},
}

local ShopService = {}

local function openShop(player: Player, shopId: string)
	local shop = SHOPS[shopId]
	if not shop then
		return
	end
	local payload = {}
	for _, entry in shop.stock do
		local def = Items[entry.itemId]
		if def then
			table.insert(payload, {
				itemId = entry.itemId,
				name = def.name,
				description = def.description,
				price = entry.price,
			})
		end
	end
	Remotes.get("ShopOpen"):FireClient(player, shopId, shop.name, payload)
end

local function onBuy(player: Player, shopId: unknown, itemId: unknown)
	if type(shopId) ~= "string" or type(itemId) ~= "string" then
		return
	end
	local shop = SHOPS[shopId]
	if not shop then
		return
	end
	local entry: ShopEntry? = nil
	for _, e in shop.stock do
		if e.itemId == itemId then
			entry = e
			break
		end
	end
	if not entry then
		return
	end
	local def = Items[entry.itemId]
	if not def then
		return
	end
	-- Non-stackable items: one copy only
	if not def.stackable and InventoryService.getCount(player, entry.itemId) > 0 then
		Remotes.get("Notify"):FireClient(player, `You already own {def.name}.`, "info")
		return
	end
	if not InventoryService.spendCoins(player, entry.price) then
		Remotes.get("Notify"):FireClient(player, "Not enough coins.", "info")
		return
	end
	InventoryService.addItem(player, entry.itemId, 1)
	Remotes.get("Notify"):FireClient(player, `Bought {def.name} for {entry.price} coins`, "item")
end

local function hookShopkeeper(model: Instance)
	local shopId = model:GetAttribute("ShopId") :: string?
	if not shopId then
		return
	end
	local torso = model:FindFirstChild("UpperTorso") or model:FindFirstChild("HumanoidRootPart")
	if not torso then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Shop"
	prompt.ObjectText = model.Name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.Parent = torso
	prompt.Triggered:Connect(function(player)
		openShop(player, shopId)
	end)
end

function ShopService.init()
	for _, model in CollectionService:GetTagged("Shopkeeper") do
		hookShopkeeper(model)
	end
	CollectionService:GetInstanceAddedSignal("Shopkeeper"):Connect(hookShopkeeper)
	Remotes.get("ShopBuy").OnServerEvent:Connect(onBuy)
end

return ShopService
