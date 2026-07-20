--!strict
-- Drives the 15 ambient villagers: block-figure rigs with procedural walk
-- animation, real pathfinding around buildings/fences, and endless randomized
-- routines (walk somewhere -> dwell / enter a house / work the forge -> pick
-- the next errand). Routines never repeat because each next stop is drawn
-- from the persona's weights at runtime.

local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

local Catalog = require(script.Parent.VillagerCatalog)

type Persona = Catalog.Persona

local WALK_Y = 3 -- rig root height above ground when standing

type Villager = {
	persona: Persona,
	model: Model,
	torso: Part,
	head: Part,
	legL: Part,
	legR: Part,
	armL: Part,
	armR: Part,
	hammer: Part?,
	parts: { Part },
	mode: "Idle" | "Walking" | "Hidden" | "Working" | "Routing",
	pos: Vector3,
	look: Vector3,
	waypoints: { Vector3 },
	wpIndex: number,
	phase: number,
	timerUntil: number,
	rng: Random,
	swingT: number,
}

local VillagerService = {}

local villagers: { Villager } = {}
local destinations: { [string]: { Vector3 } } = {}
local anvilSparks: ParticleEmitter? = nil

-- ---------------------------------------------------------------- rig building

local function makeLimb(size: Vector3, color: Color3): Part
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local function buildRig(persona: Persona, spawnPos: Vector3): Villager
	local model = Instance.new("Model")
	model.Name = persona.name

	local torso = makeLimb(Vector3.new(2, 2, 1), persona.shirt)
	torso.Name = "Torso"
	local head = makeLimb(Vector3.new(1.5, 1.5, 1.5), persona.skin)
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	local legL = makeLimb(Vector3.new(0.8, 2, 0.8), persona.pants)
	local legR = makeLimb(Vector3.new(0.8, 2, 0.8), persona.pants)
	local armL = makeLimb(Vector3.new(0.6, 2, 0.6), persona.shirt)
	local armR = makeLimb(Vector3.new(0.6, 2, 0.6), persona.shirt)

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(160, 28)
	billboard.StudsOffset = Vector3.new(0, 1.6, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 60
	billboard.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = persona.name
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.TextScaled = true
	label.Font = Enum.Font.Gotham
	label.Parent = billboard

	local parts = { torso, head, legL, legR, armL, armR }

	local hammer: Part? = nil
	if persona.weights.forge > 0 then
		local h = makeLimb(Vector3.new(0.4, 1.6, 0.4), Color3.fromRGB(120, 90, 60))
		local headPiece = makeLimb(Vector3.new(1, 0.5, 0.6), Color3.fromRGB(90, 88, 86))
		headPiece.Name = "HammerHead"
		headPiece.Parent = h
		h.Name = "Hammer"
		hammer = h
		table.insert(parts, h)
	end

	for _, p in parts do
		p.Parent = model
	end
	if hammer then
		-- hammer head follows via its own CFrame each frame; parent for cleanup only
		(hammer:FindFirstChild("HammerHead") :: Part).Anchored = true
	end
	model.Parent = workspace

	return {
		persona = persona,
		model = model,
		torso = torso,
		head = head,
		legL = legL,
		legR = legR,
		armL = armL,
		armR = armR,
		hammer = hammer,
		parts = parts,
		mode = "Idle" :: "Idle",
		pos = spawnPos,
		look = Vector3.zAxis,
		waypoints = {},
		wpIndex = 1,
		phase = 0,
		timerUntil = 0,
		rng = Random.new(),
		swingT = 0,
	}
end

-- Poses all rig parts from the villager's position, facing and animation phase.
local function pose(v: Villager, dt: number)
	local walking = v.mode == "Walking"
	local swing = if walking then math.sin(v.phase) * 0.7 else 0
	local bob = if walking then math.abs(math.cos(v.phase)) * 0.15 else math.sin(os.clock() * 1.5 + v.phase) * 0.05

	local root = CFrame.lookAlong(v.pos + Vector3.new(0, bob, 0), v.look)

	v.torso.CFrame = root
	v.head.CFrame = root * CFrame.new(0, 1.75, 0)
	v.legL.CFrame = root * CFrame.new(-0.55, -1, 0) * CFrame.Angles(swing, 0, 0) * CFrame.new(0, -1, 0)
	v.legR.CFrame = root * CFrame.new(0.55, -1, 0) * CFrame.Angles(-swing, 0, 0) * CFrame.new(0, -1, 0)

	if v.mode == "Working" then
		-- Hammering: right arm swings hard, sparks at the bottom of the strike
		v.swingT += dt * 5
		local strike = math.sin(v.swingT)
		local armAngle = -0.6 - math.max(0, strike) * 1.5
		v.armR.CFrame = root * CFrame.new(1.15, 0.8, 0) * CFrame.Angles(armAngle, 0, 0) * CFrame.new(0, -1, 0)
		v.armL.CFrame = root * CFrame.new(-1.15, 0.8, 0) * CFrame.Angles(-0.3, 0, 0) * CFrame.new(0, -1, 0)
		local hammer = v.hammer
		if hammer then
			hammer.CFrame = v.armR.CFrame * CFrame.new(0, -1.2, -0.3) * CFrame.Angles(math.rad(90), 0, 0);
			(hammer:FindFirstChild("HammerHead") :: Part).CFrame = hammer.CFrame * CFrame.new(0, 0.85, 0)
		end
		-- Spark when the strike passes its low point
		local prev = math.sin(v.swingT - dt * 5)
		if strike >= 0.98 and prev < 0.98 and anvilSparks then
			anvilSparks:Emit(14)
		end
	else
		v.armL.CFrame = root * CFrame.new(-1.15, 0.8, 0) * CFrame.Angles(-swing * 0.6, 0, 0) * CFrame.new(0, -1, 0)
		v.armR.CFrame = root * CFrame.new(1.15, 0.8, 0) * CFrame.Angles(swing * 0.6, 0, 0) * CFrame.new(0, -1, 0)
		local hammer = v.hammer
		if hammer then
			-- carried at the hip when not working
			hammer.CFrame = v.torso.CFrame * CFrame.new(1.2, -0.8, 0.4) * CFrame.Angles(0, 0, math.rad(100));
			(hammer:FindFirstChild("HammerHead") :: Part).CFrame = hammer.CFrame * CFrame.new(0, 0.85, 0)
		end
	end
end

local function setHidden(v: Villager, hidden: boolean)
	for _, p in v.parts do
		p.Transparency = if hidden then 1 else 0
		for _, child in p:GetChildren() do
			if child:IsA("Part") then
				child.Transparency = if hidden then 1 else 0
			elseif child:IsA("BillboardGui") then
				child.Enabled = not hidden
			end
		end
	end
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
			AgentRadius = 2,
			AgentHeight = 6,
			AgentCanJump = false,
			WaypointSpacing = 8,
		})
		local ok = pcall(function()
			path:ComputeAsync(v.pos, target)
		end)
		local waypoints: { Vector3 } = {}
		if ok and path.Status == Enum.PathStatus.Success then
			for _, wp in path:GetWaypoints() do
				table.insert(waypoints, wp.Position)
			end
		end
		if #waypoints == 0 then
			waypoints = { target } -- fallback: straight line
		end
		v.waypoints = waypoints
		v.wpIndex = 1
		v.mode = "Walking"
		v.model:SetAttribute("ArriveMode", arriveMode)
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
	local arriveMode = v.model:GetAttribute("ArriveMode")
	if arriveMode == "enter" then
		v.mode = "Hidden"
		setHidden(v, true)
		v.timerUntil = os.clock() + v.rng:NextNumber(persona.hideMin, persona.hideMax)
	elseif arriveMode == "work" then
		v.mode = "Working"
		-- face the anvil (east of the AnvilSpot)
		v.look = Vector3.xAxis
		v.swingT = 0
		v.timerUntil = os.clock() + v.rng:NextNumber(60, 150)
	else
		v.mode = "Idle"
		v.timerUntil = os.clock() + v.rng:NextNumber(persona.dwellMin, persona.dwellMax)
	end
