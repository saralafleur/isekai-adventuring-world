--!strict
-- The two guild halls flanking the market plaza, with furnished interiors and
-- shopkeeper avatars.
--   Adventurers' Guild (west): gear, armor and expedition utilities
--   Merchants' Guild (east): maps, information and skill sheets

local PartUtil = require(script.Parent.PartUtil)
local HouseBuilder = require(script.Parent.HouseBuilder)
local AvatarFactory = require(script.Parent.Parent.NPC.AvatarFactory)

local part = PartUtil.part

local BEAM_COLOR = Color3.fromRGB(74, 52, 34)
local PARCHMENT = Color3.fromRGB(228, 214, 180)

local GuildBuilder = {}

local function hangingSign(parent: Instance, position: Vector3, boardColor: Color3)
	part({ Name = "SignBracket", Size = Vector3.new(0.3, 0.3, 2.6), Position = position + Vector3.new(0, 1.4, -0.6), Color = Color3.fromRGB(60, 58, 55), Material = Enum.Material.Metal }).Parent = parent
	part({ Name = "SignBoard", Size = Vector3.new(4.4, 2.6, 0.4), Position = position, Color = boardColor, Material = Enum.Material.Wood }).Parent = parent
end

local function banner(parent: Instance, position: Vector3, color: Color3)
	part({
		Name = "Banner",
		Size = Vector3.new(2.2, 6, 0.2),
		Position = position,
		Color = color,
		Material = Enum.Material.Fabric,
		CanCollide = false,
	}).Parent = parent
	part({
		Name = "BannerRod",
		Size = Vector3.new(2.8, 0.25, 0.25),
		Position = position + Vector3.new(0, 3.1, 0),
		Color = BEAM_COLOR,
		Material = Enum.Material.Wood,
		CanCollide = false,
	}).Parent = parent
end

