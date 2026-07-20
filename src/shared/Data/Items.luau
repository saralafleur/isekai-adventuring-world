--!strict
local Types = require(script.Parent.Parent.Types)

type ItemDef = Types.ItemDef

local Items: { [string]: ItemDef } = {
	Sunroot = {
		id = "Sunroot",
		name = "Sunroot",
		description = "A glowing orange vegetable grown in Briar Glen's gardens.",
		stackable = true,
		category = "Material",
	},
	Egg = {
		id = "Egg",
		name = "Egg",
		description = "A fresh egg. General Cluck guards these jealously.",
		stackable = true,
		category = "Material",
	},
	FestivalBasket = {
		id = "FestivalBasket",
		name = "Festival Basket",
		description = "A basket of festival supplies for the village baker.",
		stackable = false,
		category = "QuestItem",
	},
	Bread = {
		id = "Bread",
		name = "Fresh Bread",
		description = "Warm bread from the village baker. Restores a little health.",
		stackable = true,
		category = "Consumable",
	},
	BasicSatchel = {
		id = "BasicSatchel",
		name = "Basic Satchel",
		description = "A simple leather satchel. Lets you carry more.",
		stackable = false,
		category = "QuestItem",
	},
	WoodenSword = {
		id = "WoodenSword",
		name = "Wooden Practice Sword",
		description = "A gift from Father. Tarin still insists he won the last duel.",
		stackable = false,
		category = "Weapon",
	},
}

return Items
