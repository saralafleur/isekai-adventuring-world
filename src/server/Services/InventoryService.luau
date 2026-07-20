--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

type PlayerInventory = {
	items: { [string]: number },
	coins: number,
	xp: number,
}

local InventoryService = {}

local inventories: { [Player]: PlayerInventory } = {}

local function replicate(player: Player)
	local inv = inventories[player]
	if inv then
		Remotes.get("InventoryUpdated"):FireClient(player, inv.items, inv.coins, inv.xp)
	end
end

function InventoryService.setup(player: Player)
	inventories[player] = { items = {}, coins = 0, xp = 0 }
	replicate(player)
end

function InventoryService.cleanup(player: Player)
	inventories[player] = nil
end

function InventoryService.addItem(player: Player, itemId: string, count: number)
	local inv = inventories[player]
	if not inv then
		return
	end
	inv.items[itemId] = (inv.items[itemId] or 0) + count
	replicate(player)
end

function InventoryService.removeItem(player: Player, itemId: string, count: number): boolean
	local inv = inventories[player]
	if not inv then
		return false
	end
	local have = inv.items[itemId] or 0
	if have < count then
		return false
	end
	local remaining = have - count
	if remaining > 0 then
		inv.items[itemId] = remaining
	else
		(inv.items :: { [string]: number? })[itemId] = nil
	end
	replicate(player)
	return true
end

function InventoryService.getCount(player: Player, itemId: string): number
	local inv = inventories[player]
	return if inv then (inv.items[itemId] or 0) else 0
end

function InventoryService.getCoins(player: Player): number
	local inv = inventories[player]
	return if inv then inv.coins else 0
end

function InventoryService.spendCoins(player: Player, amount: number): boolean
	local inv = inventories[player]
	if not inv or inv.coins < amount then
		return false
	end
	inv.coins -= amount
	replicate(player)
	return true
end

function InventoryService.addCoins(player: Player, amount: number)
	local inv = inventories[player]
	if not inv then
		return
	end
	inv.coins += amount
	replicate(player)
end

function InventoryService.addXp(player: Player, amount: number)
	local inv = inventories[player]
	if not inv then
		return
	end
	inv.xp += amount
	replicate(player)
end

Players.PlayerRemoving:Connect(InventoryService.cleanup)

return InventoryService
