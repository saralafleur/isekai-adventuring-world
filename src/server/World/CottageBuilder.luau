--!strict
-- Builds the Rowan family cottage: timber-frame fantasy style with real window
-- openings, pitched shingle roof, chimney, fireplace, and furnished interior.
-- Footprint: x -15..15, z -52..-28 (center 0,-40). Floor top at y=1, walls to y=10.

local CottageBuilder = {}

local WALL_BASE = 1
local WALL_TOP = 10
local WALL_THICKNESS = 1
local RISE = 8 -- roof rise from wall top to ridge
local HALF_DEPTH = 12
local OVERHANG = 2

local PLASTER_COLOR = Color3.fromRGB(232, 224, 205)
local BEAM_COLOR = Color3.fromRGB(74, 52, 34)
local ROOF_COLOR = Color3.fromRGB(112, 66, 48)
local STONE_COLOR = Color3.fromRGB(130, 126, 120)

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

type Opening = { center: number, width: number, y0: number, y1: number }

-- Builds an axis-aligned wall from p1 to p2 (ground endpoints) with real openings.
local function segmentedWall(
	parent: Instance,
	p1: Vector3,
	p2: Vector3,
	openings: { Opening }
)
	local delta = p2 - p1
	local length = delta.Magnitude
	local dir = delta.Unit
	local alongX = math.abs(dir.X) > 0.5

	local function panel(fromOffset: number, toOffset: number, y0: number, y1: number)
		local segLength = toOffset - fromOffset
		if segLength <= 0.05 or (y1 - y0) <= 0.05 then
			return
		end
		local mid = p1 + dir * ((fromOffset + toOffset) / 2)
		local p = part({
			Name = "WallPanel",
			Size = if alongX
				then Vector3.new(segLength, y1 - y0, WALL_THICKNESS)
				else Vector3.new(WALL_THICKNESS, y1 - y0, segLength),
			Position = Vector3.new(mid.X, (y0 + y1) / 2, mid.Z),
			Color = PLASTER_COLOR,
			Material = Enum.Material.Plaster,
		})
		p.Parent = parent
	end

	table.sort(openings, function(a, b)
		return a.center < b.center
	end)

	local cursor = 0
	for _, opening in openings do
		local left = opening.center - opening.width / 2
		local right = opening.center + opening.width / 2
		panel(cursor, left, WALL_BASE, WALL_TOP)
		panel(left, right, WALL_BASE, opening.y0) -- below opening
		panel(left, right, opening.y1, WALL_TOP) -- above opening
		cursor = right
	end
	panel(cursor, length, WALL_BASE, WALL_TOP)
end

local function windowFrame(parent: Instance, center: Vector3, width: number, y0: number, y1: number, alongX: boolean)
	local frameT = 0.5
	local depth = WALL_THICKNESS + 0.4
	local h = y1 - y0
	local cy = (y0 + y1) / 2

	local function framePiece(size: Vector3, pos: Vector3)
		part({
			Name = "WindowFrame",
			Size = size,
			Position = pos,
			Color = BEAM_COLOR,
			Material = Enum.Material.Wood,
		}).Parent = parent
	end

	if alongX then
		framePiece(Vector3.new(width + frameT * 2, frameT, depth), Vector3.new(center.X, y1 + frameT / 2, center.Z))
		framePiece(Vector3.new(width + frameT * 2, frameT, depth), Vector3.new(center.X, y0 - frameT / 2, center.Z))
		framePiece(Vector3.new(frameT, h, depth), Vector3.new(center.X - width / 2 - frameT / 2, cy, center.Z))
		framePiece(Vector3.new(frameT, h, depth), Vector3.new(center.X + width / 2 + frameT / 2, cy, center.Z))
		-- cross muntins
		framePiece(Vector3.new(width, 0.2, 0.2), Vector3.new(center.X, cy, center.Z))
		framePiece(Vector3.new(0.2, h, 0.2), Vector3.new(center.X, cy, center.Z))
	else
		framePiece(Vector3.new(depth, frameT, width + frameT * 2), Vector3.new(center.X, y1 + frameT / 2, center.Z))
		framePiece(Vector3.new(depth, frameT, width + frameT * 2), Vector3.new(center.X, y0 - frameT / 2, center.Z))
		framePiece(Vector3.new(depth, h, frameT), Vector3.new(center.X, cy, center.Z - width / 2 - frameT / 2))
		framePiece(Vector3.new(depth, h, frameT), Vector3.new(center.X, cy, center.Z + width / 2 + frameT / 2))
		framePiece(Vector3.new(0.2, 0.2, width), Vector3.new(center.X, cy, center.Z))
		framePiece(Vector3.new(0.2, h, 0.2), Vector3.new(center.X, cy, center.Z))
	end

	local glass = part({
		Name = "WindowGlass",
		Size = if alongX then Vector3.new(width, h, 0.15) else Vector3.new(0.15, h, width),
		Position = Vector3.new(center.X, cy, center.Z),
		Color = Color3.fromRGB(170, 200, 220),
		Material = Enum.Material.Glass,
		Transparency = 0.4,
		CanCollide = false,
	})
	glass.Parent = parent
