--!strict
local Types = require(script.Parent.Parent.Types)

type QuestDef = Types.QuestDef

local Quests: { [string]: QuestDef } = {
	HarvestMorning = {
		id = "HarvestMorning",
		name = "Harvest Morning",
		giver = "Mira",
		objectives = {
			{
				id = "GatherSunroot",
				kind = "Gather",
				description = "Collect sunroot from the family garden",
				target = "Sunroot",
				count = 5,
			},
			{
				id = "GatherEggs",
				kind = "Gather",
				description = "Gather eggs from the chicken pen",
				target = "Egg",
				count = 3,
			},
			{
				id = "DeliverBasket",
				kind = "Deliver",
				description = "Deliver the basket to the village baker",
				target = "Baker",
				count = 1,
			},
		},
		reward = {
			xp = 20,
			coins = 15,
			items = { BasicSatchel = 1, Bread = 1 },
		},
		nextQuest = nil,
	},
}

return Quests
