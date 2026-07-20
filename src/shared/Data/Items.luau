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

	-- Adventurers' Guild stock
	IronSword = {
		id = "IronSword",
		name = "Iron Sword",
		description = "Guild-forged steel. A real blade for real dangers.",
		stackable = false,
		category = "Weapon",
	},
	LeatherArmor = {
		id = "LeatherArmor",
		name = "Leather Armor",
		description = "Hardened leather chest guard. Better than a wool shirt.",
		stackable = false,
		category = "Armor",
	},
	WoodenShield = {
		id = "WoodenShield",
		name = "Wooden Shield",
		description = "Iron-rimmed oak. Tarin would approve.",
		stackable = false,
		category = "Armor",
	},
	HealingTonic = {
		id = "HealingTonic",
		name = "Healing Tonic",
		description = "A bitter red draught that knits small wounds.",
		stackable = true,
		category = "Consumable",
	},
	Rope = {
		id = "Rope",
		name = "Hemp Rope",
		description = "Twenty feet of sturdy rope. Adventurers swear by it.",
		stackable = true,
		category = "Utility",
	},
	Torch = {
		id = "Torch",
		name = "Torch",
		description = "Pitch-soaked and slow-burning. Ruins are dark.",
		stackable = true,
		category = "Utility",
	},
	CampKit = {
		id = "CampKit",
		name = "Camp Kit",
		description = "Bedroll, flint, and a small pot. Home wherever you stop.",
		stackable = false,
		category = "Utility",
	},

	-- Merchants' Guild stock
	ValedornMap = {
		id = "ValedornMap",
		name = "Map of Valedorn",
		description = "Roads, rivers, and towns of the kingdom, inked on vellum.",
		stackable = false,
		category = "Scroll",
	},
	BanditRumors = {
		id = "BanditRumors",
		name = "Rumor Sheet: Bandits",
		description = "Collected sightings and whispers about the Ashen Hand.",
		stackable = false,
		category = "Scroll",
	},
	SkillSwordBasics = {
		id = "SkillSwordBasics",
		name = "Skill Sheet: Sword Basics",
		description = "Illustrated forms and footwork for the aspiring swordsman.",
		stackable = false,
		category = "Scroll",
	},
	SkillHerbLore = {
		id = "SkillHerbLore",
		name = "Skill Sheet: Herb Lore",
		description = "Which leaf heals and which leaf kills.",
		stackable = false,
		category = "Scroll",
	},
	SkillHaggling = {
		id = "SkillHaggling",
		name = "Skill Sheet: Haggling",
		description = "The merchant's art, in twelve shameless lessons.",
		stackable = false,
		category = "Scroll",
	},
	LedgerPaper = {
		id = "LedgerPaper",
		name = "Ledger Paper",
		description = "Fine blank sheets for records and letters.",
		stackable = true,
		category = "Utility",
	},
	TradePass = {
		id = "TradePass",
		name = "Trade Pass",
		description = "Guild-stamped papers granting passage with merchant caravans.",
		stackable = false,
		category = "Scroll",
	},
}

return Items
