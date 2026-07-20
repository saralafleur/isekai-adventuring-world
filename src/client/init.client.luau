--!strict
local DialogueUI = require(script.Controllers.DialogueUI)
local QuestTracker = require(script.Controllers.QuestTracker)
local Notifier = require(script.Controllers.Notifier)
local IntroSequence = require(script.Controllers.IntroSequence)

Notifier.init()
QuestTracker.init()
DialogueUI.init()

IntroSequence.play()

print("[Client] Echoes of Aetheria client ready")
