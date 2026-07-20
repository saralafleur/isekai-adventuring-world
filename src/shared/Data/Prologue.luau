--!strict
-- Opening narration, spoken by the Chronicler over black before the village
-- flyby. One entry per on-screen phrase: the line is shown while its clip
-- plays, then gives way to the next, so the text and the voice stay in step.
--
-- `key` names the voice clip (Prologue__<key>__1 in VoiceLines). `hold` is the
-- fallback display time in seconds, used only when that clip has no asset id
-- yet — with audio present the line waits for the clip to finish instead.

export type PrologueLine = { key: string, text: string, hold: number }

local Prologue: { PrologueLine } = {
	{ key = "secrets", text = "Every world keeps its secrets. Aetheria keeps more than most.", hold = 4.5 },
	{ key = "died", text = "Fourteen years ago, a boy died in the rain of another world.", hold = 5 },
	{ key = "reborn", text = "He was born again here, to a farmer and his wife, in a village called Briar Glen.", hold = 6.5 },
	{ key = "dream", text = "He remembers none of it. Only the dream. Rain. Lights. A voice.", hold = 5.5 },
	{ key = "harvest", text = "Today the village celebrates the First Harvest.", hold = 3.5 },
	{ key = "nightfall", text = "And by nightfall, everything he loves will be taken from him.", hold = 5.5 },
	{ key = "wake", text = "Wake up, lad. Your story starts now.", hold = 3.5 },
}

return Prologue
