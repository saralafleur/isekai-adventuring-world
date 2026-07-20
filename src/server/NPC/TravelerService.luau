--!strict
-- Traveling adventurers: they arrive through one forest gate, walk the main
-- road into the village, stop somewhere interesting (the guild tavern, the
-- market, the well), then leave through the other gate and despawn. A steady
-- trickle keeps the roads alive.

local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SOUTH_GATE = Vector3.new(0, 1, -178)
local NORTH_GATE = Vector3.new(0, 1, 230)
local PLAZA = Vector3.new(0, 1, 50)

local MAX_TRAVELERS = 4
local SPAWN_INTERVAL = { 40, 85 }

local WALK_ANIM = "rbxassetid://507777826"
local IDLE_ANIM = "rbxassetid://507766388"

type Outfit = { shirt: number, pants: number }
local OUTFITS: { Outfit } = {
	{ shirt = 11401062683, pants = 11199196921 }, -- knight
	{ shirt = 5518042632, pants = 6458492706 },
	{ shirt = 12175961478, pants = 13479897957 },
	{ shirt = 991220279, pants = 4600522644 },
}
local NAMES = {
	"Sellsword Dorn",
	"Ranger Elyse",
	"Wanderer Corvin",
	"Squire Petta",
	"Mercenary Halvik",
	"Scout Nyra",
	"Pilgrim Osric",
	"Huntress Vale",
}
local SKINS = {
	Color3.fromRGB(255, 219, 172),
	Color3.fromRGB(214, 173, 130),
	Color3.fromRGB(150, 108, 70),
}

type Traveler = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	walkTrack: AnimationTrack,
	-- remaining itinerary: walk to each point in order, dwelling where noted
	stops: { { position: Vector3, dwell: number, wares: string? } },
	stopIndex: number,
	waypoints: { Vector3 },
	wpIndex: number,
	mode: "Walking" | "Dwelling" | "Routing" | "Done",
	timerUntil: number,
	repathAt: number,
	progressPos: Vector3,
	progressAt: number,
	stuckRetries: number,
	gestureAt: number,
	rng: Random,
}

local TravelerService = {}

local travelers: { Traveler } = {}
local rng = Random.new()

type SpotInfo = { position: Vector3, wares: string? }

local function browseSpots(): { SpotInfo }
	local list = {}
	for _, inst in CollectionService:GetTagged("BrowseSpot") do
		if inst:IsA("BasePart") then
			table.insert(list, { position = inst.Position, wares = inst:GetAttribute("Wares") :: string? })
		end
	end
	return list
end

local AvatarFactory = require(script.Parent.AvatarFactory)
local CarryItems = require(script.Parent.CarryItems)
local Gestures = require(script.Parent.Gestures)

local BODY_KINDS: { AvatarFactory.BodyKind } = { "masc", "fem" }
local BODY_SHAPES: { AvatarFactory.BodyShape } = { "heavy", "average", "average", "thin" }
local HAIR = {
	masc = { 62234425, 10944323614, 14651241814 },
	fem = { 62724852, 16289673213, 110290888975881 },
}

