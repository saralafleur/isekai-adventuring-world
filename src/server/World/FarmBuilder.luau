--!strict
-- The farming hamlet around the Rowan cottage: farmhouses, barn, silo,
-- windmill, sheds, fenced wheat fields, and dirt lanes.

local PartUtil = require(script.Parent.PartUtil)
local HouseBuilder = require(script.Parent.HouseBuilder)

local part = PartUtil.part

local BEAM_COLOR = Color3.fromRGB(74, 52, 34)
local WHEAT_COLOR = Color3.fromRGB(222, 188, 92)

local FarmBuilder = {}

local function fence(parent: Instance, centerX: number, centerZ: number, w: number, d: number)
	local halfW = w / 2 + 1.5
	local halfD = d / 2 + 1.5
	local postSpacing = 6

	local function run(x0: number, z0: number, x1: number, z1: number)
		local p0 = Vector3.new(x0, 0, z0)
		local p1 = Vector3.new(x1, 0, z1)
		local length = (p1 - p0).Magnitude
		local dir = (p1 - p0).Unit
		local count = math.floor(length / postSpacing)
		for i = 0, count do
			local pos = p0 + dir * math.min(i * postSpacing, length)
			part({
				Name = "FencePost",
				Size = Vector3.new(0.5, 3, 0.5),
				Position = Vector3.new(pos.X, 1.5, pos.Z),
				Color = BEAM_COLOR,
				Material = Enum.Material.Wood,
			}).Parent = parent
		end
		local mid = (p0 + p1) / 2
		local alongX = math.abs(dir.X) > 0.5
		for _, y in { 1.2, 2.4 } do
			part({
				Name = "FenceRail",
				Size = if alongX then Vector3.new(length, 0.3, 0.3) else Vector3.new(0.3, 0.3, length),
				Position = Vector3.new(mid.X, y, mid.Z),
				Color = BEAM_COLOR,
				Material = Enum.Material.Wood,
			}).Parent = parent
		end
	end

	run(centerX - halfW, centerZ - halfD, centerX + halfW, centerZ - halfD)
	run(centerX - halfW, centerZ + halfD, centerX + halfW, centerZ + halfD)
	run(centerX - halfW, centerZ - halfD, centerX - halfW, centerZ + halfD)
	run(centerX + halfW, centerZ - halfD, centerX + halfW, centerZ + halfD)
end

local function wheatField(parent: Instance, centerX: number, centerZ: number, w: number, d: number)
	part({
		Name = "FieldSoil",
		Size = Vector3.new(w, 0.3, d),
		Position = Vector3.new(centerX, 0.15, centerZ),
		Color = Color3.fromRGB(96, 74, 56),
		Material = Enum.Material.Ground,
	}).Parent = parent

	local spacing = 3
	local cols = math.floor(w / spacing) - 1
	local rows = math.floor(d / spacing) - 1
	for ix = 1, cols do
		for iz = 1, rows do
			local h = 2.4 + ((ix + iz) % 3) * 0.3
			part({
				Name = "Wheat",
				Size = Vector3.new(1.4, h, 1.4),
				Position = Vector3.new(
					centerX - w / 2 + ix * spacing,
					0.3 + h / 2,
					centerZ - d / 2 + iz * spacing
				),
				Color = WHEAT_COLOR,
				Material = Enum.Material.Grass,
				CanCollide = false,
			}).Parent = parent
		end
	end

	fence(parent, centerX, centerZ, w, d)
	-- NPC work spots just outside the fence
	PartUtil.marker("FieldSpot", Vector3.new(centerX - w / 2 - 4, 0.5, centerZ)).Parent = parent
	PartUtil.marker("FieldSpot", Vector3.new(centerX + w / 2 + 4, 0.5, centerZ + 3)).Parent = parent
end

