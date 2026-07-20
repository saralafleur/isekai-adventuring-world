--!strict
local DialogueUI = require(script.Controllers.DialogueUI)
local QuestTracker = require(script.Controllers.QuestTracker)
local Notifier = require(script.Controllers.Notifier)
local ShopUI = require(script.Controllers.ShopUI)
local TitleScreen = require(script.Controllers.TitleScreen)
local IntroSequence = require(script.Controllers.IntroSequence)
local FlybyCinematic = require(script.Controllers.FlybyCinematic)

Notifier.init()
QuestTracker.init()
DialogueUI.init()
ShopUI.init()

-- Opening flow: title screen -> monologue over black -> village flyby that
-- descends to the cottage -> control handed to the player
TitleScreen.play()
local blackGui = IntroSequence.play(true)
FlybyCinematic.play(blackGui)

print("[Client] Ikaika in an Adventuring World — client ready")
