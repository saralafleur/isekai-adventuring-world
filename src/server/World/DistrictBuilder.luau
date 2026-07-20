--!strict
-- The town's outer districts, each down its own road from the market plaza:
--   EAST  — Shopping Street: six shops with signs, browsable stocked
--           interiors (BrowseSpot + wares), keepers behind counters, homes
--           upstairs.
--   WEST  — Industrial district: warehouse, tannery, lumber yard, and
--           mason's workshop, dressed with log piles, stone stacks, and vats.

local PartUtil = require(script.Parent.PartUtil)
local HouseBuilder = require(script.Parent.HouseBuilder)
local AvatarFactory = require(script.Parent.Parent.NPC.AvatarFactory)

local part = PartUtil.part

local BEAM_COLOR = Color3.fromRGB(74, 52, 34)

local DistrictBuilder = {}

type ShopSpec = {
	name: string,
	label: string,
	x: number,
	z: number,
	rotation: number,
	wares: string,
	signColor: Color3,
	plaster: Color3,
	keeper: string,
	keeperShirt: number,
	keeperPants: number,
	keeperSkin: Color3,
	keeperBody: "masc" | "fem",
	keeperShape: "heavy" | "average" | "thin",
	keeperHair: number,
}

local SHOPS: { ShopSpec } = {
	{
		name = "GeneralGoods",
		label = "Berta's Sundries",
		x = 84,
		z = 26,
		rotation = 0,
		wares = "parcel",
		signColor = Color3.fromRGB(190, 120, 60),
		plaster = Color3.fromRGB(228, 216, 192),
		keeper = "Shopkeep Berta",
		keeperShirt = 18715074963,
		keeperPants = 18715064441,
		keeperSkin = Color3.fromRGB(214, 173, 130),
		keeperBody = "fem",
		keeperShape = "heavy",
		keeperHair = 62724852,
	},
	{
		name = "Apothecary",
		label = "The Green Flask",
		x = 128,
		z = 26,
		rotation = 0,
		wares = "potion",
		signColor = Color3.fromRGB(90, 160, 100),
		plaster = Color3.fromRGB(214, 222, 204),
		keeper = "Herbalist Fen",
		keeperShirt = 5295687641,
		keeperPants = 6458492706,
		keeperSkin = Color3.fromRGB(150, 108, 70),
		keeperBody = "masc",
		keeperShape = "thin",
		keeperHair = 14651241814,
	},
	{
		name = "Tailor",
		label = "Imre's Fine Threads",
		x = 168,
		z = 26,
		rotation = 0,
		wares = "cloth",
		signColor = Color3.fromRGB(150, 90, 160),
		plaster = Color3.fromRGB(226, 210, 220),
		keeper = "Tailor Imre",
		keeperShirt = 10565347864,
		keeperPants = 180864440,
		keeperSkin = Color3.fromRGB(255, 219, 172),
		keeperBody = "masc",
		keeperShape = "average",
		keeperHair = 10944323614,
	},
	{
		name = "Bookbinder",
		label = "The Inkwell",
		x = 96,
		z = 74,
		rotation = 180,
		wares = "book",
		signColor = Color3.fromRGB(90, 80, 140),
		plaster = Color3.fromRGB(216, 214, 226),
		keeper = "Binder Ottoline",
		keeperShirt = 9909459331,
		keeperPants = 9313405331,
		keeperSkin = Color3.fromRGB(255, 219, 172),
		keeperBody = "fem",
		keeperShape = "thin",
		keeperHair = 110290888975881,
	},
	{
		name = "Cobbler",
		label = "Wex & Sons, Cobblers",
		x = 140,
		z = 74,
		rotation = 180,
		wares = "parcel",
		signColor = Color3.fromRGB(120, 90, 60),
		plaster = Color3.fromRGB(222, 212, 196),
		keeper = "Cobbler Wex",
		keeperShirt = 6873403919,
		keeperPants = 6873405718,
		keeperSkin = Color3.fromRGB(214, 173, 130),
		keeperBody = "masc",
		keeperShape = "heavy",
		keeperHair = 109787953635038,
	},
	{
		name = "Trinkets",
		label = "The Magpie's Hoard",
		x = 180,
		z = 74,
		rotation = 180,
		wares = "parcel",
		signColor = Color3.fromRGB(200, 170, 80),
		plaster = Color3.fromRGB(230, 222, 200),
		keeper = "Peddler Sol",
		keeperShirt = 991220279,
		keeperPants = 4600522644,
		keeperSkin = Color3.fromRGB(150, 108, 70),
		keeperBody = "masc",
		keeperShape = "thin",
		keeperHair = 122943278283338,
	},
}

