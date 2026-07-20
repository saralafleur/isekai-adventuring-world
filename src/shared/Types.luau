--!strict

export type ItemId = string

export type ItemDef = {
	id: ItemId,
	name: string,
	description: string,
	stackable: boolean,
	category: "Consumable" | "Weapon" | "Armor" | "QuestItem" | "Material" | "Currency",
}

export type ObjectiveKind = "Gather" | "Deliver" | "Talk" | "Kill" | "Reach"

export type ObjectiveDef = {
	id: string,
	kind: ObjectiveKind,
	description: string,
	-- Gather/Kill: target id and count. Deliver/Talk: NPC name. Reach: zone tag.
	target: string,
	count: number,
}

export type QuestReward = {
	xp: number,
	coins: number,
	items: { [ItemId]: number },
}

export type QuestDef = {
	id: string,
	name: string,
	giver: string,
	objectives: { ObjectiveDef },
	reward: QuestReward,
	nextQuest: string?,
}

export type ObjectiveProgress = {
	id: string,
	current: number,
	required: number,
	done: boolean,
}

export type QuestState = {
	id: string,
	status: "Active" | "Completed",
	objectives: { ObjectiveProgress },
}

export type DialogueChoice = {
	text: string,
	nextNode: string?,
}

export type DialogueNode = {
	speaker: string,
	lines: { string },
	choices: { DialogueChoice }?,
	nextNode: string?,
	-- Fired server-side when the node is reached (e.g. "StartQuest:HarvestMorning")
	action: string?,
}

export type DialogueTree = {
	id: string,
	nodes: { [string]: DialogueNode },
	rootNode: string,
}

return {}
