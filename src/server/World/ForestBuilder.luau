--!strict
-- Dense forest surrounding the settled valley, with a corridor kept clear for
-- the main road running north and south, plus the road itself and the village
-- gates. Deterministic (seeded) so every server builds the same forest.

local PartUtil = require(script.Parent.PartUtil)
local part = PartUtil.part

local BEAM_COLOR = Color3.fromRGB(74, 52, 34)

-- The settled area trees must stay out of
local SETTLE_X = 200
local SETTLE_Z_MIN = -195
local SETTLE_Z_MAX = 245
-- Road corridor half-width (trees keep clear of the north/south road)
local ROAD_CLEAR = 16

local ForestBuilder = {}

local function tree(parent: Instance, x: number, z: number, scale: number, shade: number)
	local trunkColor = Color3.fromRGB(92 - shade * 10, 64 - shade * 6, 44)
	local leafColor = Color3.fromRGB(56 + shade * 12, 100 + shade * 14, 48 + shade * 8)
	part({
		Name = "TreeTrunk",
		Size = Vector3.new(2 * scale, 12 * scale, 2 * scale),
		Position = Vector3.new(x, 6 * scale, z),
		Color = trunkColor,
		Material = Enum.Material.Wood,
	}).Parent = parent
	part({
		Name = "TreeCanopy",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(11 * scale, 11 * scale, 11 * scale),
		Position = Vector3.new(x, 13 * scale, z),
		Color = leafColor,
		Material = Enum.Material.LeafyGrass,
		CanCollide = false,
	}).Parent = parent
	part({
		Name = "TreeCanopyTop",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(7 * scale, 7 * scale, 7 * scale),
		Position = Vector3.new(x + 1.5 * scale, 17 * scale, z + scale),
		Color = leafColor:Lerp(Color3.new(1, 1, 1), 0.08),
		Material = Enum.Material.LeafyGrass,
		CanCollide = false,
	}).Parent = parent
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

	-- The main road running out of the valley through the woods
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

	-- Seeded scatter of trees (and the odd rock) everywhere outside the
	-- settlement and off the road corridor
	local rng = Random.new(7341)
	local planted = 0
	local attempts = 0
	while planted < 420 and attempts < 2600 do
		attempts += 1
		local x = rng:NextNumber(-540, 540)
		local z = rng:NextNumber(-500, 560)
		local inSettlement = math.abs(x) < SETTLE_X and z > SETTLE_Z_MIN and z < SETTLE_Z_MAX
		local onRoad = math.abs(x) < ROAD_CLEAR and (z <= SETTLE_Z_MIN or z >= SETTLE_Z_MAX)
		if inSettlement or onRoad then
			continue
		end
		if attempts % 9 == 0 then
			rock(forest, x, z, 0.7 + rng:NextNumber() * 1.1)
		else
			tree(forest, x, z, 0.9 + rng:NextNumber() * 0.9, rng:NextInteger(0, 2))
		end
		planted += 1
	end

	forest.Parent = parentFolder
	return forest
end

return ForestBuilder
