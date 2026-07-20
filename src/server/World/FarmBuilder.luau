--!strict
-- The farming hamlet around the Rowan cottage: farmhouses, barn, silo,
-- windmill, sheds, fenced wheat fields, and dirt lanes.

local PartUtil = require(script.Parent.PartUtil)
local HouseBuilder = require(script.Parent.HouseBuilder)
local Textures = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Data.Textures)

local part = PartUtil.part

local BEAM_COLOR = Color3.fromRGB(74, 52, 34)
local WHEAT_TEXTURE = `rbxassetid://{Textures.wheat_card}`
local WHEAT_CARD_ASPECT = 320 / 480 -- matches textures/wheat_card.png so it never stretches

local FarmBuilder = {}

local function fenceRun(parent: Instance, p0: Vector3, p1: Vector3)
	local postSpacing = 6
	local length = (p1 - p0).Magnitude
	if length <= 0 then
		return
	end
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

export type FenceGate = { side: "north" | "south" | "east" | "west", at: number, width: number }

-- `gates` cut a walkable gap in the perimeter where a path crosses it: `at`
-- is the world X (for the north/south sides) or world Z (for the east/west
-- sides) of the gap's center.
local function fence(parent: Instance, centerX: number, centerZ: number, w: number, d: number, gates: { FenceGate }?)
	local halfW = w / 2 + 1.5
	local halfD = d / 2 + 1.5

	local function side(p0: Vector3, p1: Vector3, sideName: string)
		local dir = p1 - p0
		local length = dir.Magnitude
		local unit = dir.Unit
		local alongX = math.abs(unit.X) > 0.5
		local cuts = {}
		local gateList: { FenceGate } = gates or {}
		for _, g in gateList do
			if g.side == sideName then
				local coord = if alongX then g.at - p0.X else g.at - p0.Z
				table.insert(cuts, { math.max(0, coord - g.width / 2), math.min(length, coord + g.width / 2) })
			end
		end
		table.sort(cuts, function(a, b)
			return a[1] < b[1]
		end)
		local cursor = 0
		for _, cut in cuts do
			if cut[1] > cursor then
				fenceRun(parent, p0 + unit * cursor, p0 + unit * cut[1])
			end
			cursor = math.max(cursor, cut[2])
		end
		if cursor < length then
			fenceRun(parent, p0 + unit * cursor, p1)
		end
	end

	side(Vector3.new(centerX - halfW, 0, centerZ + halfD), Vector3.new(centerX + halfW, 0, centerZ + halfD), "north")
	side(Vector3.new(centerX - halfW, 0, centerZ - halfD), Vector3.new(centerX + halfW, 0, centerZ - halfD), "south")
	side(Vector3.new(centerX - halfW, 0, centerZ - halfD), Vector3.new(centerX - halfW, 0, centerZ + halfD), "west")
	side(Vector3.new(centerX + halfW, 0, centerZ - halfD), Vector3.new(centerX + halfW, 0, centerZ + halfD), "east")
end

