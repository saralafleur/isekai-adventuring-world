--!strict
-- The two guild halls flanking the market plaza — large, two-story, fully
-- walkable interiors.
--   Adventurers' Guild (west): ground floor is a tavern hall (bar, kegs,
--     tables, fireplace, notice board) with the guild service counter at the
--     back; upstairs is adventurer lodging.
--   Merchants' Guild (east): ground floor trading hall (map table, ledger
--     desks, crates, scroll wall, service counter); upstairs offices.

local PartUtil = require(script.Parent.PartUtil)
local HouseBuilder = require(script.Parent.HouseBuilder)
local AvatarFactory = require(script.Parent.Parent.NPC.AvatarFactory)

local part = PartUtil.part
local wedge = PartUtil.wedge

local BEAM_COLOR = Color3.fromRGB(74, 52, 34)
local DARK_WOOD = Color3.fromRGB(96, 62, 38)
local FLOOR_WOOD = Color3.fromRGB(133, 100, 67)
local STONE_COLOR = Color3.fromRGB(130, 126, 120)
local PARCHMENT = Color3.fromRGB(228, 214, 180)

local GuildBuilder = {}

local function hangingLantern(parent: Instance, x: number, z: number, ceilingY: number, brightness: number, range: number)
	local lanternY = ceilingY - 2.2
	part({
		Name = "LanternChain",
		Size = Vector3.new(0.18, ceilingY - lanternY + 0.4, 0.18),
		Position = Vector3.new(x, (ceilingY + lanternY) / 2 + 0.2, z),
		Color = Color3.fromRGB(80, 80, 80),
		Material = Enum.Material.Metal,
		CanCollide = false,
	}).Parent = parent
	local lamp = part({
		Name = "HangingLantern",
		Size = Vector3.new(0.9, 1.2, 0.9),
		Position = Vector3.new(x, lanternY, z),
		Color = Color3.fromRGB(255, 214, 130),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 205, 120)
	light.Brightness = brightness
	light.Range = range
	light.Parent = lamp
	lamp.Parent = parent
end

local function rectTable(parent: Instance, x: number, z: number, withBenches: boolean)
	part({ Name = "TableTop", Size = Vector3.new(5, 0.45, 3), Position = Vector3.new(x, 3.3, z), Color = Color3.fromRGB(110, 78, 48), Material = Enum.Material.WoodPlanks }).Parent = parent
	for _, offset in { Vector3.new(-2, 0, -1.2), Vector3.new(2, 0, -1.2), Vector3.new(-2, 0, 1.2), Vector3.new(2, 0, 1.2) } do
		part({
			Name = "TableLeg",
			Size = Vector3.new(0.35, 2.1, 0.35),
			Position = Vector3.new(x, 2, z) + offset,
			Color = BEAM_COLOR,
			Material = Enum.Material.Wood,
		}).Parent = parent
	end
	-- candle
	part({ Name = "TableCandle", Size = Vector3.new(0.25, 0.6, 0.25), Position = Vector3.new(x + 0.7, 3.83, z - 0.5), Color = Color3.fromRGB(230, 220, 200), Material = Enum.Material.SmoothPlastic, CanCollide = false }).Parent = parent
	local flame = part({
		Name = "CandleFlame",
		Size = Vector3.new(0.16, 0.26, 0.16),
		Position = Vector3.new(x + 0.7, 4.26, z - 0.5),
		Color = Color3.fromRGB(255, 200, 90),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 200, 110)
	light.Brightness = 0.5
	light.Range = 7
	light.Parent = flame
	flame.Parent = parent
	if withBenches then
		for _, dz in { -2.3, 2.3 } do
			part({ Name = "Bench", Size = Vector3.new(4.6, 1.5, 1.1), Position = Vector3.new(x, 1.85, z + dz), Color = Color3.fromRGB(110, 78, 48), Material = Enum.Material.WoodPlanks }).Parent = parent
		end
	else
		for _, dz in { -2.2, 2.2 } do
			part({ Name = "Stool", Size = Vector3.new(1.3, 1.5, 1.3), Position = Vector3.new(x, 1.85, z + dz), Color = Color3.fromRGB(110, 78, 48), Material = Enum.Material.Wood }).Parent = parent
		end
	end
end

-- Straight stair run rising WESTWARD (toward -X) along a south wall.
local function stairsWestward(parent: Instance, xBottom: number, z: number, storyH: number)
	local runLength = storyH * 1.3
	local xTop = xBottom - runLength
	wedge({
		Name = "StairRamp",
		Size = Vector3.new(3.2, storyH, runLength),
		-- wedge rises toward local -Z; rotate +90 about Y so it rises toward -X
		CFrame = CFrame.new((xBottom + xTop) / 2, 1 + storyH / 2, z) * CFrame.Angles(0, math.rad(90), 0),
		Color = FLOOR_WOOD,
		Material = Enum.Material.WoodPlanks,
	}).Parent = parent
	-- Rail on the open (north) side
	local railZ = z + 1.7
	for i = 0, 2 do
		local t = i / 2
		part({
			Name = "StairPost",
			Size = Vector3.new(0.35, 3.2, 0.35),
			Position = Vector3.new(xBottom - runLength * t, 1 + storyH * t + 1.6, railZ),
			Color = BEAM_COLOR,
			Material = Enum.Material.Wood,
		}).Parent = parent
	end
	local railLength = math.sqrt(runLength * runLength + storyH * storyH)
	local angle = math.atan(storyH / runLength)
	part({
		Name = "StairRail",
		Size = Vector3.new(railLength, 0.3, 0.3),
		CFrame = CFrame.new((xBottom + xTop) / 2, 1 + storyH / 2 + 2.9, railZ) * CFrame.Angles(0, 0, angle),
		Color = DARK_WOOD,
		Material = Enum.Material.Wood,
	}).Parent = parent
end

local function serviceCounter(parent: Instance, x: number, z0: number, z1: number)
	part({
		Name = "ServiceCounterBase",
		Size = Vector3.new(1.8, 2.2, z1 - z0),
		Position = Vector3.new(x, 2.1, (z0 + z1) / 2),
		Color = DARK_WOOD,
		Material = Enum.Material.Wood,
	}).Parent = parent
	part({
		Name = "ServiceCounterTop",
		Size = Vector3.new(2.2, 0.5, z1 - z0 + 0.4),
		Position = Vector3.new(x, 3.45, (z0 + z1) / 2),
		Color = Color3.fromRGB(110, 78, 48),
		Material = Enum.Material.WoodPlanks,
	}).Parent = parent
end

local function guardRailX(parent: Instance, x: number, z0: number, z1: number, floorTopY: number)
	part({
		Name = "GuardRail",
		Size = Vector3.new(0.3, 0.3, z1 - z0),
		Position = Vector3.new(x, floorTopY + 2.7, (z0 + z1) / 2),
		Color = DARK_WOOD,
		Material = Enum.Material.Wood,
	}).Parent = parent
	for _, z in { z0 + 0.3, (z0 + z1) / 2, z1 - 0.3 } do
		part({
			Name = "GuardPost",
			Size = Vector3.new(0.3, 2.8, 0.3),
			Position = Vector3.new(x, floorTopY + 1.4, z),
			Color = BEAM_COLOR,
			Material = Enum.Material.Wood,
		}).Parent = parent
	end
end

local function guardRailZ(parent: Instance, z: number, x0: number, x1: number, floorTopY: number)
	part({
		Name = "GuardRail",
		Size = Vector3.new(x1 - x0, 0.3, 0.3),
		Position = Vector3.new((x0 + x1) / 2, floorTopY + 2.7, z),
		Color = DARK_WOOD,
		Material = Enum.Material.Wood,
	}).Parent = parent
	for _, x in { x0 + 0.3, (x0 + x1) / 2, x1 - 0.3 } do
		part({
			Name = "GuardPost",
			Size = Vector3.new(0.3, 2.8, 0.3),
			Position = Vector3.new(x, floorTopY + 1.4, z),
			Color = BEAM_COLOR,
			Material = Enum.Material.Wood,
		}).Parent = parent
	end
end

local function bed(parent: Instance, x: number, z: number, blanket: Color3, floorY: number, rotated: boolean)
	local frameSize = if rotated then Vector3.new(7, 0.9, 4.2) else Vector3.new(4.2, 0.9, 7)
	local mattressSize = if rotated then Vector3.new(6.6, 1.1, 3.8) else Vector3.new(3.8, 1.1, 6.6)
	part({ Name = "BedFrame", Size = frameSize, Position = Vector3.new(x, floorY + 0.45, z), Color = BEAM_COLOR, Material = Enum.Material.Wood }).Parent = parent
	part({ Name = "BedMattress", Size = mattressSize, Position = Vector3.new(x, floorY + 1.15, z), Color = Color3.fromRGB(225, 218, 200), Material = Enum.Material.Fabric }).Parent = parent
	local pillowOffset = if rotated then Vector3.new(-2.3, 0, 0) else Vector3.new(0, 0, -2.3)
	part({ Name = "BedPillow", Size = if rotated then Vector3.new(1.5, 0.5, 2.6) else Vector3.new(2.6, 0.5, 1.5), Position = Vector3.new(x, floorY + 1.9, z) + pillowOffset, Color = Color3.fromRGB(240, 235, 220), Material = Enum.Material.Fabric }).Parent = parent
	local blanketOffset = if rotated then Vector3.new(1.2, 0, 0) else Vector3.new(0, 0, 1.2)
	part({ Name = "BedBlanket", Size = if rotated then Vector3.new(3.8, 0.22, 3.9) else Vector3.new(3.9, 0.22, 3.8), Position = Vector3.new(x, floorY + 1.78, z) + blanketOffset, Color = blanket, Material = Enum.Material.Fabric, CanCollide = false }).Parent = parent
end

-- ============================================================ Adventurers'

local function buildAdventurersGuild(guilds: Folder)
	HouseBuilder.build(guilds, {
		name = "AdventurersGuild",
		position = Vector3.new(-52, 0, 55),
		rotation = 90,
		width = 36,
		depth = 26,
		stories = 2,
		storyHeight = 8,
		stoneGround = true,
		plasterColor = Color3.fromRGB(214, 200, 175),
		roofColor = Color3.fromRGB(70, 62, 58),
		doorWidth = 6,
		doorHeight = 7,
		interior = "none",
	})
	-- Footprint: x -65..-39, z 37..73. Door faces east (+X) at (-39, 55).
	-- Interior region: x -64.5..-39.5, z 37.5..72.5. Ground ceiling plate at y 9.

	-- Signage + banners outside
	part({ Name = "SignBracket", Size = Vector3.new(0.3, 0.3, 2.6), Position = Vector3.new(-38.2, 11.4, 54.4), Color = Color3.fromRGB(60, 58, 55), Material = Enum.Material.Metal }).Parent = guilds
	part({ Name = "SignBoard", Size = Vector3.new(0.4, 2.6, 4.4), Position = Vector3.new(-38.2, 10, 55), Color = Color3.fromRGB(90, 60, 40), Material = Enum.Material.Wood }).Parent = guilds
	for _, bladeAngle in { 40, -40 } do
		part({
			Name = "SignSword",
			Size = Vector3.new(0.35, 3, 0.2),
			CFrame = CFrame.new(-37.9, 10, 55) * CFrame.Angles(0, math.rad(90), math.rad(bladeAngle)),
			Color = Color3.fromRGB(200, 200, 210),
			Material = Enum.Material.Metal,
			CanCollide = false,
		}).Parent = guilds
	end
	for _, z in { 46, 64 } do
		part({ Name = "BannerRod", Size = Vector3.new(2.8, 0.25, 0.25), Position = Vector3.new(-39.2, 15.1, z), Color = BEAM_COLOR, Material = Enum.Material.Wood, CanCollide = false }).Parent = guilds
		part({ Name = "Banner", Size = Vector3.new(0.2, 6, 2.2), Position = Vector3.new(-38.6, 12, z), Color = Color3.fromRGB(160, 40, 40), Material = Enum.Material.Fabric, CanCollide = false }).Parent = guilds
	end

	-- ---------------- ground floor: tavern hall
	-- Bar along the north side
	part({ Name = "BarBase", Size = Vector3.new(11, 2.2, 1.8), Position = Vector3.new(-56, 2.1, 66.5), Color = DARK_WOOD, Material = Enum.Material.Wood }).Parent = guilds
	part({ Name = "BarTop", Size = Vector3.new(11.4, 0.5, 2.2), Position = Vector3.new(-56, 3.45, 66.5), Color = Color3.fromRGB(110, 78, 48), Material = Enum.Material.WoodPlanks }).Parent = guilds
	-- Back-bar shelves embedded in the north wall, with bottles standing on them
	for _, shelfY in { 4.6, 6.4 } do
		part({ Name = "BackBarShelf", Size = Vector3.new(10, 0.35, 1), Position = Vector3.new(-56, shelfY, 72.1), Color = BEAM_COLOR, Material = Enum.Material.Wood }).Parent = guilds
		for i = 0, 5 do
			part({
				Name = "Bottle",
				Size = Vector3.new(0.4, 1.1, 0.4),
				Position = Vector3.new(-60.4 + i * 1.7, shelfY + 0.73, 72.1),
				Color = if i % 2 == 0 then Color3.fromRGB(90, 130, 90) else Color3.fromRGB(140, 100, 70),
				Material = Enum.Material.Glass,
				Transparency = 0.2,
				CanCollide = false,
			}).Parent = guilds
		end
	end
	-- Kegs stacked in the northwest corner
	for i = 0, 2 do
		part({
			Name = "Keg",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(2.6, 2.2, 2.2),
			CFrame = CFrame.new(-62.8, 1.6 + (if i == 2 then 2.2 else 0), 69.8 - (i % 2) * 2.4) * CFrame.Angles(0, math.rad(90), 0),
			Color = Color3.fromRGB(110, 78, 48),
			Material = Enum.Material.WoodPlanks,
		}).Parent = guilds
	end
	-- Barstools in front of the bar
	for i = 0, 3 do
		part({ Name = "BarStool", Size = Vector3.new(1.2, 2.2, 1.2), Position = Vector3.new(-60 + i * 2.6, 2.2, 64.2), Color = Color3.fromRGB(110, 78, 48), Material = Enum.Material.Wood }).Parent = guilds
	end

	-- Tavern tables (benches for the big ones, stools for the small)
	rectTable(guilds, -50, 60, true)
	rectTable(guilds, -58, 61, false)
	rectTable(guilds, -47, 45, true)
	rectTable(guilds, -57, 48, false)

	-- Fireplace on the south wall (west of the stairs)
	part({ Name = "HearthSideL", Size = Vector3.new(0.8, 4, 1.8), Position = Vector3.new(-62.1, 3, 38.6), Color = STONE_COLOR, Material = Enum.Material.Cobblestone }).Parent = guilds
	part({ Name = "HearthSideR", Size = Vector3.new(0.8, 4, 1.8), Position = Vector3.new(-57.9, 3, 38.6), Color = STONE_COLOR, Material = Enum.Material.Cobblestone }).Parent = guilds
	part({ Name = "HearthLintel", Size = Vector3.new(5, 0.9, 1.8), Position = Vector3.new(-60, 5.45, 38.6), Color = STONE_COLOR, Material = Enum.Material.Slate }).Parent = guilds
	part({ Name = "HearthBase", Size = Vector3.new(5, 0.4, 2.2), Position = Vector3.new(-60, 1.3, 38.8), Color = STONE_COLOR, Material = Enum.Material.Slate }).Parent = guilds
	local fireLogs = part({
		Name = "FireLogs",
		Size = Vector3.new(2.2, 0.7, 1.2),
		Position = Vector3.new(-60, 1.85, 38.7),
		Color = Color3.fromRGB(60, 42, 30),
		Material = Enum.Material.Wood,
	})
	local fire = Instance.new("Fire")
	fire.Size = 4
	fire.Heat = 6
	fire.Parent = fireLogs
	local fireLight = Instance.new("PointLight")
	fireLight.Color = Color3.fromRGB(255, 160, 70)
	fireLight.Brightness = 1.6
	fireLight.Range = 16
	fireLight.Parent = fireLogs
	fireLogs.Parent = guilds

	-- Guild service counter along the back (west) wall + notice board
	serviceCounter(guilds, -62.4, 47, 63)
	part({ Name = "CounterLedger", Size = Vector3.new(1.2, 0.18, 1.6), Position = Vector3.new(-62.4, 3.79, 52), Color = PARCHMENT, Material = Enum.Material.SmoothPlastic, CanCollide = false }).Parent = guilds
	part({ Name = "NoticeBoard", Size = Vector3.new(0.4, 3.4, 5), Position = Vector3.new(-64.3, 5, 44), Color = Color3.fromRGB(96, 70, 46), Material = Enum.Material.Wood }).Parent = guilds
	for i = 0, 3 do
		part({
			Name = "NoticePaper",
			Size = Vector3.new(0.1, 1.1, 0.9),
			Position = Vector3.new(-64.05, 5.6 - (i % 2) * 1.3, 42.6 + math.floor(i / 2) * 1.6),
			Color = PARCHMENT,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		}).Parent = guilds
	end

	hangingLantern(guilds, -52, 60, 9, 1.4, 20)
	hangingLantern(guilds, -58, 46, 9, 1.2, 18)

	-- Stairs up along the south wall (bottom at east, rising west)
	stairsWestward(guilds, -43, 40.4, 8)

	-- ---------------- upper floor: lodging
	-- Floor plate at y 9 with stairwell hole over the stair top
	part({ Name = "FloorPlate", Size = Vector3.new(24.6, 0.5, 29.6), Position = Vector3.new(-52, 8.75, 57.4), Color = FLOOR_WOOD, Material = Enum.Material.WoodPlanks }).Parent = guilds
	part({ Name = "FloorPlate", Size = Vector3.new(9.7, 0.5, 4), Position = Vector3.new(-59.65, 8.75, 40.6), Color = FLOOR_WOOD, Material = Enum.Material.WoodPlanks }).Parent = guilds
	guardRailZ(guilds, 42.8, -54.8, -42.9, 9)
	guardRailX(guilds, -54.8, 38.7, 42.6, 9)

	-- Beds for traveling adventurers
	local blankets = { Color3.fromRGB(150, 60, 60), Color3.fromRGB(80, 100, 140), Color3.fromRGB(96, 128, 88), Color3.fromRGB(150, 120, 80) }
	for i = 0, 3 do
		bed(guilds, -62.2, 68 - i * 7.4, blankets[i + 1], 9, true)
		part({ Name = "LodgingChest", Size = Vector3.new(1.6, 1.2, 1.2), Position = Vector3.new(-57.6, 9.6, 68 - i * 7.4), Color = DARK_WOOD, Material = Enum.Material.WoodPlanks }).Parent = guilds
	end
	part({ Name = "LodgingRug", Size = Vector3.new(4, 0.12, 20), Position = Vector3.new(-54, 9.06, 58), Color = Color3.fromRGB(110, 90, 60), Material = Enum.Material.Fabric, CanCollide = false }).Parent = guilds

	-- Collar rafters at the wall top anchor the upstairs lanterns
	for _, z in { 48, 62 } do
		part({ Name = "CollarRafter", Size = Vector3.new(24.5, 0.5, 0.7), Position = Vector3.new(-52, 17.15, z), Color = BEAM_COLOR, Material = Enum.Material.Wood, CanCollide = false }).Parent = guilds
	end
	hangingLantern(guilds, -52, 48, 17, 1, 16)
	hangingLantern(guilds, -52, 62, 17, 1, 16)

	-- Villager/traveler destinations inside
	PartUtil.marker("BrowseSpot", Vector3.new(-53, 1.6, 63)).Parent = guilds -- at the bar
	PartUtil.marker("BrowseSpot", Vector3.new(-62.5, 1.6, 44)).Parent = guilds -- notice board
	PartUtil.marker("GatherSpot", Vector3.new(-51, 1.6, 59)).Parent = guilds -- tavern floor

	-- Staff
	task.spawn(function()
		local thorne = AvatarFactory.createStatic({
			name = "Guildmaster Thorne",
			hairId = 10944323614,
			body = "masc",
			shape = "heavy",
			shirtId = 11401062683,
			pantsId = 11199196921,
			skin = Color3.fromRGB(214, 173, 130),
			position = Vector3.new(-63.6, 0.5, 55),
			facing = Vector3.xAxis,
			widthScale = 1.1,
		})
		if thorne then
			thorne:SetAttribute("ShopId", "AdventurersGuild")
			game:GetService("CollectionService"):AddTag(thorne, "Shopkeeper")
		end
	end)
	task.spawn(function()
		AvatarFactory.createStatic({
			name = "Barkeep Hulda",
			hairId = 110290888975881,
			body = "fem",
			shape = "average",
			shirtId = 18715074963,
			pantsId = 18715064441,
			skin = Color3.fromRGB(255, 219, 172),
			position = Vector3.new(-56, 0.5, 68.6),
			facing = -Vector3.zAxis,
		})
	end)
end

-- ============================================================ Merchants'

local function buildMerchantsGuild(guilds: Folder)
	HouseBuilder.build(guilds, {
		name = "MerchantsGuild",
		position = Vector3.new(52, 0, 55),
		rotation = -90,
		width = 32,
		depth = 26,
		stories = 2,
		storyHeight = 8,
		plasterColor = Color3.fromRGB(226, 216, 196),
		roofColor = Color3.fromRGB(60, 90, 120),
		doorWidth = 6,
		doorHeight = 7,
		interior = "none",
	})
	-- Footprint: x 39..65, z 39..71. Door faces west (-X) at (39, 55).
	-- Interior region: x 39.5..64.5, z 39.5..70.5. Ground ceiling plate at y 9.

	-- Signage + banners
	part({ Name = "SignBracket", Size = Vector3.new(0.3, 0.3, 2.6), Position = Vector3.new(38.2, 11.4, 54.4), Color = Color3.fromRGB(60, 58, 55), Material = Enum.Material.Metal }).Parent = guilds
	part({ Name = "SignBoard", Size = Vector3.new(0.4, 2.6, 4.4), Position = Vector3.new(38.2, 10, 55), Color = Color3.fromRGB(80, 70, 50), Material = Enum.Material.Wood }).Parent = guilds
	part({
		Name = "SignCoin",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 1.9, 1.9),
		CFrame = CFrame.new(37.9, 10, 55) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(220, 180, 80),
		Material = Enum.Material.Metal,
		CanCollide = false,
	}).Parent = guilds
	for _, z in { 46, 64 } do
		part({ Name = "BannerRod", Size = Vector3.new(2.8, 0.25, 0.25), Position = Vector3.new(39.2, 15.1, z), Color = BEAM_COLOR, Material = Enum.Material.Wood, CanCollide = false }).Parent = guilds
		part({ Name = "Banner", Size = Vector3.new(0.2, 6, 2.2), Position = Vector3.new(38.6, 12, z), Color = Color3.fromRGB(50, 90, 150), Material = Enum.Material.Fabric, CanCollide = false }).Parent = guilds
	end

	-- ---------------- ground floor: trading hall
	serviceCounter(guilds, 62.4, 47, 63)
	part({ Name = "CounterScale", Size = Vector3.new(0.9, 1, 0.5), Position = Vector3.new(62.4, 4.2, 59), Color = Color3.fromRGB(190, 160, 80), Material = Enum.Material.Metal, CanCollide = false }).Parent = guilds
	part({ Name = "CounterLedger", Size = Vector3.new(1.2, 0.18, 1.6), Position = Vector3.new(62.4, 3.79, 51), Color = PARCHMENT, Material = Enum.Material.SmoothPlastic, CanCollide = false }).Parent = guilds

	-- Scroll wall behind the counter (embedded into the east wall)
	for row = 0, 2 do
		part({ Name = "ScrollShelf", Size = Vector3.new(1, 0.35, 12), Position = Vector3.new(64.2, 4.4 + row * 1.8, 55), Color = BEAM_COLOR, Material = Enum.Material.Wood }).Parent = guilds
		for col = 0, 4 do
			part({
				Name = "Scroll",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1.1, 0.5, 0.5),
				CFrame = CFrame.new(63.9, 4.95 + row * 1.8, 50.4 + col * 2.2) * CFrame.Angles(0, math.rad(90), 0),
				Color = PARCHMENT,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
			}).Parent = guilds
		end
	end

	-- Central map table
	part({ Name = "MapTable", Size = Vector3.new(6.5, 0.5, 4.5), Position = Vector3.new(50, 3.3, 55), Color = Color3.fromRGB(110, 78, 48), Material = Enum.Material.WoodPlanks }).Parent = guilds
	for _, offset in { Vector3.new(-2.7, 0, -1.8), Vector3.new(2.7, 0, -1.8), Vector3.new(-2.7, 0, 1.8), Vector3.new(2.7, 0, 1.8) } do
		part({ Name = "MapTableLeg", Size = Vector3.new(0.4, 2.1, 0.4), Position = Vector3.new(50, 2, 55) + offset, Color = BEAM_COLOR, Material = Enum.Material.Wood }).Parent = guilds
	end
	part({ Name = "TableMap", Size = Vector3.new(5.4, 0.1, 3.4), Position = Vector3.new(50, 3.6, 55), Color = PARCHMENT, Material = Enum.Material.SmoothPlastic, CanCollide = false }).Parent = guilds
	part({ Name = "MapWeight", Size = Vector3.new(0.4, 0.3, 0.4), Position = Vector3.new(48.2, 3.8, 54), Color = Color3.fromRGB(90, 88, 86), Material = Enum.Material.Metal, CanCollide = false }).Parent = guilds

	-- Ledger desks along the north wall
	for _, x in { 46, 56 } do
		part({ Name = "DeskTop", Size = Vector3.new(3.6, 0.4, 2), Position = Vector3.new(x, 3.2, 68.6), Color = Color3.fromRGB(110, 78, 48), Material = Enum.Material.WoodPlanks }).Parent = guilds
		for _, offset in { Vector3.new(-1.5, 0, -0.7), Vector3.new(1.5, 0, -0.7), Vector3.new(-1.5, 0, 0.7), Vector3.new(1.5, 0, 0.7) } do
			part({ Name = "DeskLeg", Size = Vector3.new(0.3, 2, 0.3), Position = Vector3.new(x, 2, 68.6) + offset, Color = BEAM_COLOR, Material = Enum.Material.Wood }).Parent = guilds
		end
		part({ Name = "DeskPaper", Size = Vector3.new(1.1, 0.1, 0.9), Position = Vector3.new(x, 3.45, 68.6), Color = PARCHMENT, Material = Enum.Material.SmoothPlastic, CanCollide = false }).Parent = guilds
		part({ Name = "DeskStool", Size = Vector3.new(1.2, 1.4, 1.2), Position = Vector3.new(x, 1.8, 66.4), Color = Color3.fromRGB(110, 78, 48), Material = Enum.Material.Wood }).Parent = guilds
	end

	-- Crates and barrels, southwest corner
	for i = 0, 2 do
		part({ Name = "TradeCrate", Size = Vector3.new(1.8, 1.8, 1.8), Position = Vector3.new(42 + (i % 2) * 2.1, 2 + math.floor(i / 2) * 1.9, 42), Color = Color3.fromRGB(160, 126, 80), Material = Enum.Material.WoodPlanks }).Parent = guilds
	end
	part({
		Name = "TradeBarrel",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.4, 2.2, 2.2),
		CFrame = CFrame.new(46.5, 2.3, 41.8) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(110, 78, 48),
		Material = Enum.Material.WoodPlanks,
	}).Parent = guilds
	-- Coin chest by the counter
	part({ Name = "CoinChest", Size = Vector3.new(2.4, 1.6, 1.6), Position = Vector3.new(61, 1.9, 65.5), Color = Color3.fromRGB(96, 66, 40), Material = Enum.Material.Wood }).Parent = guilds
	part({ Name = "CoinPile", Size = Vector3.new(1.8, 0.5, 1.1), Position = Vector3.new(61, 2.95, 65.5), Color = Color3.fromRGB(230, 190, 90), Material = Enum.Material.Metal, CanCollide = false }).Parent = guilds

	hangingLantern(guilds, 50, 60, 9, 1.4, 20)
	hangingLantern(guilds, 58, 46, 9, 1.2, 18)

	-- Stairs up along the south wall
	stairsWestward(guilds, 61.5, 41.2, 8)

	-- ---------------- upper floor: offices
	part({ Name = "FloorPlate", Size = Vector3.new(24.6, 0.5, 27.4), Position = Vector3.new(52, 8.75, 56.6), Color = FLOOR_WOOD, Material = Enum.Material.WoodPlanks }).Parent = guilds
	part({ Name = "FloorPlate", Size = Vector3.new(10.3, 0.5, 3.4), Position = Vector3.new(44.85, 8.75, 41.2), Color = FLOOR_WOOD, Material = Enum.Material.WoodPlanks }).Parent = guilds
	guardRailZ(guilds, 42.9, 50, 62.7, 9)
	guardRailX(guilds, 50, 39.7, 42.9, 9)

	-- Office furnishings
	for _, z in { 62, 50 } do
		part({ Name = "OfficeDesk", Size = Vector3.new(3.6, 0.4, 2), Position = Vector3.new(43.5, 11.2, z), Color = Color3.fromRGB(110, 78, 48), Material = Enum.Material.WoodPlanks }).Parent = guilds
		for _, offset in { Vector3.new(-1.5, 0, -0.7), Vector3.new(1.5, 0, -0.7), Vector3.new(-1.5, 0, 0.7), Vector3.new(1.5, 0, 0.7) } do
			part({ Name = "DeskLeg", Size = Vector3.new(0.3, 2, 0.3), Position = Vector3.new(43.5, 10, z) + offset, Color = BEAM_COLOR, Material = Enum.Material.Wood }).Parent = guilds
		end
		part({ Name = "OfficeStool", Size = Vector3.new(1.2, 1.4, 1.2), Position = Vector3.new(45.8, 9.8, z), Color = Color3.fromRGB(110, 78, 48), Material = Enum.Material.Wood }).Parent = guilds
	end
	part({ Name = "RecordShelf", Size = Vector3.new(1, 6, 8), Position = Vector3.new(63.9, 12.05, 62), Color = DARK_WOOD, Material = Enum.Material.WoodPlanks }).Parent = guilds
	part({ Name = "Strongbox", Size = Vector3.new(2, 1.6, 1.5), Position = Vector3.new(62.5, 9.85, 46), Color = Color3.fromRGB(70, 68, 66), Material = Enum.Material.Metal }).Parent = guilds
	part({ Name = "OfficeRug", Size = Vector3.new(14, 0.12, 5), Position = Vector3.new(52, 9.06, 56), Color = Color3.fromRGB(80, 95, 120), Material = Enum.Material.Fabric, CanCollide = false }).Parent = guilds

	for _, z in { 48, 62 } do
		part({ Name = "CollarRafter", Size = Vector3.new(24.5, 0.5, 0.7), Position = Vector3.new(52, 17.15, z), Color = BEAM_COLOR, Material = Enum.Material.Wood, CanCollide = false }).Parent = guilds
	end
	hangingLantern(guilds, 52, 48, 17, 1, 16)
	hangingLantern(guilds, 52, 62, 17, 1, 16)

	PartUtil.marker("BrowseSpot", Vector3.new(47, 1.6, 55)).Parent = guilds -- map table
	PartUtil.marker("BrowseSpot", Vector3.new(60.5, 1.6, 55)).Parent = guilds -- counter

	task.spawn(function()
		local aldric = AvatarFactory.createStatic({
			name = "Master Aldric",
			hairId = 112378007199540,
			body = "masc",
			shape = "thin",
			shirtId = 10565347864,
			pantsId = 180864440,
			skin = Color3.fromRGB(255, 219, 172),
			position = Vector3.new(63.6, 0.5, 55),
			facing = -Vector3.xAxis,
		})
		if aldric then
			aldric:SetAttribute("ShopId", "MerchantsGuild")
			game:GetService("CollectionService"):AddTag(aldric, "Shopkeeper")
		end
	end)
	task.spawn(function()
		AvatarFactory.createStatic({
			name = "Scribe Odell",
			hairId = 14651241814,
			body = "masc",
			shape = "thin",
			shirtId = 329836637,
			pantsId = 17154514582,
			skin = Color3.fromRGB(214, 173, 130),
			position = Vector3.new(56, 0.5, 66.9),
			facing = Vector3.zAxis,
		})
	end)
end

function GuildBuilder.build(parentFolder: Instance)
	local guilds = Instance.new("Folder")
	guilds.Name = "Guilds"
	buildAdventurersGuild(guilds)
	buildMerchantsGuild(guilds)
	guilds.Parent = parentFolder
end

return GuildBuilder
