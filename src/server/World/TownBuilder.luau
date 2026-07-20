--!strict
-- The town proper, north of the farm hamlet: market plaza with stalls and a
-- well, the town hall, streets, and blocks of 2-3 story townhouses.

local PartUtil = require(script.Parent.PartUtil)
local HouseBuilder = require(script.Parent.HouseBuilder)
local AvatarFactoryRef = require(script.Parent.Parent.NPC.AvatarFactory)

local part = PartUtil.part
local DARK_WOOD_TOWN = Color3.fromRGB(96, 62, 38)

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

local TownBuilder = {}

type StallTheme = {
	key: string,
	title: string,
	canopy: Color3,
	vendor: string,
	vendorShirt: number,
	vendorPants: number,
	vendorSkin: Color3,
	vendorBody: "masc" | "fem",
	vendorShape: "heavy" | "average" | "thin",
	vendorHair: number?,
	isQuestBaker: boolean?,
}

-- Themed goods displayed on/around the counter, built in stall-local space
-- (counter top at y 3.1, front toward +Z)
local function stallGoods(model: Model, key: string)
	local function p(props: { [string]: any })
		local goodsPart = part(props)
		goodsPart.CanCollide = false
		goodsPart.Parent = model
	end
	if key == "produce" then
		p({ Name = "GoodsCrate", Size = Vector3.new(2, 0.8, 1.4), Position = Vector3.new(-2, 3.55, 2), Color = Color3.fromRGB(150, 116, 70), Material = Enum.Material.WoodPlanks })
		for i = 0, 3 do
			p({ Name = "GoodsApple", Shape = Enum.PartType.Ball, Size = Vector3.new(0.55, 0.55, 0.55), Position = Vector3.new(-2.6 + (i % 2) * 1.1, 4.1, 1.7 + math.floor(i / 2) * 0.7), Color = Color3.fromRGB(200, 60, 55), Material = Enum.Material.SmoothPlastic })
		end
		p({ Name = "GoodsSquash", Size = Vector3.new(0.9, 0.7, 0.9), Position = Vector3.new(1.2, 3.5, 2.2), Color = Color3.fromRGB(230, 160, 60), Material = Enum.Material.SmoothPlastic })
		p({ Name = "GoodsGreens", Size = Vector3.new(1.4, 0.5, 0.9), Position = Vector3.new(2.6, 3.4, 1.8), Color = Color3.fromRGB(96, 150, 70), Material = Enum.Material.Grass })
		p({ Name = "GoodsSack", Size = Vector3.new(1.4, 1.8, 1.4), Position = Vector3.new(-2.6, 0.9, -0.8), Color = Color3.fromRGB(190, 170, 130), Material = Enum.Material.Fabric })
	elseif key == "bread" then
		for i = 0, 2 do
			p({ Name = "GoodsLoaf", Size = Vector3.new(1.5, 0.5, 0.6), Position = Vector3.new(-2.2 + i * 1.9, 3.4, 2), Color = Color3.fromRGB(196, 150, 90), Material = Enum.Material.Sand })
		end
		p({ Name = "GoodsBasket", Size = Vector3.new(1.6, 0.9, 1.6), Position = Vector3.new(2.6, 3.6, 1.6), Color = Color3.fromRGB(150, 116, 70), Material = Enum.Material.WoodPlanks })
		p({ Name = "GoodsRolls", Size = Vector3.new(1.2, 0.5, 1.2), Position = Vector3.new(2.6, 4.25, 1.6), Color = Color3.fromRGB(214, 172, 110), Material = Enum.Material.Sand })
		p({ Name = "GoodsFlourSack", Size = Vector3.new(1.5, 1.9, 1.5), Position = Vector3.new(2.4, 0.95, -0.8), Color = Color3.fromRGB(225, 218, 200), Material = Enum.Material.Fabric })
	elseif key == "fish" then
		for i = 0, 2 do
			p({ Name = "GoodsFish", Size = Vector3.new(0.4, 0.35, 1.8), Position = Vector3.new(-2 + i * 1.2, 3.3, 2), Color = Color3.fromRGB(140, 155, 165), Material = Enum.Material.SmoothPlastic })
		end
		p({ Name = "GoodsIce", Size = Vector3.new(5.5, 0.25, 2.2), Position = Vector3.new(-0.9, 3.15, 2), Color = Color3.fromRGB(200, 225, 235), Material = Enum.Material.Ice })
		local barrel = part({ Name = "GoodsBarrel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.2, 2, 2), CFrame = CFrame.new(2.7, 1.1, -0.6) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(110, 78, 48), Material = Enum.Material.WoodPlanks })
		barrel.Parent = model
		p({ Name = "GoodsNet", Size = Vector3.new(2.2, 0.15, 1.6), Position = Vector3.new(-2.6, 0.6, -0.8), Color = Color3.fromRGB(120, 110, 90), Material = Enum.Material.Fabric })
	elseif key == "cloth" then
		local rollColors = { Color3.fromRGB(160, 60, 70), Color3.fromRGB(70, 110, 160), Color3.fromRGB(190, 160, 80) }
		for i = 0, 2 do
			local roll = part({ Name = "GoodsClothRoll", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.6, 0.7, 0.7), CFrame = CFrame.new(-1.8 + i * 1.8, 3.5, 2) * CFrame.Angles(0, 0, math.rad(90)), Color = rollColors[i + 1], Material = Enum.Material.Fabric })
			roll.Parent = model
		end
		p({ Name = "GoodsFoldStack", Size = Vector3.new(1.6, 1, 1.3), Position = Vector3.new(2.8, 3.65, 1.8), Color = Color3.fromRGB(150, 120, 150), Material = Enum.Material.Fabric })
		p({ Name = "GoodsTrunk", Size = Vector3.new(2.2, 1.4, 1.4), Position = Vector3.new(-2.4, 0.75, -0.8), Color = DARK_WOOD_TOWN, Material = Enum.Material.WoodPlanks })
	elseif key == "pottery" then
		for i = 0, 2 do
			local pot = part({ Name = "GoodsPot", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.1, 0.9, 0.9), CFrame = CFrame.new(-2 + i * 1.6, 3.7, 2) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(168, 110, 72), Material = Enum.Material.SmoothPlastic })
			pot.Parent = model
		end
		p({ Name = "GoodsBowlStack", Size = Vector3.new(1.1, 0.8, 1.1), Position = Vector3.new(2.6, 3.55, 1.9), Color = Color3.fromRGB(190, 150, 110), Material = Enum.Material.SmoothPlastic })
		local bigUrn = part({ Name = "GoodsUrn", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 1.5, 1.5), CFrame = CFrame.new(-2.6, 1.2, -0.8) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(150, 96, 62), Material = Enum.Material.SmoothPlastic })
		bigUrn.Parent = model
	elseif key == "flowers" then
		local bloomColors = { Color3.fromRGB(230, 120, 150), Color3.fromRGB(240, 200, 80), Color3.fromRGB(150, 110, 220) }
		for i = 0, 2 do
			local bucket = part({ Name = "GoodsBucket", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.1, 0.9, 0.9), CFrame = CFrame.new(-1.8 + i * 1.8, 3.7, 2) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(120, 120, 125), Material = Enum.Material.Metal })
			bucket.Parent = model
			p({ Name = "GoodsBloomCluster", Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1), Position = Vector3.new(-1.8 + i * 1.8, 4.6, 2), Color = bloomColors[i + 1], Material = Enum.Material.Grass })
		end
		p({ Name = "GoodsPlanter", Size = Vector3.new(2.4, 0.8, 1.2), Position = Vector3.new(-2.4, 0.45, -0.8), Color = Color3.fromRGB(150, 116, 70), Material = Enum.Material.WoodPlanks })
		p({ Name = "GoodsPlanterBloom", Size = Vector3.new(2, 0.5, 0.9), Position = Vector3.new(-2.4, 1.1, -0.8), Color = Color3.fromRGB(230, 120, 150), Material = Enum.Material.Grass })
	end
