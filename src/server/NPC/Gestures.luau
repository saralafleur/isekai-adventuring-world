--!strict
-- Subtle conversational gestures for NPCs: a small point or wave, slowed
-- slightly so it reads as chat rather than theatrics. Vendors run a loop that
-- gestures only when someone is actually standing near them.

local Gestures = {}

local GESTURE_IDS = {
	point = "rbxassetid://507770453",
	wave = "rbxassetid://507770239",
}

local pointAnim = Instance.new("Animation")
pointAnim.AnimationId = GESTURE_IDS.point
local waveAnim = Instance.new("Animation")
waveAnim.AnimationId = GESTURE_IDS.wave

type TrackSet = { point: AnimationTrack, wave: AnimationTrack }
local cache: { [Animator]: TrackSet } = {}
setmetatable(cache :: any, { __mode = "k" })

local function tracksFor(humanoid: Humanoid): TrackSet?
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end
	local existing = cache[animator]
	if existing then
		return existing
	end
	local set = {
		point = animator:LoadAnimation(pointAnim),
		wave = animator:LoadAnimation(waveAnim),
	}
	for _, track in set :: { [string]: AnimationTrack } do
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = false
	end
	cache[animator] = set
	return set
end

-- One small gesture; mostly points (talking with the hands), rare waves.
function Gestures.play(humanoid: Humanoid, rng: Random)
	local set = tracksFor(humanoid)
	if not set then
		return
	end
	local track = if rng:NextNumber() < 0.75 then set.point else set.wave
	if track.IsPlaying then
		return
	end
	track:Play(0.3)
	track:AdjustSpeed(0.85)
end

local function someoneNearby(model: Model, radius: number): boolean
	local root = model.PrimaryPart
	if not root then
		return false
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model }
	for _, hit in workspace:GetPartBoundsInRadius(root.Position, radius, params) do
		local character = hit.Parent
		if character and character:FindFirstChildOfClass("Humanoid") then
			return true
		end
	end
	return false
end

-- For stationary NPCs (vendors, staff): gesture now and then, but only while
-- a customer — villager, traveler, or player — is standing close.
function Gestures.attachIdleLoop(model: Model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local rng = Random.new()
	task.spawn(function()
		while model.Parent do
			task.wait(rng:NextNumber(5, 10))
			if model.Parent and someoneNearby(model, 9) then
				Gestures.play(humanoid, rng)
			end
		end
	end)
end

return Gestures
