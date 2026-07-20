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
	-- NPC destination in front of the counter
	PartUtil.marker("BrowseSpot", Vector3.new(0, 0.5, 5)).Parent = model

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
	-- NPC loitering spots around the well
	PartUtil.marker("GatherSpot", Vector3.new(x + 6, 0.9, z)).Parent = parent
	PartUtil.marker("GatherSpot", Vector3.new(x - 6, 0.9, z + 2)).Parent = parent
	PartUtil.marker("GatherSpot", Vector3.new(x, 0.9, z - 6)).Parent = parent
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

	-- Town hall: 3 stories, stone ground floor, facing south over the plaza.
	-- Interior is custom-built below (assembly hall + records balcony).
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
		interior = "none",
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

	-- ---------------- town hall interior: assembly hall
	-- Interior region: x -18.5..18.5, z 107.5..132.5 (door south at z 107)
	local BENCH_WOOD = Color3.fromRGB(110, 78, 48)
	for _, z in { 111.5, 114.5, 117.5, 120.5 } do
		for _, x in { -5.5, 5.5 } do
			part({ Name = "HallBench", Size = Vector3.new(6, 1.5, 1.2), Position = Vector3.new(x, 1.85, z), Color = BENCH_WOOD, Material = Enum.Material.WoodPlanks }).Parent = hall
			part({ Name = "HallBenchBack", Size = Vector3.new(6, 1.2, 0.3), Position = Vector3.new(x, 3.1, z + 0.45), Color = BENCH_WOOD, Material = Enum.Material.WoodPlanks }).Parent = hall
		end
	end
	-- Dais with podium and council table
	part({ Name = "Dais", Size = Vector3.new(16, 0.8, 6), Position = Vector3.new(0, 1.5, 128.5), Color = Color3.fromRGB(120, 90, 60), Material = Enum.Material.WoodPlanks }).Parent = hall
	part({ Name = "Podium", Size = Vector3.new(1.4, 3.1, 1.2), Position = Vector3.new(0, 3.45, 126.3), Color = BEAM_COLOR, Material = Enum.Material.Wood }).Parent = hall
	part({ Name = "PodiumTop", Size = Vector3.new(1.8, 0.3, 1.5), Position = Vector3.new(0, 5.1, 126.3), Color = Color3.fromRGB(96, 62, 38), Material = Enum.Material.Wood }).Parent = hall
	part({ Name = "CouncilTable", Size = Vector3.new(8, 0.5, 2.5), Position = Vector3.new(0, 4.15, 130.3), Color = BENCH_WOOD, Material = Enum.Material.WoodPlanks }).Parent = hall
	for _, x in { -3.4, 3.4 } do
		part({ Name = "CouncilTableLeg", Size = Vector3.new(0.5, 2, 2), Position = Vector3.new(x, 2.9, 130.3), Color = BEAM_COLOR, Material = Enum.Material.Wood }).Parent = hall
	end
	for _, x in { -2.6, 0, 2.6 } do
		part({ Name = "CouncilChair", Size = Vector3.new(1.4, 1.6, 1.3), Position = Vector3.new(x, 2.7, 131.6), Color = BENCH_WOOD, Material = Enum.Material.Wood }).Parent = hall
	end
	-- Banners on the north interior wall
	for _, x in { -7, 7 } do
		part({ Name = "HallBanner", Size = Vector3.new(2.4, 7, 0.2), Position = Vector3.new(x, 11.5, 132.2), Color = Color3.fromRGB(160, 40, 40), Material = Enum.Material.Fabric, CanCollide = false }).Parent = hall
	end
	-- Stairs along the east wall up to the records balcony (rise toward +Z)
	local wedgePart = Instance.new("WedgePart")
	wedgePart.Name = "HallStairRamp"
	wedgePart.Anchored = true
	wedgePart.Size = Vector3.new(3.2, 7, 9.6)
	wedgePart.CFrame = CFrame.new(16.8, 4.5, 119.4) * CFrame.Angles(0, math.pi, 0)
	wedgePart.Color = Color3.fromRGB(133, 100, 67)
	wedgePart.Material = Enum.Material.WoodPlanks
	wedgePart.TopSurface = Enum.SurfaceType.Smooth
	wedgePart.BottomSurface = Enum.SurfaceType.Smooth
	wedgePart.Parent = hall
	-- Balcony plate over the dais end
	part({ Name = "BalconyPlate", Size = Vector3.new(36.5, 0.5, 7.9), Position = Vector3.new(0, 7.75, 128.2), Color = Color3.fromRGB(133, 100, 67), Material = Enum.Material.WoodPlanks }).Parent = hall
	-- Railing along the balcony edge, leaving the stair arrival gap on the east
	part({ Name = "BalconyRail", Size = Vector3.new(33, 0.3, 0.3), Position = Vector3.new(-1.6, 10.7, 124.4), Color = Color3.fromRGB(96, 62, 38), Material = Enum.Material.Wood }).Parent = hall
	for _, x in { -17.9, -12, -6, 0, 6, 12, 14.6 } do
		part({ Name = "BalconyPost", Size = Vector3.new(0.3, 2.8, 0.3), Position = Vector3.new(x, 9.4, 124.4), Color = BEAM_COLOR, Material = Enum.Material.Wood }).Parent = hall
	end
	-- Records desk and shelf on the balcony
	part({ Name = "RecordsDesk", Size = Vector3.new(3.6, 0.4, 2), Position = Vector3.new(-8, 10.2, 130.4), Color = BENCH_WOOD, Material = Enum.Material.WoodPlanks }).Parent = hall
	part({ Name = "RecordsShelf", Size = Vector3.new(6, 4.5, 1), Position = Vector3.new(6, 10.25, 131.7), Color = Color3.fromRGB(96, 62, 38), Material = Enum.Material.WoodPlanks }).Parent = hall
	-- Chandeliers hanging from collar beams high in the open hall
	for _, z in { 112, 120 } do
		part({ Name = "HallCollarBeam", Size = Vector3.new(36, 0.5, 0.7), Position = Vector3.new(0, 21.85, z), Color = BEAM_COLOR, Material = Enum.Material.Wood, CanCollide = false }).Parent = hall
		part({ Name = "ChandelierChain", Size = Vector3.new(0.18, 6.4, 0.18), Position = Vector3.new(0, 18.7, z), Color = Color3.fromRGB(80, 80, 80), Material = Enum.Material.Metal, CanCollide = false }).Parent = hall
		local chandelier = part({
			Name = "Chandelier",
			Size = Vector3.new(1.4, 1.2, 1.4),
			Position = Vector3.new(0, 15.2, z),
			Color = Color3.fromRGB(255, 214, 130),
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		local chandelierLight = Instance.new("PointLight")
		chandelierLight.Color = Color3.fromRGB(255, 205, 120)
		chandelierLight.Brightness = 1.4
		chandelierLight.Range = 24
		chandelierLight.Parent = chandelier
		chandelier.Parent = hall
	end
	-- Under-balcony light over the dais
	part({ Name = "DaisLampChain", Size = Vector3.new(0.18, 1.6, 0.18), Position = Vector3.new(0, 6.9, 129), Color = Color3.fromRGB(80, 80, 80), Material = Enum.Material.Metal, CanCollide = false }).Parent = hall
	local daisLamp = part({
		Name = "DaisLamp",
		Size = Vector3.new(0.9, 1.1, 0.9),
		Position = Vector3.new(0, 5.75, 129),
		Color = Color3.fromRGB(255, 214, 130),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	local daisLight = Instance.new("PointLight")
	daisLight.Color = Color3.fromRGB(255, 205, 120)
	daisLight.Brightness = 1
	daisLight.Range = 14
	daisLight.Parent = daisLamp
	daisLamp.Parent = hall

	-- Townhouse blocks: two rows each side of the main axis, plus a north row
	-- behind the town hall. Deterministic variation from the index.
	-- Townhouses: larger footprints so every one holds a real furnished
	-- interior (living floor + bedrooms + stairs).
	local index = 0
	local function townhouse(x: number, z: number, rotation: number)
		index += 1
		HouseBuilder.build(town, {
			name = `Townhouse{index}`,
			position = Vector3.new(x, 0, z),
			rotation = rotation,
			width = 20 + (index * 5 % 2) * 2,
			depth = 16 + (index * 7 % 2) * 2,
			stories = if index % 3 == 0 then 3 else 2,
			stoneGround = index % 4 == 0,
			plasterColor = PLASTER_TINTS[(index - 1) % #PLASTER_TINTS + 1],
			roofColor = ROOF_TINTS[(index - 1) % #ROOF_TINTS + 1],
			seed = index,
		})
	end

	local rowZs = { 30, 60, 90, 120, 150, 180 }
	for _, z in rowZs do
		if z ~= 30 and z ~= 60 then -- the bigger guild halls own the z 30-73 band
			townhouse(-42, z, 90) -- west inner row, facing east
			townhouse(42, z, -90) -- east inner row, facing west
		end
		townhouse(-76, z, 90) -- west outer row
		townhouse(76, z, -90) -- east outer row
	end
	-- North row leaves the x ±6 road corridor clear (the north road to the
	-- forest gate runs between them)
	for _, x in { -80, -50, -20, 20, 50, 80 } do
		townhouse(x, 210, 180) -- north row, facing south
	end

	town.Parent = parentFolder
	return town
end

return TownBuilder
