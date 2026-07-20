--!strict
-- The town proper, north of the farm hamlet: market plaza with stalls and a
-- well, the town hall, streets, and blocks of 2-3 story townhouses.

local PartUtil = require(script.Parent.PartUtil)
local HouseBuilder = require(script.Parent.HouseBuilder)

local part = PartUtil.part

local BEAM_COLOR = Color3.fromRGB(74, 52, 34)
local STONE_COLOR = Color3.fromRGB(130, 126, 120)

local PLASTER_TINTS = {
	Color3.fromRGB(232, 224, 205),
	Color3.fromRGB(226, 214, 186),
	Color3.fromRGB(211, 206, 198),
	Color3.fromRGB(236, 228, 214),
	Color3.fromRGB(219, 203, 178),
	Color3.fromRGB(224, 216, 190),
}
local ROOF_TINTS = {
	Color3.fromRGB(112, 66, 48),
	Color3.fromRGB(95, 70, 56),
	Color3.fromRGB(88, 78, 72),
	Color3.fromRGB(120, 58, 42),
}
local CANOPY_COLORS = {
	Color3.fromRGB(190, 60, 60),
	Color3.fromRGB(60, 110, 170),
	Color3.fromRGB(70, 140, 80),
	Color3.fromRGB(200, 150, 60),
	Color3.fromRGB(150, 80, 160),
	Color3.fromRGB(60, 150, 150),
}

local TownBuilder = {}