end

local function update(v: Villager, dt: number)
	local now = os.clock()

	if v.mode == "Walking" then
		local target = v.waypoints[v.wpIndex]
		if not target then
			onArrive(v)
			return
		end
		local goal = Vector3.new(target.X, target.Y + WALK_Y - 1.5, target.Z)
		local delta = goal - v.pos
		local flat = Vector3.new(delta.X, 0, delta.Z)
		local step = v.persona.speed * dt
		if delta.Magnitude <= step + 0.1 then
			v.pos = goal
			v.wpIndex += 1
			if v.wpIndex > #v.waypoints then
				onArrive(v)
			end
		else
			v.pos += delta.Unit * step
			if flat.Magnitude > 0.05 then
				v.look = flat.Unit
			end
			v.phase += dt * v.persona.speed * 1.4
		end
	elseif v.mode == "Idle" or v.mode == "Working" then
		if now >= v.timerUntil then
			chooseNext(v)
		end
	elseif v.mode == "Hidden" then
		if now >= v.timerUntil then
			setHidden(v, false)
			chooseNext(v)
		end
	end
	-- "Routing" waits for the path computation

	if v.mode ~= "Hidden" then
		pose(v, dt)
	end
end

-- ---------------------------------------------------------------- init

function VillagerService.init()
	collectDestinations()

	local spawnSpots = {
		Vector3.new(-10, 0, 35),
		Vector3.new(8, 0, 42),
		Vector3.new(-6, 0, 60),
		Vector3.new(12, 0, 30),
		Vector3.new(0, 0, 68),
	}
	for index, persona in Catalog do
		local spot = spawnSpots[(index - 1) % #spawnSpots + 1]
		local jitter = Vector3.new((index * 7) % 11 - 5, 0, (index * 13) % 9 - 4)
		local spawnPos = spot + jitter + Vector3.new(0, WALK_Y - 1.5 + 0.4, 0)
		local v = buildRig(persona, spawnPos)
		-- stagger the first errand so they don't all move in lockstep
		v.mode = "Idle"
		v.timerUntil = os.clock() + index * 1.5
		table.insert(villagers, v)
	end

	RunService.Heartbeat:Connect(function(dt)
		for _, v in villagers do
			update(v, dt)
		end
	end)

	print(`[Server] {#villagers} villagers going about their day`)
end

return VillagerService