end

local function cornerPostsAndPlates(parent: Instance)
	local corners = {
		Vector3.new(-15, 0, -52),
		Vector3.new(15, 0, -52),
		Vector3.new(-15, 0, -28),
		Vector3.new(15, 0, -28),
	}
	for _, corner in corners do
		part({
			Name = "CornerPost",
			Size = Vector3.new(1.4, WALL_TOP - WALL_BASE + 0.4, 1.4),
			Position = Vector3.new(corner.X, (WALL_BASE + WALL_TOP) / 2, corner.Z),
			Color = BEAM_COLOR,
			Material = Enum.Material.Wood,
		}).Parent = parent
	end
	-- Horizontal plates (top and mid) on each face, slightly proud of the plaster
	local faces = {
		{ size = Vector3.new(31, 0.6, 1.4), pos = Vector3.new(0, 0, -52) },
		{ size = Vector3.new(31, 0.6, 1.4), pos = Vector3.new(0, 0, -28) },
		{ size = Vector3.new(1.4, 0.6, 25), pos = Vector3.new(-15, 0, -40) },
		{ size = Vector3.new(1.4, 0.6, 25), pos = Vector3.new(15, 0, -40) },
	}
	-- Top plates only — a mid-height plate would cut across the window and door openings
	for _, face in faces do
		part({
			Name = "Beam",
			Size = face.size,
			Position = Vector3.new(face.pos.X, WALL_TOP - 0.3, face.pos.Z),
			Color = BEAM_COLOR,
			Material = Enum.Material.Wood,
		}).Parent = parent
	end
end

local function roof(parent: Instance)
	local angle = math.atan(RISE / HALF_DEPTH)
	local run = HALF_DEPTH + OVERHANG
	local drop = math.tan(angle) * run
	local slabLength = math.sqrt(run * run + drop * drop)
	local ridgeY = WALL_TOP + RISE
	local eaveY = ridgeY - drop

	-- South slab (descends toward +Z), north slab mirrored
	for _, side in { 1, -1 } do
		local centerZ = -40 + side * run / 2
		local centerY = (ridgeY + eaveY) / 2
		local slab = part({
			Name = "RoofSlab",
			Size = Vector3.new(34, 0.5, slabLength),
			CFrame = CFrame.new(0, centerY, centerZ) * CFrame.Angles(side * angle, 0, 0),
			Color = ROOF_COLOR,
			Material = Enum.Material.RoofShingles,
		})
		slab.Parent = parent
	end

	-- Ridge cap
	part({
		Name = "RidgeCap",
		Size = Vector3.new(34, 0.7, 1.2),
		Position = Vector3.new(0, ridgeY + 0.1, -40),
		Color = BEAM_COLOR,
		Material = Enum.Material.Wood,
	}).Parent = parent

	-- Gable triangles (east/west ends): two wedges per end.
	-- Slightly undersized so the sloped tops sit below the roof slabs' underside
	-- instead of sharing their plane (which z-fights).
	local gableRise = RISE - 0.6
	local gableDepth = HALF_DEPTH - 0.9
	for _, x in { -14.75, 14.75 } do
		for _, side in { 1, -1 } do
			local wedge = Instance.new("WedgePart")
			wedge.Anchored = true
			wedge.Size = Vector3.new(1, gableRise, gableDepth)
			-- Wedge slopes up toward its -Z; put the tall face at the ridge (z=-40)
			wedge.CFrame = CFrame.new(x, WALL_TOP + gableRise / 2, -40 + side * gableDepth / 2)
				* CFrame.Angles(0, if side == 1 then math.pi else 0, 0)
			wedge.Color = PLASTER_COLOR
			wedge.Material = Enum.Material.Plaster
			wedge.TopSurface = Enum.SurfaceType.Smooth
			wedge.BottomSurface = Enum.SurfaceType.Smooth
			wedge.Parent = parent
		end
	end
