--!strict
-- Drives the 15 ambient villagers as real R15 avatars: each rig is generated
-- from a HumanoidDescription (catalog clothing + body scales), walks with
-- Roblox's standard walk/idle animations via Humanoid:MoveTo, pathfinds around
-- buildings/fences, and runs endless randomized routines (walk somewhere ->
-- dwell / enter a house / work the forge -> pick the next errand). Routines
-- never repeat because each next stop is drawn from persona weights at runtime.

local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Catalog = require(script.Parent.VillagerCatalog)

type Persona = Catalog.Persona

-- Roblox's standard R15 animation assets
local ANIM_IDS = {
	idle = "rbxassetid://507766388",
	walk = "rbxassetid://507777826",
	slash = "rbxassetid://522635514", -- hammer swing
}

local VILLAGER_GROUP = "Villager"

type Villager = {
	persona: Persona,
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	walkTrack: AnimationTrack,
	slashTrack: AnimationTrack,
	originalTransparency: { [Instance]: number },
	mode: "Idle" | "Walking" | "Hidden" | "Working" | "Routing",
	waypoints: { Vector3 },
	wpIndex: number,
	timerUntil: number,
	repathAt: number,
	sparkAt: number,
	rng: Random,
}

local VillagerService = {}

local villagers: { Villager } = {}
local destinations: { [string]: { Vector3 } } = {}
local anvilSparks: ParticleEmitter? = nil

-- ---------------------------------------------------------------- rig building

local function makeAnimation(id: string): Animation
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	return anim
end

local animIdle = makeAnimation(ANIM_IDS.idle)
local animWalk = makeAnimation(ANIM_IDS.walk)
local animSlash = makeAnimation(ANIM_IDS.slash)

local function attachHammer(model: Model)
	local rightHand = model:FindFirstChild("RightHand") :: BasePart?
	if not rightHand then
		return
	end
	local handle = Instance.new("Part")
	handle.Name = "Hammer"
	handle.Size = Vector3.new(0.35, 1.6, 0.35)
	handle.Color = Color3.fromRGB(120, 90, 60)
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.Massless = true
	handle.CFrame = rightHand.CFrame * CFrame.new(0, -0.4, -0.6) * CFrame.Angles(math.rad(90), 0, 0)
	local head = Instance.new("Part")
	head.Name = "HammerHead"
	head.Size = Vector3.new(0.9, 0.5, 0.55)
	head.Color = Color3.fromRGB(90, 88, 86)
	head.Material = Enum.Material.Metal
	head.CanCollide = false
	head.Massless = true
	head.CFrame = handle.CFrame * CFrame.new(0, 0.85, 0)

	local weld1 = Instance.new("WeldConstraint")
	weld1.Part0 = rightHand
	weld1.Part1 = handle
	weld1.Parent = handle
	local weld2 = Instance.new("WeldConstraint")
	weld2.Part0 = handle
	weld2.Part1 = head
	weld2.Parent = head
	handle.Parent = model
	head.Parent = model
end

local function buildRig(persona: Persona, spawnPos: Vector3): Villager?
	local description = Instance.new("HumanoidDescription")
	description.Shirt = persona.shirtId
	description.Pants = persona.pantsId
	description.HeightScale = persona.heightScale
	description.WidthScale = persona.widthScale
	description.BodyTypeScale = 0.15
	if persona.hairId then
		description.HairAccessory = tostring(persona.hairId)
	end
	if persona.hatId then
		description.HatAccessory = tostring(persona.hatId)
	end
	description.HeadColor = persona.skin
	description.TorsoColor = persona.skin
	description.LeftArmColor = persona.skin
	description.RightArmColor = persona.skin
	description.LeftLegColor = persona.skin
	description.RightLegColor = persona.skin

	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn(`[Villagers] failed to create rig for {persona.name}: {model}`)
		return nil
	end

	model.Name = persona.name
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.WalkSpeed = persona.speed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.HealthDisplayDistance = 0
	humanoid.NameDisplayDistance = 50
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)

	local root = model.PrimaryPart :: BasePart

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = VILLAGER_GROUP
		end
	end

	if persona.weights.forge > 0 then
		attachHammer(model)
	end

	-- Record original transparencies so hide/unhide can restore them exactly
	local originalTransparency: { [Instance]: number } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") then
			originalTransparency[descendant] = (descendant :: any).Transparency
		end
	end

	model:PivotTo(CFrame.new(spawnPos + Vector3.new(0, 3.2, 0)))
	model.Parent = workspace
	root:SetNetworkOwner(nil)

	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local idleTrack = animator:LoadAnimation(animIdle)
	idleTrack.Priority = Enum.AnimationPriority.Idle
	idleTrack.Looped = true
	idleTrack:Play()
	local walkTrack = animator:LoadAnimation(animWalk)
	walkTrack.Priority = Enum.AnimationPriority.Movement
	walkTrack.Looped = true
	local slashTrack = animator:LoadAnimation(animSlash)
	slashTrack.Priority = Enum.AnimationPriority.Action
	slashTrack.Looped = true

	return {
		persona = persona,
		model = model,
		humanoid = humanoid,
		root = root,
		walkTrack = walkTrack,
		slashTrack = slashTrack,
		originalTransparency = originalTransparency,
		mode = "Idle" :: "Idle",
		waypoints = {},
		wpIndex = 1,
		timerUntil = 0,
		repathAt = 0,
		sparkAt = 0,
		rng = Random.new(),
	}
