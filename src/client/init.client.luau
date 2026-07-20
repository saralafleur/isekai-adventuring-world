--!strict
local DialogueUI = require(script.Controllers.DialogueUI)
local QuestTracker = require(script.Controllers.QuestTracker)
local Notifier = require(script.Controllers.Notifier)
local ShopUI = require(script.Controllers.ShopUI)
local MusicController = require(script.Controllers.MusicController)
local MapUI = require(script.Controllers.MapUI)
local VoiceListener = require(script.Controllers.VoiceListener)
local TitleScreen = require(script.Controllers.TitleScreen)
local IntroSequence = require(script.Controllers.IntroSequence)
local FlybyCinematic = require(script.Controllers.FlybyCinematic)

Notifier.init()
QuestTracker.init()
DialogueUI.init()
ShopUI.init()
MusicController.init()
MapUI.init()
VoiceListener.init()

-- Opening flow: title screen -> monologue over black -> village flyby that
-- glides back into the player's head (first person) -> control handed over
MusicController.playTitle()
TitleScreen.play()
local blackGui = IntroSequence.play(true)
FlybyCinematic.play(blackGui)
MusicController.toVillage()

print("[Client] Isekai in an Adventuring World — client ready")