local function marketStall(parent: Instance, x: number, z: number, facing: number, colorIndex: number)
	local model = Instance.new("Model")
	model.Name = "MarketStall"
	local anchor = part({
		Name = "Anchor",
		Size = Vector3.new(1, 0.2, 1),
		Position = Vector3.new(0, 0.1, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	anchor.Parent = model
	model.PrimaryPart = anchor

	for _, px in { -3.5, 3.5 } do
		for _, pz in { -2, 2 } do
			part({
				Name = "StallPost",
				Size = Vector3.new(0.5, 7, 0.5),
				Position = Vector3.new(px, 3.5, pz),
				Color = BEAM_COLOR,
				Material = Enum.Material.Wood,
			}).Parent = model
		end
	end
	part({
		Name = "StallCounter",
		Size = Vector3.new(7.4, 1, 2),
		Position = Vector3.new(0, 2.6, 2),
		Color = Color3.fromRGB(133, 100, 67),
		Material = Enum.Material.WoodPlanks,
	}).Parent = model
	part({
		Name = "StallCanopy",
		Size = Vector3.new(8.6, 0.3, 6),
		CFrame = CFrame.new(0, 7.4, 0.4) * CFrame.Angles(math.rad(-10), 0, 0),
		Color = CANOPY_COLORS[(colorIndex - 1) % #CANOPY_COLORS + 1],
		Material = Enum.Material.Fabric,
	}).Parent = model
	part({
		Name = "StallCrate",
		Size = Vector3.new(1.6, 1.6, 1.6),
		Position = Vector3.new(-2, 0.8, -0.8),
		Color = Color3.fromRGB(160, 126, 80),
		Material = Enum.Material.WoodPlanks,
	}).Parent = model

	model.Parent = parent
	model:PivotTo(CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(facing), 0))
end

local function well(parent: Instance, x: number, z: number)
	part({
		Name = "WellRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.6, 8, 8),
		CFrame = CFrame.new(x, 1.3, z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = STONE_COLOR,
		Material = Enum.Material.Cobblestone,
	}).Parent = parent
	part({
		Name = "WellWater",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 6.6, 6.6),
		-- Sits 0.1 proud of the stone ring's top so the faces never share a plane
		CFrame = CFrame.new(x, 2.5, z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(40, 70, 100),
		Material = Enum.Material.Glass,
		Transparency = 0.2,
		CanCollide = false,
	}).Parent = parent
	for _, px in { -3.2, 3.2 } do
		part({
			Name = "WellPost",
			Size = Vector3.new(0.5, 6, 0.5),
			Position = Vector3.new(x + px, 3, z),
			Color = BEAM_COLOR,
			Material = Enum.Material.Wood,
		}).Parent = parent
	end
	part({
		Name = "WellRoof",
		Size = Vector3.new(8.4, 0.4, 5),
		CFrame = CFrame.new(x, 6.4, z) * CFrame.Angles(math.rad(18), 0, 0),
		Color = Color3.fromRGB(112, 66, 48),
		Material = Enum.Material.RoofShingles,
	}).Parent = parent
end

local function road(parent: Instance, centerX: number, centerZ: number, w: number, d: number, thickness: number?)
	local t = thickness or 0.2
	part({
		Name = "Road",
		Size = Vector3.new(w, t, d),
		Position = Vector3.new(centerX, t / 2, centerZ),
		Color = Color3.fromRGB(168, 158, 140),
		Material = Enum.Material.Cobblestone,
	}).Parent = parent
end

function TownBuilder.build(parentFolder: Instance)
	local town = Instance.new("Folder")
	town.Name = "Town"

	-- Streets: main road plaza->town hall, and two east-west side streets.
	-- (The plaza part itself is built by VillageBuilder; roads tuck under it.)
	road(town, 0, 93, 10, 27)
	road(town, 0, 75, 160, 6, 0.14)
	road(town, 0, 135, 160, 6, 0.14)

	well(town, 0, 50)

	-- Market stalls ringing the plaza, facing inward
	marketStall(town, -22, 32, 90, 1)
	marketStall(town, -22, 50, 90, 2)
	marketStall(town, -22, 68, 90, 3)
	marketStall(town, 22, 32, -90, 4)
	marketStall(town, 22, 68, -90, 5)
	marketStall(town, 20, 55, -90, 6) -- Baker Hobb's stall

	-- Town hall: 3 stories, stone ground floor, facing south over the plaza
	local hall = HouseBuilder.build(town, {
		name = "TownHall",
		position = Vector3.new(0, 0, 120),
		rotation = 180,
		width = 38,
		depth = 26,
		stories = 3,
		stoneGround = true,
		plasterColor = Color3.fromRGB(236, 228, 214),
		roofColor = Color3.fromRGB(88, 78, 72),
		doorWidth = 6,
		doorHeight = 7,
	})
	-- Clock face + bell cupola to mark it as civic
	part({
		Name = "ClockFace",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 6, 6),
		CFrame = CFrame.new(0, 18, 106.2) * CFrame.Angles(0, math.rad(90), 0),
		Color = Color3.fromRGB(240, 234, 216),
		Material = Enum.Material.SmoothPlastic,
	}).Parent = hall
	part({
		Name = "ClockHand",
		Size = Vector3.new(0.3, 2.2, 0.2),
		CFrame = CFrame.new(0, 18.8, 105.9) * CFrame.Angles(0, 0, math.rad(25)),
		Color = Color3.fromRGB(40, 36, 32),
		Material = Enum.Material.Metal,
		CanCollide = false,
	}).Parent = hall
	for _, px in { -2, 2 } do
		for _, pz in { -2, 2 } do
			part({
				Name = "CupolaPost",
				Size = Vector3.new(0.6, 4.4, 0.6),
				-- Bases embed into the hall roof slope; tops reach the cupola roof
				Position = Vector3.new(px, 30.6, 120 + pz),
				Color = BEAM_COLOR,
				Material = Enum.Material.Wood,
			}).Parent = hall
		end
	end
	part({
		Name = "CupolaRoof",
		Size = Vector3.new(6.5, 0.5, 6.5),
		Position = Vector3.new(0, 33, 120),
		Color = Color3.fromRGB(88, 78, 72),
		Material = Enum.Material.RoofShingles,
	}).Parent = hall
	part({
		Name = "Bell",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.8, 1.8, 1.8),
		Position = Vector3.new(0, 31.5, 120),
		Color = Color3.fromRGB(196, 164, 88),
		Material = Enum.Material.Metal,
		CanCollide = false,
	}).Parent = hall

	-- Townhouse blocks: two rows each side of the main axis, plus a north row
	-- behind the town hall. Deterministic variation from the index.
	local index = 0
	local function townhouse(x: number, z: number, rotation: number)
		index += 1
		HouseBuilder.build(town, {
			name = `Townhouse{index}`,
			position = Vector3.new(x, 0, z),
			rotation = rotation,
			width = 16 + (index * 5 % 3) * 2,
			depth = 13 + (index * 7 % 3) * 2,
			stories = if index % 3 == 0 then 3 else 2,
			stoneGround = index % 4 == 0,
			plasterColor = PLASTER_TINTS[(index - 1) % #PLASTER_TINTS + 1],
			roofColor = ROOF_TINTS[(index - 1) % #ROOF_TINTS + 1],
		})
	end

	local rowZs = { 30, 60, 90, 120, 150, 180 }
	for _, z in rowZs do
		townhouse(-40, z, 90) -- west inner row, facing east
		townhouse(-72, z, 90) -- west outer row
		townhouse(40, z, -90) -- east inner row, facing west
		townhouse(72, z, -90) -- east outer row
	end
	for _, x in { -75, -45, -15, 15, 45, 75 } do
		townhouse(x, 210, 180) -- north row, facing south
	end

	town.Parent = parentFolder
	return town
end

return TownBuilder