end

local function setHidden(v: Villager, hidden: boolean)
	for instance, original in v.originalTransparency do
		(instance :: any).Transparency = if hidden then 1 else original
	end
	for _, descendant in v.model:GetDescendants() do
		if descendant:IsA("BasePart") and (descendant.Name == "Hammer" or descendant.Name == "HammerHead") then
			descendant.Transparency = if hidden then 1 else 0
		end
	end
	v.root.Anchored = hidden
	v.humanoid.DisplayDistanceType = if hidden
		then Enum.HumanoidDisplayDistanceType.None
		else Enum.HumanoidDisplayDistanceType.Viewer
end

-- ---------------------------------------------------------------- destinations

local function collectDestinations()
	local function positionsOf(tag: string): { Vector3 }
		local list = {}
		for _, inst in CollectionService:GetTagged(tag) do
			if inst:IsA("BasePart") then
				table.insert(list, inst.Position)
			end
		end
		return list
	end
	destinations = {
		house = positionsOf("HouseDoor"),
		browse = positionsOf("BrowseSpot"),
		well = positionsOf("GatherSpot"),
		field = positionsOf("FieldSpot"),
		watch = positionsOf("SmithyWatchSpot"),
		forge = positionsOf("AnvilSpot"),
	}
	for _, inst in CollectionService:GetTagged("AnvilSpot") do
		local smithy = inst.Parent
		if smithy then
			local anvilTop = smithy:FindFirstChild("AnvilTop")
			if anvilTop then
				anvilSparks = anvilTop:FindFirstChild("Sparks") :: ParticleEmitter
			end
		end
	end
end

type WeightEntry = { category: string, weight: number }

local function pickCategory(v: Villager): string
	local w = v.persona.weights
	local entries: { WeightEntry } = {
		{ category = "house", weight = w.house },
		{ category = "browse", weight = w.browse },
		{ category = "well", weight = w.well },
		{ category = "field", weight = w.field },
		{ category = "watch", weight = w.watch },
		{ category = "forge", weight = w.forge },
	}
	local total = 0
	for _, e in entries do
		total += e.weight
	end
	local roll = v.rng:NextNumber(0, total)
	local acc = 0
	for _, e in entries do
		acc += e.weight
		if roll <= acc then
			return e.category
		end
	end
	return "well"
end

-- ---------------------------------------------------------------- behavior

local function walkTo(v: Villager, target: Vector3, arriveMode: "enter" | "dwell" | "work")
	v.mode = "Routing"
	task.spawn(function()
		local path = PathfindingService:CreatePath({
			AgentRadius = 2.5,
			AgentHeight = 6,
			AgentCanJump = false,
			WaypointSpacing = 8,
		})
		local ok = pcall(function()
			path:ComputeAsync(v.root.Position, target)
		end)
		local waypoints: { Vector3 } = {}
		if ok and path.Status == Enum.PathStatus.Success then
			for _, wp in path:GetWaypoints() do
				table.insert(waypoints, wp.Position)
			end
		end
		if #waypoints == 0 then
			waypoints = { target }
		end
		v.waypoints = waypoints
		v.wpIndex = 1
		v.repathAt = 0
		v.mode = "Walking"
		v.model:SetAttribute("ArriveMode", arriveMode)
		v.walkTrack:Play()
	end)