end

local function marketStall(parent: Instance, x: number, z: number, facing: number, theme: StallTheme)
	local model = Instance.new("Model")
	model.Name = `Stall_{theme.key}`
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
		Size = Vector3.new(7.4, 1, 2.2),
		Position = Vector3.new(0, 2.6, 2),
		Color = Color3.fromRGB(133, 100, 67),
		Material = Enum.Material.WoodPlanks,
	}).Parent = model
	part({
		Name = "StallCounterBase",
		Size = Vector3.new(7, 2, 1.8),
		Position = Vector3.new(0, 1.1, 2),
		Color = Color3.fromRGB(110, 78, 48),
		Material = Enum.Material.Wood,
	}).Parent = model
	-- Striped canopy: theme color with a lighter mid-stripe
	part({
		Name = "StallCanopy",
		Size = Vector3.new(8.6, 0.3, 6),
		CFrame = CFrame.new(0, 7.4, 0.4) * CFrame.Angles(math.rad(-10), 0, 0),
		Color = theme.canopy,
		Material = Enum.Material.Fabric,
	}).Parent = model
	part({
		Name = "StallCanopyStripe",
		Size = Vector3.new(8.7, 0.12, 1.6),
		CFrame = CFrame.new(0, 7.52, 0.4) * CFrame.Angles(math.rad(-10), 0, 0),
		Color = theme.canopy:Lerp(Color3.new(1, 1, 1), 0.55),
		Material = Enum.Material.Fabric,
		CanCollide = false,
	}).Parent = model
	-- Side shelf for more goods
	part({
		Name = "StallShelf",
		Size = Vector3.new(1.4, 0.4, 3.6),
		Position = Vector3.new(-3.2, 3.9, 0),
		Color = Color3.fromRGB(133, 100, 67),
		Material = Enum.Material.WoodPlanks,
	}).Parent = model

	stallGoods(model, theme.key)

	-- NPC destination in front of the counter, tagged with what's sold here
	local browseMarker = PartUtil.marker("BrowseSpot", Vector3.new(0, 0.5, 5))
	browseMarker:SetAttribute("Wares", theme.key)
	browseMarker.Parent = model

	model.Parent = parent
	local stallCF = CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(facing), 0)
	model:PivotTo(stallCF)

	-- Vendor behind the counter, facing customers
	local vendorPos = (stallCF * CFrame.new(0, 0, -0.6)).Position
	-- Stall fronts are local +Z (toward the plaza/well); LookVector is -Z,
	-- so vendors face the negation — inward, at their customers
	local vendorFacing = -stallCF.LookVector
	task.spawn(function()
		local vendor = AvatarFactoryRef.createStatic({
			name = theme.vendor,
			shirtId = theme.vendorShirt,
			pantsId = theme.vendorPants,
			skin = theme.vendorSkin,
			position = Vector3.new(vendorPos.X, 0.5, vendorPos.Z),
			facing = vendorFacing,
			body = theme.vendorBody,
			shape = theme.vendorShape,
			hairId = theme.vendorHair,
			gestures = true,
		})
		if vendor and theme.isQuestBaker then
			-- Baker Hobb is the Harvest Morning delivery target: quest NPC
			-- tag + Talk prompt wire him into the dialogue system
			vendor:SetAttribute("NpcName", "Baker")
			local torso = vendor:FindFirstChild("UpperTorso") or vendor.PrimaryPart
			if torso then
				local prompt = Instance.new("ProximityPrompt")
				prompt.ActionText = "Talk"
				prompt.ObjectText = theme.vendor
				prompt.HoldDuration = 0
				prompt.MaxActivationDistance = 10
				prompt.Parent = torso
			end
			game:GetService("CollectionService"):AddTag(vendor, "NPC")
		end
	end)
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

	well(town, 0, 50)

	-- Market stalls ringing the plaza, each selling something distinct,
	-- each with its own vendor behind the counter
	marketStall(town, -22, 32, 90, {
		key = "produce",
		title = "Produce",
		canopy = Color3.fromRGB(70, 140, 80),
		vendor = "Farmer Joss",
		vendorHair = 62724852,
		vendorShirt = 3174708425,
		vendorPants = 5139586944,
		vendorSkin = Color3.fromRGB(214, 173, 130),
		vendorBody = "fem",
		vendorShape = "average",
	})
	marketStall(town, -22, 50, 90, {
		key = "cloth",
		title = "Cloth & Thread",
		canopy = Color3.fromRGB(150, 80, 160),
		vendor = "Weaver Sena",
		vendorHair = 17320190968,
		vendorShirt = 9909459331,
		vendorPants = 9313405331,
		vendorSkin = Color3.fromRGB(150, 108, 70),
		vendorBody = "fem",
		vendorShape = "thin",
	})
	marketStall(town, -22, 68, 90, {
		key = "flowers",
		title = "Flowers",
		canopy = Color3.fromRGB(200, 150, 60),
		vendor = "Florist Wren",
		vendorHair = 87786134298390,
		vendorShirt = 767069743,
		vendorPants = 17396743947,
		vendorSkin = Color3.fromRGB(255, 219, 172),
		vendorBody = "fem",
		vendorShape = "thin",
	})
	marketStall(town, 22, 32, -90, {
		key = "fish",
		title = "Fresh Catch",
		canopy = Color3.fromRGB(60, 110, 170),
		vendor = "Fisher Malin",
		vendorHair = 14651241814,
		vendorShirt = 5518042632,
		vendorPants = 6458492706,
		vendorSkin = Color3.fromRGB(214, 173, 130),
		vendorBody = "masc",
		vendorShape = "average",
	})
	marketStall(town, 22, 68, -90, {
		key = "pottery",
		title = "Pottery",
		canopy = Color3.fromRGB(60, 150, 150),
		vendor = "Potter Grum",
		vendorHair = 95892745934875,
		vendorShirt = 872921927,
		vendorPants = 13124170939,
		vendorSkin = Color3.fromRGB(150, 108, 70),
		vendorBody = "masc",
		vendorShape = "heavy",
	})
	marketStall(town, 20, 55, -90, {
		key = "bread",
		title = "Hobb's Bakery",
		canopy = Color3.fromRGB(190, 60, 60),
		vendor = "Baker Hobb",
		vendorHair = 122943278283338,
		vendorShirt = 5088653702,
		vendorPants = 10482967100,
		vendorSkin = Color3.fromRGB(255, 219, 172),
		vendorBody = "masc",
		vendorShape = "heavy",
		isQuestBaker = true,
	})

	-- Plaza ambience: corner lamp posts and freight
	for _, corner in { Vector3.new(-27, 0, 23), Vector3.new(27, 0, 23), Vector3.new(-27, 0, 77), Vector3.new(27, 0, 77) } do
		part({ Name = "PlazaLampPost", Size = Vector3.new(0.5, 6.5, 0.5), Position = corner + Vector3.new(0, 3.25, 0), Color = BEAM_COLOR, Material = Enum.Material.Wood }).Parent = town
		local plazaLamp = part({
			Name = "PlazaLamp",
			Size = Vector3.new(0.9, 1.1, 0.9),
			Position = corner + Vector3.new(0, 7, 0),
			Color = Color3.fromRGB(255, 214, 130),
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		local plazaLight = Instance.new("PointLight")
		plazaLight.Color = Color3.fromRGB(255, 200, 110)
		plazaLight.Brightness = 1
		plazaLight.Range = 16
		plazaLight.Parent = plazaLamp
		plazaLamp.Parent = town
	end
	for i = 0, 2 do
		part({ Name = "PlazaCrate", Size = Vector3.new(1.7, 1.7, 1.7), Position = Vector3.new(-26 + (i % 2) * 2, 0.85 + math.floor(i / 2) * 1.75, 40 + (i % 2) * 1.2), Color = Color3.fromRGB(160, 126, 80), Material = Enum.Material.WoodPlanks }).Parent = town
	end

	-- Town hall: 3 stories, stone ground floor, facing south over the plaza.
	-- Interior is custom-built below (assembly hall + records balcony).
	local hall = HouseBuilder.build(town, {
		name = "TownHall",
		position = Vector3.new(0, 0, 120),
		rotation = 180,
		width = 38,
		depth = 26,
		stories = 3,
		storyHeight = 12,
		stoneGround = true,
		plasterColor = Color3.fromRGB(236, 228, 214),
		roofColor = Color3.fromRGB(88, 78, 72),
		doorWidth = 6,
		doorHeight = 10,
		interior = "none",
		signText = "Briar Glen Town Hall",
		signMajor = true,
	})
	-- Clock face + bell cupola to mark it as civic
	part({
		Name = "ClockFace",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 6, 6),
		CFrame = CFrame.new(0, 30, 106.2) * CFrame.Angles(0, math.rad(90), 0),
		Color = Color3.fromRGB(240, 234, 216),
		Material = Enum.Material.SmoothPlastic,
	}).Parent = hall
	part({
		Name = "ClockHand",
		Size = Vector3.new(0.3, 2.2, 0.2),
		CFrame = CFrame.new(0, 30.8, 105.9) * CFrame.Angles(0, 0, math.rad(25)),
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
				Position = Vector3.new(px, 48.4, 120 + pz),
				Color = BEAM_COLOR,
				Material = Enum.Material.Wood,
			}).Parent = hall
		end
	end
	part({
		Name = "CupolaRoof",
		Size = Vector3.new(6.5, 0.5, 6.5),
		Position = Vector3.new(0, 51, 120),
		Color = Color3.fromRGB(88, 78, 72),
		Material = Enum.Material.RoofShingles,
	}).Parent = hall
	part({
		Name = "Bell",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.8, 1.8, 1.8),
		Position = Vector3.new(0, 49.5, 120),
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
	-- Stepped stairs along the east wall up to the records balcony
	PartUtil.steppedStairs(hall, Vector3.new(16.8, 1.05, 110.0), Vector3.zAxis, 12.95, 14.2, 4.2, {
		stepColor = Color3.fromRGB(133, 100, 67),
		stepMaterial = Enum.Material.WoodPlanks,
		railColor = Color3.fromRGB(96, 62, 38),
		railSides = { -Vector3.xAxis }, -- open west side
	})
	-- Balcony plate over the dais end
	part({ Name = "BalconyPlate", Size = Vector3.new(37.2, 0.5, 8.6), Position = Vector3.new(0, 13.75, 128.4), Color = Color3.fromRGB(133, 100, 67), Material = Enum.Material.WoodPlanks }).Parent = hall
	-- Railing along the balcony edge, leaving the stair arrival gap on the east
	part({ Name = "BalconyRail", Size = Vector3.new(33, 0.3, 0.3), Position = Vector3.new(-1.6, 16.7, 124.4), Color = Color3.fromRGB(96, 62, 38), Material = Enum.Material.Wood }).Parent = hall
	for _, x in { -17.9, -12, -6, 0, 6, 12, 14.6 } do
		part({ Name = "BalconyPost", Size = Vector3.new(0.3, 2.8, 0.3), Position = Vector3.new(x, 15.4, 124.4), Color = BEAM_COLOR, Material = Enum.Material.Wood }).Parent = hall
	end
	-- Records desk and shelf on the balcony
	part({ Name = "RecordsDesk", Size = Vector3.new(3.6, 2.4, 2), Position = Vector3.new(-8, 15.2, 130.4), Color = BENCH_WOOD, Material = Enum.Material.WoodPlanks }).Parent = hall
	part({ Name = "RecordsShelf", Size = Vector3.new(6, 4.5, 1), Position = Vector3.new(6, 16.25, 131.7), Color = Color3.fromRGB(96, 62, 38), Material = Enum.Material.WoodPlanks }).Parent = hall
	-- Chandeliers hanging from collar beams high in the open hall
	for _, z in { 112, 120 } do
		part({ Name = "HallCollarBeam", Size = Vector3.new(36, 0.5, 0.7), Position = Vector3.new(0, 36.85, z), Color = BEAM_COLOR, Material = Enum.Material.Wood, CanCollide = false }).Parent = hall
		part({ Name = "ChandelierChain", Size = Vector3.new(0.18, 9.6, 0.18), Position = Vector3.new(0, 32.2, z), Color = Color3.fromRGB(80, 80, 80), Material = Enum.Material.Metal, CanCollide = false }).Parent = hall
		local chandelier = part({
			Name = "Chandelier",
			Size = Vector3.new(1.4, 1.2, 1.4),
			Position = Vector3.new(0, 27.6, z),
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
	part({ Name = "DaisLampChain", Size = Vector3.new(0.18, 1.6, 0.18), Position = Vector3.new(0, 12.9, 129), Color = Color3.fromRGB(80, 80, 80), Material = Enum.Material.Metal, CanCollide = false }).Parent = hall
	local daisLamp = part({
		Name = "DaisLamp",
		Size = Vector3.new(0.9, 1.1, 0.9),
		Position = Vector3.new(0, 11.75, 129),
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
			width = 30 + (index * 5 % 3) * 3,
			depth = 24 + (index * 7 % 2) * 3,
			stories = if index % 3 == 0 then 3 else 2,
			stoneGround = index % 4 == 0,
			plasterColor = PLASTER_TINTS[(index - 1) % #PLASTER_TINTS + 1],
			roofColor = ROOF_TINTS[(index - 1) % #ROOF_TINTS + 1],
			seed = index,
			signText = `House {index}`,
		})
	end

	-- Organic placement, spread wide: no building stands closer than ~12 studs
	-- of clear ground to its neighbor. Residential is the NORTH district
	-- (curving lanes + crescent); shopping runs EAST, industry WEST (see
	-- DistrictBuilder); the farm hamlet stays SOUTH.
	local PLOTS = {
		-- northwest lane, outer side
		{ -54, 112, 65 },
		{ -86, 155, 55 },
		{ -104, 203, 45 },
		-- northeast lane, outer side
		{ 54, 112, -65 },
		{ 86, 155, -55 },
		{ 104, 203, -45 },
		-- flanking the north road
		{ -30, 168, 85 },
		{ 30, 180, -85 },
		-- north crescent
		{ -56, 216, 160 },
		{ 56, 216, 200 },
	}
	for _, plot in PLOTS do
		townhouse(plot[1], plot[2], plot[3])
	end

	-- Curved dirt lanes (segment heights alternate so overlapping joints never
	-- share a top plane)
	local function curvedLane(points: { Vector3 }, width: number)
		for i = 1, #points - 1 do
			local a, b = points[i], points[i + 1]
			local delta = b - a
			local length = delta.Magnitude
			local laneAngle = math.atan2(delta.Z, delta.X)
			local thickness = 0.16 + (i % 2) * 0.05
			part({
				Name = "Lane",
				Size = Vector3.new(length + 3, thickness, width),
				CFrame = CFrame.new((a + b) / 2 + Vector3.new(0, thickness / 2, 0)) * CFrame.Angles(0, -laneAngle, 0),
				Color = Color3.fromRGB(150, 125, 95),
				Material = Enum.Material.Ground,
			}).Parent = town
		end
	end
	-- northwest residential lane
	curvedLane({
		Vector3.new(-26, 0, 80),
		Vector3.new(-40, 0, 98),
		Vector3.new(-56, 0, 120),
		Vector3.new(-72, 0, 150),
		Vector3.new(-84, 0, 182),
		Vector3.new(-90, 0, 208),
	}, 8)
	-- northeast residential lane
	curvedLane({
		Vector3.new(26, 0, 80),
		Vector3.new(40, 0, 98),
		Vector3.new(56, 0, 120),
		Vector3.new(72, 0, 150),
		Vector3.new(84, 0, 182),
		Vector3.new(90, 0, 208),
	}, 8)
	-- crescent lane behind the hall
	curvedLane({
		Vector3.new(-70, 0, 200),
		Vector3.new(-40, 0, 214),
		Vector3.new(-14, 0, 220),
		Vector3.new(14, 0, 220),
		Vector3.new(40, 0, 214),
		Vector3.new(70, 0, 200),
	}, 6)
	-- shopping street (east) and industrial road (west): the roads start past
	-- the guild halls' rears; curved connectors skirt the guilds' south sides
	part({ Name = "ShoppingRoad", Size = Vector3.new(112, 0.2, 12), Position = Vector3.new(124, 0.1, 50), Color = Color3.fromRGB(168, 158, 140), Material = Enum.Material.Cobblestone }).Parent = town
	part({ Name = "IndustryRoad", Size = Vector3.new(112, 0.2, 12), Position = Vector3.new(-124, 0.1, 50), Color = Color3.fromRGB(160, 150, 135), Material = Enum.Material.Cobblestone }).Parent = town
	curvedLane({
		Vector3.new(28, 0, 32),
		Vector3.new(48, 0, 26),
		Vector3.new(64, 0, 32),
		Vector3.new(72, 0, 44),
	}, 7)
	curvedLane({
		Vector3.new(-28, 0, 32),
		Vector3.new(-48, 0, 26),
		Vector3.new(-64, 0, 32),
		Vector3.new(-72, 0, 44),
	}, 7)

	town.Parent = parentFolder
	return town
end

return TownBuilder
