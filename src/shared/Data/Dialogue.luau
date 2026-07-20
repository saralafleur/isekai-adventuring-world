--!strict
local Types = require(script.Parent.Parent.Types)

type DialogueTree = Types.DialogueTree

local Dialogue: { [string]: DialogueTree } = {
	MiraBreakfast = {
		id = "MiraBreakfast",
		rootNode = "greeting",
		nodes = {
			greeting = {
				speaker = "Mira",
				lines = {
					"There you are. I was beginning to think you planned to sleep through the festival.",
				},
				nextNode = "kael_dream",
			},
			kael_dream = {
				speaker = "Kael",
				lines = { "I had the dream again." },
				nextNode = "mira_city",
			},
			mira_city = {
				speaker = "Mira",
				lines = { "The city of glass?" },
				nextNode = "kael_rain",
			},
			kael_rain = {
				speaker = "Kael",
				lines = { "And the rain." },
				nextNode = "daren_breakfast",
			},
			daren_breakfast = {
				speaker = "Daren",
				lines = { "Dreams feel important until breakfast." },
				nextNode = "mira_cure",
			},
			mira_cure = {
				speaker = "Mira",
				lines = { "Your father believes food is the cure for everything." },
				nextNode = "daren_usually",
			},
			daren_usually = {
				speaker = "Daren",
				lines = { "It usually is." },
				nextNode = "quest_ask",
			},
			quest_ask = {
				speaker = "Mira",
				lines = {
					"Kael, the festival won't wait for daydreams. I need supplies before noon.",
					"Gather five sunroot from the garden, three eggs from the pen, and take the basket to the baker.",
				},
				action = "StartQuest:HarvestMorning",
			},
		},
	},

	MiraQuestActive = {
		id = "MiraQuestActive",
		rootNode = "reminder",
		nodes = {
			reminder = {
				speaker = "Mira",
				lines = {
					"Sunroot from the garden, eggs from the pen, and the basket goes to the baker.",
					"And mind General Cluck. That bird has opinions.",
				},
			},
		},
	},

	DarenBracer = {
		id = "DarenBracer",
		rootNode = "ask",
		nodes = {
			ask = {
				speaker = "Kael",
				lines = { "Father, what's that bracer you keep repairing?" },
				nextNode = "answer",
			},
			answer = {
				speaker = "Daren",
				lines = { "Old militia equipment. Nothing more." },
			},
		},
	},

	Baker = {
		id = "Baker",
		rootNode = "greeting",
		nodes = {
			greeting = {
				speaker = "Baker Hobb",
				lines = {
					"Ah, the Rowan boy! Is that Mira's festival basket?",
					"Wonderful. The harvest loaves will be ready before the music starts.",
				},
				action = "Deliver:Baker",
				nextNode = "thanks",
			},
			thanks = {
				speaker = "Baker Hobb",
				lines = { "Here, take a fresh loaf for your trouble. Enjoy the festival!" },
			},
		},
	},

	BakerNoBasket = {
		id = "BakerNoBasket",
		rootNode = "greeting",
		nodes = {
			greeting = {
				speaker = "Baker Hobb",
				lines = { "Morning, lad! Busy day ahead. Come back if you've got something for me." },
			},
		},
	},
}

return Dialogue