local function shopSign(parent: Instance, x: number, z: number, rotation: number, color: Color3)
	-- hanging sign over the door, on the road-facing side
	local frontDir = if rotation == 0 then 1 else -1
	local signZ = z + frontDir * 11.2
	part({ Name = "ShopSignBracket", Size = Vector3.new(0.3, 0.3, 2.4), Position = Vector3.new(x - 3, 13, signZ - frontDir * 0.8), Color = Color3.fromRGB(60, 58, 55), Material = Enum.Material.Metal }).Parent = parent
	part({ Name = "ShopSign", Size = Vector3.new(3.8, 2.2, 0.4), Position = Vector3.new(x - 3, 11.6, signZ), Color = color, Material = Enum.Material.Wood }).Parent = parent
end

local function buildShoppingStreet(district: Folder)
	for index, spec in SHOPS do
		HouseBuilder.build(district, {
			name = `Shop_{spec.name}`,
			position = Vector3.new(spec.x, 0, spec.z),
			rotation = spec.rotation,
			width = 26,
			depth = 20,
			stories = 2,
			plasterColor = spec.plaster,
			roofColor = Color3.fromRGB(95, 70, 56),
			interior = "shop",
			shopWares = spec.wares,
			seed = 40 + index,
			signText = spec.label,
			signMajor = true,
		})
		shopSign(district, spec.x, spec.z, spec.rotation, spec.signColor)

		-- Keeper behind the counter (counter sits toward the back of the shop)
		local backDir = if spec.rotation == 0 then -1 else 1
		local keeperPos = Vector3.new(spec.x, 0.5, spec.z + backDir * 8)
		local keeperFacing = Vector3.new(0, 0, -backDir)
		task.spawn(function()
			local keeper = AvatarFactory.createStatic({
				name = spec.keeper,
				shirtId = spec.keeperShirt,
				pantsId = spec.keeperPants,
				skin = spec.keeperSkin,
				position = keeperPos,
				facing = keeperFacing,
				body = spec.keeperBody,
				shape = spec.keeperShape,
				hairId = spec.keeperHair,
				gestures = true,
			})
			if keeper then
				keeper.Name = spec.keeper
			end
		end)
	end

	-- street lamps along the shopping road
	for _, x in { 84, 128, 168 } do
		for _, z in { 42, 58 } do
			part({ Name = "StreetLampPost", Size = Vector3.new(0.5, 7, 0.5), Position = Vector3.new(x + 20, 3.5, z), Color = BEAM_COLOR, Material = Enum.Material.Wood }).Parent = district
			local lamp = part({
				Name = "StreetLamp",
				Size = Vector3.new(0.9, 1.1, 0.9),
				Position = Vector3.new(x + 20, 7.4, z),
				Color = Color3.fromRGB(255, 214, 130),
				Material = Enum.Material.Neon,
				CanCollide = false,
			})
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 200, 110)
			light.Brightness = 1
			light.Range = 16
			light.Parent = lamp
			lamp.Parent = district
		end
	end
end

local function logPile(parent: Instance, x: number, z: number, count: number)
	for i = 0, count - 1 do
		local layer = math.floor(i / 3)
		local slot = i % 3
		part({
			Name = "IndustryLog",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(7, 1.4, 1.4),
			CFrame = CFrame.new(x, 0.75 + layer * 1.25, z + slot * 1.5 - layer * 0.75) * CFrame.Angles(0, 0, 0),
			Color = Color3.fromRGB(104, 74, 48),
			Material = Enum.Material.Wood,
		}).Parent = parent
	end
end