local function interiorLight(parent: Instance, position: Vector3)
	local lamp = part({
		Name = "GuildLantern",
		Size = Vector3.new(1, 1.3, 1),
		Position = position,
		Color = Color3.fromRGB(255, 214, 130),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 205, 120)
	light.Brightness = 1.5
	light.Range = 24
	light.Parent = lamp
	lamp.Parent = parent
end

local function counter(parent: Instance, position: Vector3, alongX: boolean)
	part({
		Name = "GuildCounter",
		Size = if alongX then Vector3.new(10, 1, 2.2) else Vector3.new(2.2, 1, 10),
		Position = position + Vector3.new(0, 2.6, 0),
		Color = Color3.fromRGB(110, 78, 48),
		Material = Enum.Material.WoodPlanks,
	}).Parent = parent
	part({
		Name = "GuildCounterBase",
		Size = if alongX then Vector3.new(9.6, 2.2, 1.8) else Vector3.new(1.8, 2.2, 9.6),
		Position = position + Vector3.new(0, 1.2, 0),
		Color = Color3.fromRGB(96, 66, 40),
		Material = Enum.Material.Wood,
	}).Parent = parent
end

function GuildBuilder.build(parentFolder: Instance)
	local guilds = Instance.new("Folder")
	guilds.Name = "Guilds"

	-- ============================== Adventurers' Guild (west of plaza)
	-- Center (-48, 60), rotated 90: door faces east onto the plaza at x=-39
	HouseBuilder.build(guilds, {
		name = "AdventurersGuild",
		position = Vector3.new(-48, 0, 60),
		rotation = 90,
		width = 24,
		depth = 18,
		stories = 2,
		stoneGround = true,
		plasterColor = Color3.fromRGB(214, 200, 175),
		roofColor = Color3.fromRGB(70, 62, 58),
		doorWidth = 6,
		doorHeight = 7,
		openDoor = true,
	})

	-- Signage: crossed swords over the door + red banners
	hangingSign(guilds, Vector3.new(-38.2, 10, 60), Color3.fromRGB(90, 60, 40))
	for _, angle in { 40, -40 } do
		part({
			Name = "SignSword",
			Size = Vector3.new(0.35, 3, 0.2),
			CFrame = CFrame.new(-37.9, 10, 60) * CFrame.Angles(0, math.rad(90), math.rad(angle)),
			Color = Color3.fromRGB(200, 200, 210),
			Material = Enum.Material.Metal,
			CanCollide = false,
		}).Parent = guilds
	end
	banner(guilds, Vector3.new(-39.2, 12, 52), Color3.fromRGB(160, 40, 40))
	banner(guilds, Vector3.new(-39.2, 12, 68), Color3.fromRGB(160, 40, 40))

	-- Interior: counter along the back (west) wall, keeper behind it
	counter(guilds, Vector3.new(-52, 0, 60), false)
	interiorLight(guilds, Vector3.new(-48, 9, 60))
	-- Weapon wall: display swords + a shield behind the counter
	part({ Name = "DisplayBoard", Size = Vector3.new(0.4, 5, 12), Position = Vector3.new(-56.2, 6, 60), Color = BEAM_COLOR, Material = Enum.Material.Wood }).Parent = guilds
	for i = 0, 2 do
		part({
			Name = "DisplaySword",
			Size = Vector3.new(0.25, 3.2, 0.18),
			Position = Vector3.new(-55.8, 6, 55.5 + i * 3),
			Color = Color3.fromRGB(190, 190, 200),
			Material = Enum.Material.Metal,
			CanCollide = false,
		}).Parent = guilds
	end
	part({
		Name = "DisplayShield",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 2.6, 2.6),
		CFrame = CFrame.new(-55.8, 6, 64.5) * CFrame.Angles(0, math.rad(90), 0),
		Color = Color3.fromRGB(120, 80, 50),
		Material = Enum.Material.Wood,
		CanCollide = false,
	}).Parent = guilds
	-- Armor stand near the door
	part({ Name = "ArmorStandPost", Size = Vector3.new(0.4, 5, 0.4), Position = Vector3.new(-43, 3.5, 53), Color = BEAM_COLOR, Material = Enum.Material.Wood }).Parent = guilds
	part({ Name = "ArmorStandChest", Size = Vector3.new(2.2, 2.4, 1.2), Position = Vector3.new(-43, 4.4, 53), Color = Color3.fromRGB(120, 85, 60), Material = Enum.Material.Leather }).Parent = guilds
	-- Notice board with quest papers
	part({ Name = "NoticeBoard", Size = Vector3.new(0.4, 3.4, 5), Position = Vector3.new(-40.2, 5, 68.5), Color = Color3.fromRGB(96, 70, 46), Material = Enum.Material.Wood }).Parent = guilds
	for i = 0, 3 do
		part({
			Name = "NoticePaper",
			Size = Vector3.new(0.1, 1.1, 0.9),
			Position = Vector3.new(-39.9, 5.6 - (i % 2) * 1.3, 67 + math.floor(i / 2) * 1.6),
			Color = PARCHMENT,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		}).Parent = guilds
	end

	-- ============================== Merchants' Guild (east of plaza)
	-- Center (48, 60), rotated -90: door faces west onto the plaza at x=39
	HouseBuilder.build(guilds, {
		name = "MerchantsGuild",
		position = Vector3.new(48, 0, 60),
		rotation = -90,
		width = 24,
		depth = 18,
		stories = 2,
		plasterColor = Color3.fromRGB(226, 216, 196),
		roofColor = Color3.fromRGB(60, 90, 120),
		doorWidth = 6,
		doorHeight = 7,
		openDoor = true,
	})

	-- Signage: gold coin over the door + blue banners
	hangingSign(guilds, Vector3.new(38.2, 10, 60), Color3.fromRGB(80, 70, 50))
	part({
		Name = "SignCoin",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 1.9, 1.9),
		CFrame = CFrame.new(37.9, 10, 60) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(220, 180, 80),
		Material = Enum.Material.Metal,
		CanCollide = false,
	}).Parent = guilds
	banner(guilds, Vector3.new(39.2, 12, 52), Color3.fromRGB(50, 90, 150))
	banner(guilds, Vector3.new(39.2, 12, 68), Color3.fromRGB(50, 90, 150))

	-- Interior: counter along the back (east) wall
	counter(guilds, Vector3.new(52, 0, 60), false)
	interiorLight(guilds, Vector3.new(48, 9, 60))
	-- Scroll shelves behind the counter
	part({ Name = "ScrollShelf", Size = Vector3.new(0.6, 6, 12), Position = Vector3.new(56, 4.5, 60), Color = BEAM_COLOR, Material = Enum.Material.Wood }).Parent = guilds
	for row = 0, 2 do
		for col = 0, 4 do
			part({
				Name = "Scroll",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1.1, 0.5, 0.5),
				CFrame = CFrame.new(55.4, 2.6 + row * 1.8, 55.6 + col * 2.2) * CFrame.Angles(0, math.rad(90), 0),
				Color = PARCHMENT,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
			}).Parent = guilds
		end
	end
	-- Map table with papers
	part({ Name = "MapTable", Size = Vector3.new(5, 0.4, 3.5), Position = Vector3.new(44, 3.2, 52), Color = Color3.fromRGB(110, 78, 48), Material = Enum.Material.WoodPlanks }).Parent = guilds
	for _, offset in { Vector3.new(-2, 0, -1.3), Vector3.new(2, 0, -1.3), Vector3.new(-2, 0, 1.3), Vector3.new(2, 0, 1.3) } do
		part({ Name = "MapTableLeg", Size = Vector3.new(0.35, 2.2, 0.35), Position = Vector3.new(44, 2, 52) + offset, Color = BEAM_COLOR, Material = Enum.Material.Wood }).Parent = guilds
	end
	part({ Name = "TableMap", Size = Vector3.new(3.6, 0.08, 2.6), Position = Vector3.new(44, 3.46, 52), Color = PARCHMENT, Material = Enum.Material.SmoothPlastic, CanCollide = false }).Parent = guilds
	-- Coin chest by the counter
	part({ Name = "CoinChest", Size = Vector3.new(2.4, 1.6, 1.6), Position = Vector3.new(52, 1.3, 66), Color = Color3.fromRGB(96, 66, 40), Material = Enum.Material.Wood }).Parent = guilds
	part({ Name = "CoinPile", Size = Vector3.new(1.8, 0.5, 1.1), Position = Vector3.new(52, 2.3, 66), Color = Color3.fromRGB(230, 190, 90), Material = Enum.Material.Metal, CanCollide = false }).Parent = guilds

	guilds.Parent = parentFolder

	-- ============================== Shopkeepers
	task.spawn(function()
		local thorne = AvatarFactory.createStatic({
			name = "Guildmaster Thorne",
			shirtId = 11401062683, -- Knight Shirt
			pantsId = 11199196921, -- Medieval Pants
			skin = Color3.fromRGB(214, 173, 130),
			position = Vector3.new(-54, 0.5, 60),
			facing = Vector3.xAxis,
			widthScale = 1.1,
		})
		if thorne then
			thorne:SetAttribute("ShopId", "AdventurersGuild")
			game:GetService("CollectionService"):AddTag(thorne, "Shopkeeper")
		end
	end)
	task.spawn(function()
		local aldric = AvatarFactory.createStatic({
			name = "Master Aldric",
			shirtId = 10565347864, -- Noble Shirt
			pantsId = 180864440, -- Noble Pants
			skin = Color3.fromRGB(255, 219, 172),
			position = Vector3.new(54, 0.5, 60),
			facing = -Vector3.xAxis,
		})
		if aldric then
			aldric:SetAttribute("ShopId", "MerchantsGuild")
			game:GetService("CollectionService"):AddTag(aldric, "Shopkeeper")
		end
	end)
end

return GuildBuilder
