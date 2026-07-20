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
	stops: { { position: Vector3, dwell: number } },
	stopIndex: number,
	waypoints: { Vector3 },
	wpIndex: number,
	mode: "Walking" | "Dwelling" | "Routing" | "Done",
	timerUntil: number,
	repathAt: number,
	rng: Random,
}

local TravelerService = {}

local travelers: { Traveler } = {}
local rng = Random.new()

local function browseSpots(): { Vector3 }
	local list = {}
	for _, inst in CollectionService:GetTagged("BrowseSpot") do
		if inst:IsA("BasePart") then
			table.insert(list, inst.Position)
		end
	end
	return list
end

local function buildTraveler(): Traveler?
	local outfit = OUTFITS[rng:NextInteger(1, #OUTFITS)]
	local description = Instance.new("HumanoidDescription")
	description.Shirt = outfit.shirt
	description.Pants = outfit.pants
	description.BodyTypeScale = 0.15
	local skin = SKINS[rng:NextInteger(1, #SKINS)]
	description.HeadColor = skin
	description.TorsoColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin
	description.LeftLegColor = skin
	description.RightLegColor = skin

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
	local stops: { { position: Vector3, dwell: number } } = {}
	table.insert(stops, { position = PLAZA + Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-8, 8)), dwell = rng:NextNumber(5, 15) })
	local spots = browseSpots()
	local stopCount = rng:NextInteger(1, 2)
	for _ = 1, stopCount do
		if #spots > 0 then
			local spot = spots[rng:NextInteger(1, #spots)]
			table.insert(stops, { position = spot, dwell = rng:NextNumber(15, 45) })
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
		local waypoints: { Vector3 } = {}
		if ok and path.Status == Enum.PathStatus.Success then
			for _, wp in path:GetWaypoints() do
				table.insert(waypoints, wp.Position)
			end
		end
		if #waypoints == 0 then
			waypoints = { stop.position }
		end
		t.waypoints = waypoints
		t.wpIndex = 1
		t.repathAt = 0
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
			local stop = t.stops[t.stopIndex]
			if stop and stop.dwell > 0 then
				t.mode = "Dwelling"
				t.timerUntil = now + stop.dwell
			else
				routeToNextStop(t)
			end
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
		if now >= t.timerUntil then
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