end

local function chimneyAndFireplace(parent: Instance)
	part({
		Name = "Chimney",
		Size = Vector3.new(3.5, 20, 3.5),
		Position = Vector3.new(8, 10, -53.8),
		Color = STONE_COLOR,
		Material = Enum.Material.Cobblestone,
	}).Parent = parent

	local smokePart = part({
		Name = "ChimneyTop",
		Size = Vector3.new(4.2, 1, 4.2),
		Position = Vector3.new(8, 20.5, -53.8),
		Color = STONE_COLOR,
		Material = Enum.Material.Slate,
	})
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Rate = 3
	smoke.Lifetime = NumberRange.new(3, 5)
	smoke.Speed = NumberRange.new(1.5, 2.5)
	smoke.SpreadAngle = Vector2.new(12, 12)
	smoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(1, 4),
	})
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Color = ColorSequence.new(Color3.fromRGB(200, 200, 200))
	smoke.Parent = smokePart
	smokePart.Parent = parent

	-- Fireplace inside against the north wall
	local hearthZ = -50.6
	part({ Name = "HearthBase", Size = Vector3.new(5, 0.4, 2.5), Position = Vector3.new(8, 1.2, hearthZ), Color = STONE_COLOR, Material = Enum.Material.Slate }).Parent = parent
	part({ Name = "HearthSideL", Size = Vector3.new(0.8, 4, 2), Position = Vector3.new(5.9, 3.4, hearthZ), Color = STONE_COLOR, Material = Enum.Material.Cobblestone }).Parent = parent
	part({ Name = "HearthSideR", Size = Vector3.new(0.8, 4, 2), Position = Vector3.new(10.1, 3.4, hearthZ), Color = STONE_COLOR, Material = Enum.Material.Cobblestone }).Parent = parent
	part({ Name = "HearthLintel", Size = Vector3.new(5, 0.9, 2), Position = Vector3.new(8, 5.85, hearthZ), Color = STONE_COLOR, Material = Enum.Material.Slate }).Parent = parent

	local firePart = part({
		Name = "FireLogs",
		Size = Vector3.new(2.4, 0.7, 1.4),
		Position = Vector3.new(8, 1.75, hearthZ),
		Color = Color3.fromRGB(60, 42, 30),
		Material = Enum.Material.Wood,
	})
	local fire = Instance.new("Fire")
	fire.Size = 4
	fire.Heat = 6
	fire.Parent = firePart
	local fireLight = Instance.new("PointLight")
	fireLight.Color = Color3.fromRGB(255, 160, 70)
	fireLight.Brightness = 1.6
	fireLight.Range = 14
	fireLight.Parent = firePart
	firePart.Parent = parent
end

