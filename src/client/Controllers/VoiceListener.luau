--!strict
-- Completes the audio graph for NPC speech.
--
-- Roblox's newer audio API does NOT play an AudioEmitter on its own. The full
-- chain is:
--     AudioTextToSpeech -> Wire -> AudioEmitter    (server, on the NPC's head)
--     AudioListener     -> Wire -> AudioDeviceOutput  (client, here)
-- Without the listener half nothing is audible, which is exactly why the
-- voices were silent — the emitters were speaking into a room with no ears.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local VoiceListener = {}

function VoiceListener.init()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local ok = pcall(function()
		-- Ears ride the camera, so speech pans and attenuates with your view
		local listener = Instance.new("AudioListener")
		listener.Name = "VoiceListener"
		listener.Parent = camera

		local output = Instance.new("AudioDeviceOutput")
		output.Name = "VoiceOutput"
		output.Player = player
		output.Parent = camera

		local wire = Instance.new("Wire")
		wire.Name = "VoiceWire"
		wire.SourceInstance = listener
		wire.SourceName = "Output"
		wire.TargetInstance = output
		wire.TargetName = "Input"
		wire.Parent = camera
	end)

	if not ok then
		warn("[VoiceListener] could not build the audio listener chain")
		return
	end

	-- The camera instance is replaced on respawn/teleport; rebuild if it goes.
	RunService.Heartbeat:Connect(function()
		local current = workspace.CurrentCamera
		if current and not current:FindFirstChild("VoiceListener") then
			VoiceListener.init()
		end
	end)
end

return VoiceListener
