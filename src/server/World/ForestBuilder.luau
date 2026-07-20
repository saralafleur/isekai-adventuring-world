--!strict
-- Dense, realistic forest surrounding the settled valley.
--
-- Structure: a thick DENSE BELT of trees + undergrowth hugs the settlement
-- edge (this is what players actually look into — canopies overlap and bushes
-- fill the ground layer, so you can't see through it), thinning to scattered
-- larger trees deeper out. Three species with per-tree size/color/rotation
-- variation: broadleaf oaks (clustered irregular canopies + branches), tall
-- pines (stacked tapering foliage), and pale-trunked birches.
--
-- The main road's corridor and the two gates stay clear. Deterministic
-- (seeded) so every server builds the same forest.

local PartUtil = require(script.Parent.PartUtil)
local part = PartUtil.part

local BEAM_COLOR = Color3.fromRGB(74, 52, 34)

local SETTLE_X = 200
local SETTLE_Z_MIN = -195
local SETTLE_Z_MAX = 245
local ROAD_CLEAR = 16
local BELT_DEPTH = 60 -- dense-forest band just outside the settlement

local ForestBuilder = {}

-- ------------------------------------------------------------------ species

local function trunkPart(parent: Instance, x: number, z: number, height: number, diameter: number, color: Color3, tilt: number, yaw: number): Part
	local trunk = part({
		Name = "TreeTrunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(x, height / 2, z)
			* CFrame.Angles(0, yaw, 0)
			* CFrame.Angles(0, 0, math.rad(90) + tilt),
		Color = color,
		Material = Enum.Material.Wood,
	})
	trunk.Parent = parent
	return trunk
end

local function canopyBall(parent: Instance, pos: Vector3, size: Vector3, color: Color3)
	part({
		Name = "TreeCanopy",
		Shape = Enum.PartType.Ball,
		Size = size,
		Position = pos,
		Color = color,
		Material = Enum.Material.LeafyGrass,
		CanCollide = false,
	}).Parent = parent
end

local function oak(parent: Instance, x: number, z: number, scale: number, rng: Random)
	local trunkColor = Color3.fromRGB(88 + rng:NextInteger(-8, 8), 62 + rng:NextInteger(-6, 6), 42)
	local baseGreen = Color3.fromRGB(52 + rng:NextInteger(0, 28), 96 + rng:NextInteger(0, 34), 44 + rng:NextInteger(0, 20))
	local h = 11 * scale
	local tilt = math.rad(rng:NextNumber(-4, 4))
	local yaw = rng:NextNumber(0, math.pi * 2)
	-- root flare + trunk
	trunkPart(parent, x, z, 1.6 * scale, 3.4 * scale, trunkColor, 0, 0)
	trunkPart(parent, x, z, h, 2.2 * scale, trunkColor, tilt, yaw)
	-- two branches reaching out of the upper trunk
	for i = 1, 2 do
		local branchYaw = yaw + i * math.pi * rng:NextNumber(0.6, 1.1)
		local branchLen = rng:NextNumber(4, 6) * scale
		part({
			Name = "TreeBranch",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(branchLen, 0.8 * scale, 0.8 * scale),
			CFrame = CFrame.new(x, h * 0.75, z)
				* CFrame.Angles(0, branchYaw, 0)
				* CFrame.Angles(0, 0, math.rad(rng:NextNumber(20, 40)))
				* CFrame.new(branchLen / 2, 0, 0),
			Color = trunkColor,
			Material = Enum.Material.Wood,
			CanCollide = false,
		}).Parent = parent
	end
	-- clustered irregular canopy: one core + 4 offset lobes
	local canopyY = h + 3.5 * scale
	local coreSize = rng:NextNumber(11, 13.5) * scale
	canopyBall(parent, Vector3.new(x, canopyY, z), Vector3.new(coreSize, coreSize * 0.92, coreSize), baseGreen)
	for i = 1, 4 do
		local lobeYaw = yaw + i * math.pi / 2 + rng:NextNumber(-0.5, 0.5)
		local lobeRadius = rng:NextNumber(3.4, 5) * scale
		local lobeSize = rng:NextNumber(6.5, 9) * scale
		canopyBall(
			parent,
			Vector3.new(
				x + math.cos(lobeYaw) * lobeRadius,
				canopyY + rng:NextNumber(-2, 3) * scale,
				z + math.sin(lobeYaw) * lobeRadius
			),
			Vector3.new(lobeSize, lobeSize * 0.9, lobeSize),
			baseGreen:Lerp(Color3.new(1, 1, 1), rng:NextNumber(0, 0.12))
		)
	end
end

local function pine(parent: Instance, x: number, z: number, scale: number, rng: Random)
	local trunkColor = Color3.fromRGB(76 + rng:NextInteger(-6, 6), 54, 38)
	local needle = Color3.fromRGB(34 + rng:NextInteger(0, 14), 72 + rng:NextInteger(0, 18), 40 + rng:NextInteger(0, 10))
	local h = 17 * scale
	trunkPart(parent, x, z, h, 1.7 * scale, trunkColor, math.rad(rng:NextNumber(-2, 2)), rng:NextNumber(0, math.pi))
	-- stacked, tapering foliage tiers
	local tierWidth = 11 * scale
	local tierY = 7.5 * scale
	for _ = 1, 4 do
		canopyBall(
			parent,
			Vector3.new(x + rng:NextNumber(-0.5, 0.5), tierY, z + rng:NextNumber(-0.5, 0.5)),
			Vector3.new(tierWidth, tierWidth * 0.5, tierWidth),
			needle
		)
		tierY += tierWidth * 0.3
		tierWidth *= 0.72
	end
	-- tip
	canopyBall(parent, Vector3.new(x, tierY + 0.6 * scale, z), Vector3.new(2.6 * scale, 3.4 * scale, 2.6 * scale), needle)
end

local function birch(parent: Instance, x: number, z: number, scale: number, rng: Random)
	local bark = Color3.fromRGB(214, 206, 192)
	local leaf = Color3.fromRGB(96 + rng:NextInteger(0, 24), 138 + rng:NextInteger(0, 20), 58)
	local h = 12 * scale
	trunkPart(parent, x, z, h, 1.3 * scale, bark, math.rad(rng:NextNumber(-6, 6)), rng:NextNumber(0, math.pi))
	local canopyY = h + 1.8 * scale
	for i = 0, 2 do
		local size = rng:NextNumber(5.5, 7.5) * scale
		canopyBall(
			parent,
			Vector3.new(x + rng:NextNumber(-2, 2), canopyY + i * 1.6 * scale, z + rng:NextNumber(-2, 2)),
			Vector3.new(size, size * 0.85, size),
			leaf:Lerp(Color3.new(1, 1, 1), rng:NextNumber(0, 0.1))
		)
	end
end

local function bush(parent: Instance, x: number, z: number, rng: Random)
	local green = Color3.fromRGB(58 + rng:NextInteger(0, 26), 96 + rng:NextInteger(0, 30), 46)
	for i = 0, 1 do
		local size = rng:NextNumber(2.4, 4.2)
		canopyBall(
			parent,
			Vector3.new(x + i * rng:NextNumber(-1.5, 1.5), size * 0.4, z + i * rng:NextNumber(-1.5, 1.5)),
			Vector3.new(size, size * 0.75, size),
			green
		)
	end
end

local function rock(parent: Instance, x: number, z: number, scale: number)
	part({
		Name = "Rock",
		Size = Vector3.new(3 * scale, 2 * scale, 2.5 * scale),
		CFrame = CFrame.new(x, scale * 0.8, z) * CFrame.Angles(0, scale * 7, math.rad(8)),
		Color = Color3.fromRGB(126, 122, 116),
		Material = Enum.Material.Rock,
	}).Parent = parent
end

-- ------------------------------------------------------------------ layout

-- How far outside the settlement rectangle a point is (0 = inside)
local function outsideDistance(x: number, z: number): number
	local ox = math.max(0, math.abs(x) - SETTLE_X)
	local oz = math.max(0, z - SETTLE_Z_MAX, SETTLE_Z_MIN - z)
	return math.max(ox, oz)
end

local function onRoadCorridor(x: number, z: number): boolean
	return math.abs(x) < ROAD_CLEAR and (z <= SETTLE_Z_MIN or z >= SETTLE_Z_MAX)
end

local function plantTree(parent: Instance, x: number, z: number, rng: Random)
	local roll = rng:NextNumber()
	local scale = 0.85 + rng:NextNumber() * 0.75
	if roll < 0.52 then
		oak(parent, x, z, scale, rng)
	elseif roll < 0.82 then
		pine(parent, x, z, scale, rng)
	else
		birch(parent, x, z, scale, rng)
	end
end

local function gate(parent: Instance, z: number)
	for _, x in { -7, 7 } do
		part({
			Name = "GatePost",
			Size = Vector3.new(1.6, 12, 1.6),
			Position = Vector3.new(x, 6, z),
			Color = BEAM_COLOR,
			Material = Enum.Material.Wood,
		}).Parent = parent
	end
	part({
		Name = "GateBeam",
		Size = Vector3.new(17, 1.4, 1.6),
		Position = Vector3.new(0, 11.3, z),
		Color = BEAM_COLOR,
		Material = Enum.Material.Wood,
	}).Parent = parent
	part({
		Name = "GateSign",
		Size = Vector3.new(5, 1.6, 0.4),
		Position = Vector3.new(0, 9.6, z),
		Color = Color3.fromRGB(120, 90, 60),
		Material = Enum.Material.WoodPlanks,
	}).Parent = parent
	for _, x in { -7, 7 } do
		local lamp = part({
			Name = "GateLantern",
			Size = Vector3.new(0.8, 1.1, 0.8),
			Position = Vector3.new(x, 9.4, z + 1.1),
			Color = Color3.fromRGB(255, 214, 130),
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 200, 110)
		light.Brightness = 1
		light.Range = 14
		light.Parent = lamp
		lamp.Parent = parent
	end
end

function ForestBuilder.build(parentFolder: Instance)
	local forest = Instance.new("Folder")
	forest.Name = "Forest"

	part({
		Name = "SouthRoad",
		Size = Vector3.new(12, 0.24, 330),
		Position = Vector3.new(0, 0.12, -350),
		Color = Color3.fromRGB(150, 125, 95),
		Material = Enum.Material.Ground,
	}).Parent = forest
	part({
		Name = "NorthRoad",
		Size = Vector3.new(12, 0.24, 330),
		Position = Vector3.new(0, 0.12, 405),
		Color = Color3.fromRGB(150, 125, 95),
		Material = Enum.Material.Ground,
	}).Parent = forest

	gate(forest, -188)
	gate(forest, 240)

	local rng = Random.new(7341)

	-- Dense belt: tightly packed trees + undergrowth just outside the
	-- settlement — the wall of forest you can't see through
	local beltTrees = 0
	local attempts = 0
	while beltTrees < 620 and attempts < 26000 do
		attempts += 1
		local x = rng:NextNumber(-SETTLE_X - BELT_DEPTH - 10, SETTLE_X + BELT_DEPTH + 10)
		local z = rng:NextNumber(SETTLE_Z_MIN - BELT_DEPTH - 10, SETTLE_Z_MAX + BELT_DEPTH + 10)
		local dist = outsideDistance(x, z)
		if dist <= 2 or dist > BELT_DEPTH or onRoadCorridor(x, z) then
			continue
		end
		plantTree(forest, x, z, rng)
		beltTrees += 1
	end

	-- Undergrowth in and just inside the belt: bushes kill the remaining
	-- ground-level sightlines
	local bushes = 0
	attempts = 0
	while bushes < 480 and attempts < 20000 do
		attempts += 1
		local x = rng:NextNumber(-SETTLE_X - BELT_DEPTH - 10, SETTLE_X + BELT_DEPTH + 10)
		local z = rng:NextNumber(SETTLE_Z_MIN - BELT_DEPTH - 10, SETTLE_Z_MAX + BELT_DEPTH + 10)
		local dist = outsideDistance(x, z)
		if dist <= 1 or dist > BELT_DEPTH + 6 or onRoadCorridor(x, z) then
			continue
		end
		bush(forest, x, z, rng)
		bushes += 1
	end

	-- Outer woods: scattered larger trees and rocks filling the horizon
	local outer = 0
	attempts = 0
	while outer < 280 and attempts < 8000 do
		attempts += 1
		local x = rng:NextNumber(-540, 540)
		local z = rng:NextNumber(-500, 560)
		local dist = outsideDistance(x, z)
		if dist <= BELT_DEPTH or onRoadCorridor(x, z) then
			continue
		end
		if attempts % 10 == 0 then
			rock(forest, x, z, 0.7 + rng:NextNumber() * 1.1)
		else
			plantTree(forest, x, z, rng)
		end
		outer += 1
	end

	forest.Parent = parentFolder
	return forest
end

return ForestBuilder