local function silo(parent: Instance, x: number, z: number)
	local body = part({
		Name = "Silo",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(16, 8, 8),
		CFrame = CFrame.new(x, 8, z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(168, 160, 150),
		Material = Enum.Material.Metal,
	})
	body.Parent = parent
	part({
		Name = "SiloCap",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(8, 8, 8),
		Position = Vector3.new(x, 16.5, z),
		Color = Color3.fromRGB(140, 60, 50),
		Material = Enum.Material.Metal,
	}).Parent = parent
end

local function windmill(parent: Instance, x: number, z: number)
	part({
		Name = "WindmillTower",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(22, 13, 13),
		CFrame = CFrame.new(x, 11, z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(150, 142, 130),
		Material = Enum.Material.Cobblestone,
	}).Parent = parent
	part({
		Name = "WindmillCap",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(13, 13, 13),
		Position = Vector3.new(x, 23, z),
		Color = Color3.fromRGB(112, 66, 48),
		Material = Enum.Material.Wood,
	}).Parent = parent
	-- Hub and four static sails on the south face
	local hubZ = z + 6.8
	part({
		Name = "WindmillHub",
		Size = Vector3.new(1.6, 1.6, 1.6),
		Position = Vector3.new(x, 20, hubZ),
		Color = BEAM_COLOR,
		Material = Enum.Material.Wood,
	}).Parent = parent
	for i = 0, 3 do
		part({
			Name = "WindmillSail",
			Size = Vector3.new(2.2, 16, 0.3),
			CFrame = CFrame.new(x, 20, hubZ + 0.2) * CFrame.Angles(0, 0, math.rad(45 + i * 90)) * CFrame.new(0, 8, 0),
			Color = Color3.fromRGB(235, 228, 210),
			Material = Enum.Material.Fabric,
			CanCollide = false,
		}).Parent = parent
	end
end

-- thickness: overlapping lanes must differ in height so their top surfaces
-- never share a plane (z-fighting).
local function dirtLane(parent: Instance, centerX: number, centerZ: number, w: number, d: number, thickness: number?)
	local t = thickness or 0.24
	part({
		Name = "DirtLane",
		Size = Vector3.new(w, t, d),
		Position = Vector3.new(centerX, t / 2, centerZ),
		Color = Color3.fromRGB(150, 125, 95),
		Material = Enum.Material.Ground,
	}).Parent = parent
end

function FarmBuilder.build(parentFolder: Instance)
	local farm = Instance.new("Folder")
	farm.Name = "FarmHamlet"

	-- Farmhouses
	HouseBuilder.build(farm, {
		name = "FarmhouseWest",
		position = Vector3.new(-50, 0, -70),
		rotation = 90,
		width = 18,
		depth = 14,
		stories = 1,
		plasterColor = Color3.fromRGB(226, 214, 186),
	})
	HouseBuilder.build(farm, {
		name = "FarmhouseSouth",
		position = Vector3.new(-45, 0, -110),
		rotation = 0,
		width = 20,
		depth = 15,
		stories = 2,
		plasterColor = Color3.fromRGB(220, 206, 180),
	})

	-- Barn: tall single story, big door, red walls with pale trim
	HouseBuilder.build(farm, {
		name = "Barn",
		position = Vector3.new(45, 0, -80),
		rotation = -90,
		width = 20,
		depth = 16,
		stories = 1,
		storyHeight = 12,
		doorWidth = 8,
		doorHeight = 8,
		plasterColor = Color3.fromRGB(152, 46, 38),
		beamColor = Color3.fromRGB(228, 220, 205),
		roofColor = Color3.fromRGB(70, 62, 58),
	})
	silo(farm, 62, -85)

	-- Sheds
	HouseBuilder.build(farm, {
		name = "ToolShed",
		position = Vector3.new(70, 0, -50),
		rotation = -90,
		width = 10,
		depth = 8,
		stories = 1,
		storyHeight = 6,
		plasterColor = Color3.fromRGB(190, 172, 140),
	})
	HouseBuilder.build(farm, {
		name = "CoopShed",
		position = Vector3.new(52, 0, -34),
		rotation = 180,
		width = 8,
		depth = 8,
		stories = 1,
		storyHeight = 5,
		doorWidth = 3,
		doorHeight = 4,
		plasterColor = Color3.fromRGB(200, 180, 150),
	})

	windmill(farm, -90, -140)

	-- Wheat fields
	wheatField(farm, -85, -60, 30, 20)
	wheatField(farm, -85, -105, 30, 24)
	wheatField(farm, 30, -115, 34, 22)

	-- Dirt lanes linking the hamlet to the cottage path
	dirtLane(farm, -40, -60, 60, 8) -- west lane to the farmhouses/fields
	dirtLane(farm, 40, -60, 60, 8) -- east lane to the barn
	-- Spur skirts EAST of the cottage (between cottage and chicken pen) down to
	-- the lanes; slightly thicker so its top clears the lanes where they overlap
	dirtLane(farm, 20.5, -40, 8, 44, 0.3)

	farm.Parent = parentFolder
	return farm
end

return FarmBuilder