-- `roadZ`/`roadWidth` describe a dirt road that cuts straight through the
-- field along the east-west axis (built separately by the caller); the field
-- leaves it clear of wheat and opens gates in its own fence where the road
-- crosses the boundary.
local function wheatField(parent: Instance, centerX: number, centerZ: number, w: number, d: number, roadZ: number, roadWidth: number)
	-- Terrain's Grass material ships with animated blades that sway in
	-- simulated wind out of the box — far cheaper and better-animated than
	-- covering a field this size in individual parts. The slab's top sits at
	-- y=0, flush with the rest of the world's ground level.
	workspace.Terrain:FillBlock(CFrame.new(centerX, -2, centerZ), Vector3.new(w, 4, d), Enum.Material.Grass)

	-- Textured billboard cards (a crossed pair per clump) scattered on top —
	-- this carries the field's read as "wheat" on its own; the terrain slab
	-- underneath is a color/wind bonus, not the primary visual
	-- (Terrain.Decoration, the thing that actually draws individual terrain
	-- blades, can't be set by any script, Rojo included — it's a Studio-only
	-- toggle). Parts are invisible (Transparency 1); only the Decals on
	-- their faces render, which is what makes a flat card read as a sprite
	-- instead of a visible box. Combed toward one prevailing wind direction
	-- per field, kept clear of the road strip. Seeded from the field's
	-- position so it looks the same on every server.
	local rng = Random.new(math.floor(centerX * 37 + centerZ * 131))
	local windYaw = rng:NextNumber(0, math.pi * 2)
	local roadHalf = roadWidth / 2 + 2
	local function onRoad(z: number): boolean
		return math.abs(z - roadZ) < roadHalf
	end

	local tuftCount = math.min(3200, math.floor((w * d) / 16))
	local placed = 0
	local attempts = 0
	while placed < tuftCount and attempts < tuftCount * 3 do
		attempts += 1
		local x = centerX + rng:NextNumber(-w / 2 + 2, w / 2 - 2)
		local z = centerZ + rng:NextNumber(-d / 2 + 2, d / 2 - 2)
		if onRoad(z) then
			continue
		end
		placed += 1

		if rng:NextNumber() < 0.05 then
			local bloomColor = if rng:NextNumber() < 0.5
				then Color3.fromRGB(196, 48, 56) -- poppy
				else Color3.fromRGB(88, 100, 188) -- cornflower
			part({
				Name = "FieldFlowerStem",
				Size = Vector3.new(0.14, 1.6, 0.14),
				Position = Vector3.new(x, 0.8, z),
				Color = Color3.fromRGB(90, 120, 60),
				Material = Enum.Material.Grass,
				CanCollide = false,
			}).Parent = parent
			part({
				Name = "FieldFlowerBloom",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.5, 0.4, 0.5),
				Position = Vector3.new(x, 1.65, z),
				Color = bloomColor,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
			}).Parent = parent
			continue
		end

		local cardHeight = rng:NextNumber(5.0, 6.6)
		local cardWidth = cardHeight * WHEAT_CARD_ASPECT
		local yaw = windYaw + math.rad(rng:NextNumber(-30, 30))
		local lean = math.rad(rng:NextNumber(0, 8))
		-- Decal.Color3 is a filter on top of the image's own colors (the
		-- source art isn't pure white), so a light near-white jitter here
		-- gives each clump a slightly different gold without needing more
		-- than one texture.
		local tint = Color3.new(
			math.clamp(rng:NextNumber(0.88, 1.05), 0, 1),
			math.clamp(rng:NextNumber(0.88, 1.05), 0, 1),
			math.clamp(rng:NextNumber(0.78, 0.95), 0, 1)
		)

		local function card(cardYaw: number)
			local cardPart = part({
				Name = "WheatCard",
				Size = Vector3.new(cardWidth, cardHeight, 0.05),
				CFrame = CFrame.new(x, cardHeight / 2 - 0.05, z) * CFrame.Angles(0, cardYaw, 0) * CFrame.Angles(lean, 0, 0),
				Transparency = 1,
				CanCollide = false,
			})
			for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
				local decal = Instance.new("Decal")
				decal.Name = "WheatDecal"
				decal.Face = face
				decal.Texture = WHEAT_TEXTURE
				decal.Color3 = tint
				decal.Parent = cardPart
			end
			cardPart.Parent = parent
		end

		-- Two cards crossed 90 degrees apart so the clump reads as a shape
		-- from most viewing angles, not just a flat cutout from one side.
		card(yaw)
		card(yaw + math.rad(90))
	end

	local gates: { FenceGate } = {
		{ side = "west", at = roadZ, width = roadWidth + 2 },
		{ side = "east", at = roadZ, width = roadWidth + 2 },
	}
	fence(parent, centerX, centerZ, w, d, gates)
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

	-- Global tint for Terrain's Grass material — this affects every Grass
	-- terrain voxel in the place (there's only ever the wheat fields' right
	-- now), not the Part-based hay bales/wheat stalks elsewhere, which use
	-- their own explicit Color regardless of this setting.
	workspace.Terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(214, 178, 88))

	-- Grass terrain doesn't sway at all without a global wind vector (it
	-- defaults to zero). NOTE: this alone isn't enough to see individual
	-- blades — Terrain.Decoration also has to be switched on, and Roblox
	-- flags that property NotScriptable, so it can only be toggled by hand
	-- in Studio's Properties panel (persists once saved with the place).
	workspace.GlobalWind = Vector3.new(6, 0, 3)

	-- Farmhouses (real furnished interiors)
	HouseBuilder.build(farm, {
		name = "FarmhouseWest",
		position = Vector3.new(-50, 0, -70),
		rotation = 90,
		width = 30,
		depth = 24,
		stories = 1,
		plasterColor = Color3.fromRGB(226, 214, 186),
		seed = 21,
		signText = "Thatch Farmstead",
		signMajor = true,
	})
	HouseBuilder.build(farm, {
		name = "FarmhouseSouth",
		position = Vector3.new(-45, 0, -110),
		rotation = 0,
		width = 30,
		depth = 24,
		stories = 2,
		plasterColor = Color3.fromRGB(220, 206, 180),
		seed = 22,
		signText = "Varn Farmstead",
		signMajor = true,
	})

	-- Barn: tall single story, big open door, working interior below
	HouseBuilder.build(farm, {
		name = "Barn",
		position = Vector3.new(45, 0, -80),
		rotation = -90,
		width = 24,
		depth = 18,
		stories = 1,
		storyHeight = 12,
		doorWidth = 8,
		doorHeight = 10,
		plasterColor = Color3.fromRGB(152, 46, 38),
		beamColor = Color3.fromRGB(228, 220, 205),
		roofColor = Color3.fromRGB(70, 62, 58),
		interior = "none",
		signText = "Rowan Barn",
		signMajor = true,
	})
	-- Barn interior (world coords; footprint x 36..54, z -92..-68, door west at x 36):
	-- hay bales stacked in the northeast, animal stalls along the south wall
	local HAY = Color3.fromRGB(212, 178, 92)
	for i = 0, 4 do
		part({
			Name = "HayBale",
			Size = Vector3.new(2.6, 1.8, 1.8),
			Position = Vector3.new(49 + (i % 2) * 3, 1.9 + math.floor(i / 3) * 1.85, -71.5 + (if i < 3 then math.floor(i / 2) * 2.2 else 0)),
			Color = HAY,
			Material = Enum.Material.Grass,
		}).Parent = farm
	end
	for _, x in { 42, 48 } do
		part({
			Name = "StallDivider",
			Size = Vector3.new(0.4, 3.4, 5),
			Position = Vector3.new(x, 2.7, -89),
			Color = Color3.fromRGB(150, 120, 80),
			Material = Enum.Material.WoodPlanks,
		}).Parent = farm
	end
	for _, x in { 39, 45, 51 } do
		part({
			Name = "FeedTrough",
			Size = Vector3.new(2.4, 0.9, 1),
			Position = Vector3.new(x, 1.55, -90.6),
			Color = Color3.fromRGB(110, 78, 48),
			Material = Enum.Material.WoodPlanks,
		}).Parent = farm
	end
	for i = 0, 2 do
		part({
			Name = "BarnCrate",
			Size = Vector3.new(1.8, 1.8, 1.8),
			Position = Vector3.new(38.2, 2 + (if i == 2 then 1.9 else 0), -70.5 + (i % 2) * 2.1),
			Color = Color3.fromRGB(160, 126, 80),
			Material = Enum.Material.WoodPlanks,
		}).Parent = farm
	end
	-- Hanging barn lantern (chain reaches the collar beam)
	part({ Name = "BarnBeam", Size = Vector3.new(17, 0.5, 0.7), Position = Vector3.new(45, 13.15, -80), Color = Color3.fromRGB(228, 220, 205), Material = Enum.Material.Wood, CanCollide = false }).Parent = farm
	part({ Name = "BarnLampChain", Size = Vector3.new(0.18, 2.6, 0.18), Position = Vector3.new(45, 11.9, -80), Color = Color3.fromRGB(80, 80, 80), Material = Enum.Material.Metal, CanCollide = false }).Parent = farm
	local barnLamp = part({
		Name = "BarnLantern",
		Size = Vector3.new(0.9, 1.2, 0.9),
		Position = Vector3.new(45, 10.3, -80),
		Color = Color3.fromRGB(255, 214, 130),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	local barnLight = Instance.new("PointLight")
	barnLight.Color = Color3.fromRGB(255, 205, 120)
	barnLight.Brightness = 1.2
	barnLight.Range = 20
	barnLight.Parent = barnLamp
	barnLamp.Parent = farm

	silo(farm, 70, -85)

	-- Sheds
	HouseBuilder.build(farm, {
		name = "ToolShed",
		position = Vector3.new(70, 0, -50),
		rotation = -90,
		width = 14,
		depth = 14,
		stories = 1,
		storyHeight = 14,
		signText = "Tool Shed",
		plasterColor = Color3.fromRGB(190, 172, 140),
	})
	HouseBuilder.build(farm, {
		name = "CoopShed",
		position = Vector3.new(46, 0, -28),
		rotation = 180,
		width = 12,
		depth = 14,
		stories = 1,
		storyHeight = 14,
		signText = "Chicken Coop",
		plasterColor = Color3.fromRGB(200, 180, 150),
	})

	windmill(farm, -90, -140)

	-- Wheat fields: two big tracts flanking the hamlet (west of the windmill,
	-- east of the barn/silo/tool shed cluster) — roughly 10x the total wheat
	-- acreage of the old three small fields — each with a dirt road cutting
	-- straight through the middle, gated through its own fence.
	wheatField(farm, -164, -112.5, 64, 155, -90, 8)
	wheatField(farm, 148, -112.5, 92, 155, -100, 8)

	-- Farm lanes route AROUND the buildings they serve (they previously ran
	-- straight through both farmhouses, the barn and the coop).
	dirtLane(farm, -22.5, -60, 25, 8) -- west lane, stops clear of FarmhouseWest
	dirtLane(farm, 0, -60, 22, 8, 0.36) -- links both lanes across the south connector
	dirtLane(farm, 34.5, -60, 49, 8) -- east lane, stops clear of the ToolShed
	dirtLane(farm, -31, -75.5, 8, 39, 0.30) -- down FarmhouseWest's door side
	dirtLane(farm, -38, -92, 22, 6, 0.36) -- FarmhouseSouth doorstep spur
	dirtLane(farm, 20, -40, 6, 44, 0.30) -- cottage east spur (narrowed to clear the pen)
	dirtLane(farm, 10, -22, 22, 7, 0.44) -- links that spur to the cottage path
	dirtLane(farm, 28.5, -71, 9, 26, 0.34) -- barn spur
	dirtLane(farm, 54, -50, 12, 7, 0.44) -- tool shed spur
	dirtLane(farm, 46, -47.5, 8, 19, 0.38) -- coop spur

	-- Out to the wheat fields, threading between the farmhouses (clear of
	-- both) and south of the barn/silo cluster, then straight through each
	-- field via its gated fence.
	dirtLane(farm, -81.5, -90, 101, 8) -- connector: hamlet to the west field's gate
	dirtLane(farm, -164, -90, 64, 8) -- straight through the west field
	dirtLane(farm, 80.5, -100, 43, 8) -- connector: hamlet to the east field's gate
	dirtLane(farm, 148, -100, 92, 8) -- straight through the east field

	farm.Parent = parentFolder
	return farm
end

return FarmBuilder