end

local function chooseNext(v: Villager)
	local category = pickCategory(v)
	local pool = destinations[category]
	if not pool or #pool == 0 then
		category = "well"
		pool = destinations.well
	end
	local target = pool[v.rng:NextInteger(1, #pool)]
	local arriveMode: "enter" | "dwell" | "work" = if category == "house"
		then "enter"
		elseif category == "forge" then "work"
		else "dwell"
	walkTo(v, target, arriveMode)
end

local function onArrive(v: Villager)
	local persona = v.persona
	local now = os.clock()
	v.walkTrack:Stop(0.2)
	local arriveMode = v.model:GetAttribute("ArriveMode")
	if arriveMode == "enter" then
		v.mode = "Hidden"
		setHidden(v, true)
		v.timerUntil = now + v.rng:NextNumber(persona.hideMin, persona.hideMax)
	elseif arriveMode == "work" then
		v.mode = "Working"
		-- face the anvil (east of the AnvilSpot)
		v.root.CFrame = CFrame.lookAlong(v.root.Position, Vector3.xAxis)
		v.slashTrack:Play(0.2)
		v.timerUntil = now + v.rng:NextNumber(60, 150)
		v.sparkAt = now + 0.4
	else
		v.mode = "Idle"
		v.timerUntil = now + v.rng:NextNumber(persona.dwellMin, persona.dwellMax)
	end
end

local function update(v: Villager)
	local now = os.clock()

	if v.mode == "Walking" then
		local target = v.waypoints[v.wpIndex]
		if not target then
			onArrive(v)
			return
		end
		local delta = v.root.Position - target
		local flatDistance = Vector3.new(delta.X, 0, delta.Z).Magnitude
		if flatDistance < 3 then
			v.wpIndex += 1
			if v.wpIndex > #v.waypoints then
				onArrive(v)
			else
				v.humanoid:MoveTo(v.waypoints[v.wpIndex])
				v.repathAt = now + 4
			end
		elseif now >= v.repathAt then
			-- (re)issue MoveTo; also covers the humanoid's 8s auto-timeout
			v.humanoid:MoveTo(target)
			v.repathAt = now + 4
		end
	elseif v.mode == "Idle" then
		if now >= v.timerUntil then
			chooseNext(v)
		end
	elseif v.mode == "Working" then
		if now >= v.sparkAt then
			v.sparkAt = now + v.slashTrack.Length
			if anvilSparks then
				anvilSparks:Emit(14)
			end
		end
		if now >= v.timerUntil then
			v.slashTrack:Stop(0.2)
			chooseNext(v)
		end
	elseif v.mode == "Hidden" then
		if now >= v.timerUntil then
			setHidden(v, false)
			chooseNext(v)
		end
	end
	-- "Routing" waits for the async path computation
end

-- ---------------------------------------------------------------- init

function VillagerService.init()
	pcall(function()
		PhysicsService:RegisterCollisionGroup(VILLAGER_GROUP)
	end)
	-- Villagers pass through each other (no plaza traffic jams) but still
	-- collide with the world (Default group)
	PhysicsService:CollisionGroupSetCollidable(VILLAGER_GROUP, VILLAGER_GROUP, false)

	collectDestinations()

	local spawnSpots = {
		Vector3.new(-10, 0, 35),
		Vector3.new(8, 0, 42),
		Vector3.new(-6, 0, 60),
		Vector3.new(12, 0, 30),
		Vector3.new(0, 0, 68),
	}
	for index, persona in Catalog do
		task.spawn(function()
			local spot = spawnSpots[(index - 1) % #spawnSpots + 1]
			local jitter = Vector3.new((index * 7) % 11 - 5, 0, (index * 13) % 9 - 4)
			local v = buildRig(persona, spot + jitter)
			if v then
				-- stagger first errands so the crowd doesn't move in lockstep
				v.timerUntil = os.clock() + index * 1.5
				table.insert(villagers, v)
			end
		end)
	end

	RunService.Heartbeat:Connect(function()
		for _, v in villagers do
			update(v)
		end
	end)

	print("[Server] villagers dressing up and heading out")
end

return VillagerService