local function buildTraveler(): Traveler?
	local outfit = OUTFITS[rng:NextInteger(1, #OUTFITS)]
	local body: AvatarFactory.BodyKind = BODY_KINDS[rng:NextInteger(1, #BODY_KINDS)]
	local hairPool = HAIR[body]
	local description = AvatarFactory.describe({
		shirtId = outfit.shirt,
		pantsId = outfit.pants,
		skin = SKINS[rng:NextInteger(1, #SKINS)],
		heightScale = rng:NextNumber(0.94, 1.06),
		body = body,
		shape = BODY_SHAPES[rng:NextInteger(1, #BODY_SHAPES)],
		hairId = hairPool[rng:NextInteger(1, #hairPool)],
	})

	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn(`[Travelers] failed to create rig: {model}`)
		return nil
	end

	model.Name = NAMES[rng:NextInteger(1, #NAMES)]
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.WalkSpeed = rng:NextNumber(8, 11)
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.HealthDisplayDistance = 0
	humanoid.NameDisplayDistance = 50

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = "Villager"
		end
	end

	-- Itinerary: enter one gate, cross the plaza, one or two stops, leave out
	-- the other gate
	local southToNorth = rng:NextInteger(0, 1) == 0
	local entry = if southToNorth then SOUTH_GATE else NORTH_GATE
	local exitGate = if southToNorth then NORTH_GATE else SOUTH_GATE
	local stops: { { position: Vector3, dwell: number, wares: string? } } = {}
	table.insert(stops, { position = PLAZA + Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-8, 8)), dwell = rng:NextNumber(5, 15) })
	local spots = browseSpots()
	local stopCount = rng:NextInteger(1, 2)
	for _ = 1, stopCount do
		if #spots > 0 then
			local spot = spots[rng:NextInteger(1, #spots)]
			table.insert(stops, { position = spot.position, dwell = rng:NextNumber(15, 45), wares = spot.wares })
		end
	end
	table.insert(stops, { position = exitGate, dwell = 0 })

	local root = model.PrimaryPart :: BasePart
	model:PivotTo(CFrame.new(entry + Vector3.new(rng:NextNumber(-4, 4), 3.2, 0)))
	model.Parent = workspace
	root:SetNetworkOwner(nil)

	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local idleAnim = Instance.new("Animation")
	idleAnim.AnimationId = IDLE_ANIM
	local idleTrack = animator:LoadAnimation(idleAnim)
	idleTrack.Priority = Enum.AnimationPriority.Idle
	idleTrack.Looped = true
	idleTrack:Play()
	local walkAnim = Instance.new("Animation")
	walkAnim.AnimationId = WALK_ANIM
	local walkTrack = animator:LoadAnimation(walkAnim)
	walkTrack.Priority = Enum.AnimationPriority.Movement
	walkTrack.Looped = true

	return {
		model = model,
		humanoid = humanoid,
		root = root,
		walkTrack = walkTrack,
		stops = stops,
		stopIndex = 0,
		waypoints = {},
		wpIndex = 1,
		mode = "Routing" :: "Routing",
		timerUntil = 0,
		repathAt = 0,
		progressPos = Vector3.zero,
		progressAt = 0,
		stuckRetries = 0,
		gestureAt = 0,
		rng = Random.new(),
	}
end

local function routeToNextStop(t: Traveler)
	t.stopIndex += 1
	local stop = t.stops[t.stopIndex]
	if not stop then
		t.mode = "Done"
		return
	end
	t.mode = "Routing"
	task.spawn(function()
		local path = PathfindingService:CreatePath({
			AgentRadius = 2.5,
			AgentHeight = 6,
			AgentCanJump = false,
			WaypointSpacing = 10,
		})
		local ok = pcall(function()
			path:ComputeAsync(t.root.Position, stop.position)
		end)
		if not ok or path.Status ~= Enum.PathStatus.Success then
			-- unreachable stop: skip it rather than grinding into walls
			routeToNextStop(t)
			return
		end
		local waypoints: { Vector3 } = {}
		for _, wp in path:GetWaypoints() do
			table.insert(waypoints, wp.Position)
		end
		t.waypoints = waypoints
		t.wpIndex = 1
		t.repathAt = 0
		t.progressPos = t.root.Position
		t.progressAt = os.clock()
		-- stuckRetries deliberately NOT reset here: it persists across a
		-- stuck-retry's re-path so a wedged traveler can't loop forever
		t.mode = "Walking"
		t.walkTrack:Play()
	end)
end

local function update(t: Traveler)
	local now = os.clock()
	if t.mode == "Walking" then
		local target = t.waypoints[t.wpIndex]
		if not target then
			t.walkTrack:Stop(0.2)
			t.stuckRetries = 0
			CarryItems.detach(t.model)
			local stop = t.stops[t.stopIndex]
			if stop and stop.dwell > 0 then
				t.mode = "Dwelling"
				t.timerUntil = now + stop.dwell
				if stop.wares then
					t.gestureAt = now + t.rng:NextNumber(1, 3)
				end
			else
				routeToNextStop(t)
			end
			return
		end
		-- stuck detection: recompute once from the actual position, then skip
		if (t.root.Position - t.progressPos).Magnitude > 1 then
			t.progressPos = t.root.Position
			t.progressAt = now
		elseif now - t.progressAt > 3 then
			t.walkTrack:Stop(0.2)
			t.stuckRetries += 1
			t.stopIndex -= 1 -- routeToNextStop re-increments to the same stop
			if t.stuckRetries > 1 then
				t.stopIndex += 1 -- give up on this stop; move to the next
			end
			routeToNextStop(t)
			return
		end
		local delta = t.root.Position - target
		if Vector3.new(delta.X, 0, delta.Z).Magnitude < 3.5 then
			t.wpIndex += 1
		elseif now >= t.repathAt then
			t.humanoid:MoveTo(target)
			t.repathAt = now + 4
		end
	elseif t.mode == "Dwelling" then
		local stop = t.stops[t.stopIndex]
		if stop and stop.wares and now >= t.gestureAt then
			Gestures.play(t.humanoid, t.rng)
			t.gestureAt = now + t.rng:NextNumber(4, 8)
		end
		if now >= t.timerUntil then
			if stop and stop.wares and t.rng:NextNumber() < 0.65 then
				CarryItems.attach(t.model, stop.wares)
			end
			routeToNextStop(t)
		end
	end
end

function TravelerService.init()
	task.spawn(function()
		while true do
			task.wait(rng:NextNumber(SPAWN_INTERVAL[1], SPAWN_INTERVAL[2]))
			-- prune finished travelers
			for i = #travelers, 1, -1 do
				local t = travelers[i]
				if t.mode == "Done" then
					t.model:Destroy()
					table.remove(travelers, i)
				end
			end
			if #travelers < MAX_TRAVELERS then
				task.spawn(function()
					local t = buildTraveler()
					if t then
						table.insert(travelers, t)
						routeToNextStop(t)
					end
				end)
			end
		end
	end)

	RunService.Heartbeat:Connect(function()
		for _, t in travelers do
			update(t)
		end
	end)
end

return TravelerService