local function stonePile(parent: Instance, x: number, z: number)
	for i = 0, 4 do
		part({
			Name = "MasonBlock",
			Size = Vector3.new(2.2, 1.6, 1.8),
			CFrame = CFrame.new(x + (i % 2) * 2.5, 0.85 + math.floor(i / 2) * 1.65, z + (i % 3) * 0.7)
				* CFrame.Angles(0, math.rad(i * 8), 0),
			Color = Color3.fromRGB(150, 146, 140),
			Material = Enum.Material.Rock,
		}).Parent = parent
	end
end

local function buildIndustry(district: Folder)
	HouseBuilder.build(district, {
		name = "Warehouse",
		signText = "Glen Storehouse",
		signMajor = true,
		position = Vector3.new(-96, 0, 22),
		rotation = 0,
		width = 36,
		depth = 24,
		stories = 1,
		storyHeight = 14,
		doorWidth = 9,
		doorHeight = 11,
		plasterColor = Color3.fromRGB(200, 188, 165),
		roofColor = Color3.fromRGB(88, 78, 72),
		stoneGround = true,
		interior = "storage",
	})
	-- extra freight around the warehouse
	for i = 0, 3 do
		part({
			Name = "WarehouseCrate",
			Size = Vector3.new(2.2, 2.2, 2.2),
			Position = Vector3.new(-114 + (i % 2) * 2.6, 1.1 + math.floor(i / 2) * 2.25, 36 + (i % 2) * 1.4),
			Color = Color3.fromRGB(160, 126, 80),
			Material = Enum.Material.WoodPlanks,
		}).Parent = district
	end

	HouseBuilder.build(district, {
		name = "Tannery",
		signText = "Bramble Tannery",
		signMajor = true,
		position = Vector3.new(-146, 0, 24),
		rotation = 0,
		width = 28,
		depth = 20,
		stories = 1,
		storyHeight = 12,
		plasterColor = Color3.fromRGB(196, 176, 150),
		roofColor = Color3.fromRGB(95, 70, 56),
		interior = "storage",
	})
	-- tanning vats beside the tannery
	for i = 0, 2 do
		local vat = part({
			Name = "TanningVat",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(2, 3.4, 3.4),
			CFrame = CFrame.new(-160 + i * 4.4, 1, 40) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(110, 78, 48),
			Material = Enum.Material.WoodPlanks,
		})
		vat.Parent = district
		part({
			Name = "VatLiquid",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, 3, 3),
			CFrame = CFrame.new(-160 + i * 4.4, 2.1, 40) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(120, 90, 50),
			Material = Enum.Material.Glass,
			Transparency = 0.2,
			CanCollide = false,
		}).Parent = district
	end

	HouseBuilder.build(district, {
		name = "LumberYard",
		signText = "Greyfen Timber",
		signMajor = true,
		position = Vector3.new(-100, 0, 78),
		rotation = 180,
		width = 30,
		depth = 22,
		stories = 1,
		storyHeight = 12,
		doorWidth = 9,
		doorHeight = 10,
		plasterColor = Color3.fromRGB(206, 188, 158),
		roofColor = Color3.fromRGB(70, 62, 58),
		interior = "storage",
	})
	logPile(district, -120, 92, 6)
	logPile(district, -80, 94, 5)

	HouseBuilder.build(district, {
		name = "MasonWorkshop",
		signText = "Stonewright's Yard",
		signMajor = true,
		position = Vector3.new(-150, 0, 76),
		rotation = 180,
		width = 28,
		depth = 20,
		stories = 1,
		storyHeight = 12,
		stoneGround = true,
		plasterColor = Color3.fromRGB(210, 206, 198),
		roofColor = Color3.fromRGB(88, 78, 72),
		interior = "storage",
	})
	stonePile(district, -166, 90)
	stonePile(district, -134, 92)

	-- work spots so villagers wander through the industrial yard too
	PartUtil.marker("FieldSpot", Vector3.new(-116, 0.5, 90)).Parent = district
	PartUtil.marker("FieldSpot", Vector3.new(-162, 0.5, 88)).Parent = district
end

function DistrictBuilder.build(parentFolder: Instance)
	local district = Instance.new("Folder")
	district.Name = "Districts"
	buildShoppingStreet(district)
	buildIndustry(district)
	district.Parent = parentFolder
	return district
end

return DistrictBuilder