local function doorway(parent: Instance)
	-- Frame around the 6-wide opening in the south wall
	local z = -28
	part({ Name = "DoorPostL", Size = Vector3.new(0.8, 8, 1.6), Position = Vector3.new(-3.4, 5, z), Color = BEAM_COLOR, Material = Enum.Material.Wood }).Parent = parent
	part({ Name = "DoorPostR", Size = Vector3.new(0.8, 8, 1.6), Position = Vector3.new(3.4, 5, z), Color = BEAM_COLOR, Material = Enum.Material.Wood }).Parent = parent
	part({ Name = "DoorLintel", Size = Vector3.new(7.6, 0.8, 1.6), Position = Vector3.new(0, 9.2, z), Color = BEAM_COLOR, Material = Enum.Material.Wood }).Parent = parent
	-- Stone doorstep
	part({ Name = "DoorStep", Size = Vector3.new(7, 0.5, 3), Position = Vector3.new(0, 0.25, z + 1.5), Color = STONE_COLOR, Material = Enum.Material.Slate }).Parent = parent

	-- Lantern beside the door
	local lamp = part({
		Name = "DoorLantern",
		Size = Vector3.new(0.8, 1.2, 0.8),
		Position = Vector3.new(4.6, 7.5, z + 0.9),
		Color = Color3.fromRGB(255, 214, 130),
		Material = Enum.Material.Neon,
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 200, 110)
	light.Brightness = 1.2
	light.Range = 12
	light.Parent = lamp
	lamp.Parent = parent
	part({ Name = "LanternBracket", Size = Vector3.new(0.3, 0.3, 1.6), Position = Vector3.new(4.6, 8.3, z + 0.5), Color = BEAM_COLOR, Material = Enum.Material.Metal }).Parent = parent
end

local function flowerBoxes(parent: Instance)
	local flowerColors = {
		Color3.fromRGB(232, 80, 90),
		Color3.fromRGB(250, 200, 70),
		Color3.fromRGB(190, 100, 220),
		Color3.fromRGB(250, 140, 60),
	}
	for _, x in { -9, 9 } do
		part({
			Name = "FlowerBox",
			Size = Vector3.new(4.6, 0.9, 1),
			Position = Vector3.new(x, 3.5, -27.2),
			Color = BEAM_COLOR,
			Material = Enum.Material.Wood,
		}).Parent = parent
		for i = 1, 5 do
			part({
				Name = "Flower",
				Size = Vector3.new(0.45, 0.45, 0.45),
				Position = Vector3.new(x - 1.8 + (i - 1) * 0.9, 4.15, -27.2),
				Color = flowerColors[(i % #flowerColors) + 1],
				Material = Enum.Material.Grass,
				CanCollide = false,
			}).Parent = parent
		end
	end
end

local function interior(parent: Instance)
	-- Kael's bed (name is load-bearing: referenced by spawn placement/story beats)
	local bed = part({
		Name = "KaelBed",
		Size = Vector3.new(4, 1.5, 8),
		Position = Vector3.new(-11, 1.75, -47),
		Color = Color3.fromRGB(140, 46, 46),
		Material = Enum.Material.Fabric,
	})
	bed.Parent = parent
	part({ Name = "BedFrame", Size = Vector3.new(4.6, 1, 8.6), Position = Vector3.new(-11, 1.3, -47), Color = BEAM_COLOR, Material = Enum.Material.Wood }).Parent = parent
	part({ Name = "BedPillow", Size = Vector3.new(3, 0.6, 1.8), Position = Vector3.new(-11, 2.7, -50), Color = Color3.fromRGB(235, 228, 210), Material = Enum.Material.Fabric }).Parent = parent

	-- Rug
	part({
		Name = "Rug",
		Size = Vector3.new(9, 0.12, 6.5),
		Position = Vector3.new(0, 1.17, -40),
		Color = Color3.fromRGB(120, 60, 50),
		Material = Enum.Material.Fabric,
		CanCollide = false,
	}).Parent = parent

	-- Table and stools (breakfast scene)
	part({ Name = "TableTop", Size = Vector3.new(6, 0.5, 3.5), Position = Vector3.new(4, 3.6, -44), Color = Color3.fromRGB(110, 78, 48), Material = Enum.Material.WoodPlanks }).Parent = parent
	for _, offset in { Vector3.new(-2.6, 0, -1.4), Vector3.new(2.6, 0, -1.4), Vector3.new(-2.6, 0, 1.4), Vector3.new(2.6, 0, 1.4) } do
		part({
			Name = "TableLeg",
			Size = Vector3.new(0.4, 2.4, 0.4),
			Position = Vector3.new(4, 2.2, -44) + offset,
			Color = BEAM_COLOR,
			Material = Enum.Material.Wood,
		}).Parent = parent
	end
	for _, x in { 1.5, 6.5 } do
		part({ Name = "Stool", Size = Vector3.new(1.4, 1.6, 1.4), Position = Vector3.new(x, 1.8, -41), Color = Color3.fromRGB(110, 78, 48), Material = Enum.Material.Wood }).Parent = parent
	end

	-- Shelf with clutter on the west wall
	part({ Name = "Shelf", Size = Vector3.new(0.8, 0.4, 6), Position = Vector3.new(-14.2, 6, -34), Color = BEAM_COLOR, Material = Enum.Material.Wood }).Parent = parent
	part({ Name = "ShelfPot", Size = Vector3.new(0.8, 1, 0.8), Position = Vector3.new(-14.2, 6.7, -36), Color = Color3.fromRGB(160, 110, 70), Material = Enum.Material.Slate }).Parent = parent
	part({ Name = "ShelfBook", Size = Vector3.new(0.7, 1, 1.6), Position = Vector3.new(-14.2, 6.7, -32.5), Color = Color3.fromRGB(70, 90, 130), Material = Enum.Material.Fabric }).Parent = parent

	-- Hanging lantern in the room center
	part({ Name = "LanternChain", Size = Vector3.new(0.2, 3, 0.2), Position = Vector3.new(0, 16, -40), Color = Color3.fromRGB(80, 80, 80), Material = Enum.Material.Metal, CanCollide = false }).Parent = parent
	local roomLamp = part({
		Name = "RoomLantern",
		Size = Vector3.new(1, 1.4, 1),
		Position = Vector3.new(0, 13.8, -40),
		Color = Color3.fromRGB(255, 214, 130),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	local roomLight = Instance.new("PointLight")
	roomLight.Color = Color3.fromRGB(255, 205, 120)
	roomLight.Brightness = 1.4
	roomLight.Range = 22
	roomLight.Parent = roomLamp
	roomLamp.Parent = parent
end

function CottageBuilder.build(parentFolder: Instance): Model
	local cottage = Instance.new("Model")
	cottage.Name = "RowanCottage"

	-- Stone foundation and plank floor
	part({
		Name = "Foundation",
		Size = Vector3.new(32, 1.2, 26),
		Position = Vector3.new(0, 0.4, -40),
		Color = STONE_COLOR,
		Material = Enum.Material.Cobblestone,
	}).Parent = cottage
	-- Floor top sits 0.1 proud of the foundation so the surfaces never share a plane
	part({
		Name = "Floor",
		Size = Vector3.new(30, 0.4, 24),
		Position = Vector3.new(0, 0.9, -40),
		Color = Color3.fromRGB(133, 100, 67),
		Material = Enum.Material.WoodPlanks,
	}).Parent = cottage

	-- Walls with real openings
	-- North wall: window at west half (chimney occupies east half outside)
	segmentedWall(cottage, Vector3.new(-15, 0, -52), Vector3.new(15, 0, -52), {
		{ center = 7, width = 4, y0 = 4, y1 = 7.5 },
	})
	windowFrame(cottage, Vector3.new(-8, 0, -52), 4, 4, 7.5, true)
	-- South wall: doorway + two windows
	segmentedWall(cottage, Vector3.new(-15, 0, -28), Vector3.new(15, 0, -28), {
		{ center = 15, width = 6, y0 = 1, y1 = 8.8 }, -- doorway (center of 30-long wall)
		{ center = 6, width = 4, y0 = 4, y1 = 7.5 }, -- window at x=-9
		{ center = 24, width = 4, y0 = 4, y1 = 7.5 }, -- window at x=9
	})
	windowFrame(cottage, Vector3.new(-9, 0, -28), 4, 4, 7.5, true)
	windowFrame(cottage, Vector3.new(9, 0, -28), 4, 4, 7.5, true)
	-- West wall: two windows
	segmentedWall(cottage, Vector3.new(-15, 0, -52), Vector3.new(-15, 0, -28), {
		{ center = 6, width = 4, y0 = 4, y1 = 7.5 }, -- z=-46
		{ center = 18, width = 4, y0 = 4, y1 = 7.5 }, -- z=-34
	})
	windowFrame(cottage, Vector3.new(-15, 0, -46), 4, 4, 7.5, false)
	windowFrame(cottage, Vector3.new(-15, 0, -34), 4, 4, 7.5, false)
	-- East wall: two windows
	segmentedWall(cottage, Vector3.new(15, 0, -52), Vector3.new(15, 0, -28), {
		{ center = 6, width = 4, y0 = 4, y1 = 7.5 },
		{ center = 18, width = 4, y0 = 4, y1 = 7.5 },
	})
	windowFrame(cottage, Vector3.new(15, 0, -46), 4, 4, 7.5, false)
	windowFrame(cottage, Vector3.new(15, 0, -34), 4, 4, 7.5, false)

	cornerPostsAndPlates(cottage)
	roof(cottage)
	chimneyAndFireplace(cottage)
	doorway(cottage)
	flowerBoxes(cottage)
	interior(cottage)

	cottage.Parent = parentFolder
	return cottage
end

return CottageBuilder
