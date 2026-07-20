--!strict
-- The Rowan family cottage: detailed timber-frame build with stone wainscot,
-- shuttered windows, door canopy, tapered chimney, and a fully furnished
-- interior (hearth kitchen, three beds' worth of family life, rafters, herbs).
-- Footprint: x -15..15, z -52..-28 (center 0,-40). Floor top y=1, walls to y=10.
--
-- Gameplay anchors that must survive any remodel:
--   * the part named "KaelBed" (story beats reference it)
--   * spawn stays clear at (-6, 1.5, -45)
--   * Mira stands at (6,-45), Daren at (10,-35)
--   * the doorway and the interior lane from the door to (-6,-40) stay clear —
--     the opening flyby flies through them
--
-- Z-fighting rules: no two surfaces ever share a plane. Exterior trim embeds
-- ~0.1 into the wall and stands proud of it; stacked parts always differ in
-- footprint or overlap in volume.

local PartUtil = require(script.Parent.PartUtil)
local part = PartUtil.part
local wedge = PartUtil.wedge

local WALL_BASE = 1
local WALL_TOP = 10
local WALL_THICKNESS = 1
local RISE = 8
local HALF_DEPTH = 12
local OVERHANG = 2

local PLASTER_COLOR = Color3.fromRGB(232, 224, 205)
local BEAM_COLOR = Color3.fromRGB(74, 52, 34)
local ROOF_COLOR = Color3.fromRGB(112, 66, 48)
local STONE_COLOR = Color3.fromRGB(130, 126, 120)
local SHUTTER_COLOR = Color3.fromRGB(70, 96, 76)
local DARK_WOOD = Color3.fromRGB(96, 62, 38)

local CottageBuilder = {}

type Opening = { center: number, width: number, y0: number, y1: number }

local function segmentedWall(
	parent: Instance,
	p1: Vector3,
	p2: Vector3,
	openings: { Opening },
	topY: number?
)
	local wallTop = topY or WALL_TOP
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
		panel(cursor, left, WALL_BASE, wallTop)
		panel(left, right, WALL_BASE, opening.y0)
		panel(left, right, opening.y1, wallTop)
		cursor = right
	end
	panel(cursor, length, WALL_BASE, wallTop)
end

local function windowFrame(parent: Instance, center: Vector3, width: number, y0: number, y1: number, alongX: boolean)
	local frameT = 0.5
	local inset = 0.2
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
		framePiece(Vector3.new(width + frameT * 2, frameT, depth), Vector3.new(center.X, y1 + frameT / 2 - inset, center.Z))
		framePiece(Vector3.new(width + frameT * 2, frameT, depth), Vector3.new(center.X, y0 - frameT / 2 + inset, center.Z))
		framePiece(Vector3.new(frameT, h, depth), Vector3.new(center.X - width / 2 - frameT / 2 + inset, cy, center.Z))
		framePiece(Vector3.new(frameT, h, depth), Vector3.new(center.X + width / 2 + frameT / 2 - inset, cy, center.Z))
		framePiece(Vector3.new(width, 0.24, 0.24), Vector3.new(center.X, cy, center.Z))
		framePiece(Vector3.new(0.24, h, 0.24), Vector3.new(center.X, cy, center.Z))
	else
		framePiece(Vector3.new(depth, frameT, width + frameT * 2), Vector3.new(center.X, y1 + frameT / 2 - inset, center.Z))
		framePiece(Vector3.new(depth, frameT, width + frameT * 2), Vector3.new(center.X, y0 - frameT / 2 + inset, center.Z))
		framePiece(Vector3.new(depth, h, frameT), Vector3.new(center.X, cy, center.Z - width / 2 - frameT / 2 + inset))
		framePiece(Vector3.new(depth, h, frameT), Vector3.new(center.X, cy, center.Z + width / 2 + frameT / 2 - inset))
		framePiece(Vector3.new(0.24, 0.24, width), Vector3.new(center.X, cy, center.Z))
		framePiece(Vector3.new(0.24, h, 0.24), Vector3.new(center.X, cy, center.Z))
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

-- Shutter pair flanking a window. `outward` is the wall's outward axis
-- direction (unit vector), used to place the shutters proud of the wall face.
local function shutters(parent: Instance, center: Vector3, y0: number, y1: number, alongX: boolean, outward: Vector3)
	local h = y1 - y0 + 0.4
	local cy = (y0 + y1) / 2
	-- back embeds 0.1 into the wall face, front stands proud
	local surfaceOffset = outward * (WALL_THICKNESS / 2 + 0.05)
	for _, side in { -3.2, 3.2 } do
		local pos = if alongX
			then Vector3.new(center.X + side, cy, center.Z) + surfaceOffset
			else Vector3.new(center.X, cy, center.Z + side) + surfaceOffset
		part({
			Name = "Shutter",
			Size = if alongX then Vector3.new(1.6, h, 0.3) else Vector3.new(0.3, h, 1.6),
			Position = pos,
			Color = SHUTTER_COLOR,
			Material = Enum.Material.Wood,
		}).Parent = parent
		-- cross brace detail
		part({
			Name = "ShutterBrace",
			Size = if alongX then Vector3.new(1.3, 0.35, 0.15) else Vector3.new(0.15, 0.35, 1.3),
			Position = pos + outward * 0.22,
			Color = DARK_WOOD,
			Material = Enum.Material.Wood,
		}).Parent = parent
	end
end

-- Stone wainscot band + vertical accent studs on an exterior face.
-- Segments listed as {fromOffset, toOffset} along the wall to avoid openings.
local function exteriorTrim(
	parent: Instance,
	p1: Vector3,
	p2: Vector3,
	outward: Vector3,
	wainscotSegments: { { number } },
	studOffsets: { number }
)
	local dir = (p2 - p1).Unit
	local alongX = math.abs(dir.X) > 0.5
	local surface = outward * (WALL_THICKNESS / 2 + 0.05)

	for _, seg in wainscotSegments do
		local fromOffset, toOffset = seg[1], seg[2]
		local segLength = toOffset - fromOffset
		if segLength <= 0.1 then
			continue
		end
		local mid = p1 + dir * ((fromOffset + toOffset) / 2) + surface
		part({
			Name = "Wainscot",
			Size = if alongX then Vector3.new(segLength, 1.4, 0.5) else Vector3.new(0.5, 1.4, segLength),
			Position = Vector3.new(mid.X, 1.7, mid.Z),
			Color = STONE_COLOR,
			Material = Enum.Material.Cobblestone,
		}).Parent = parent
	end

	for _, offset in studOffsets do
		local pos = p1 + dir * offset + surface
		part({
			Name = "WallStud",
			Size = if alongX then Vector3.new(0.6, 8.2, 0.45) else Vector3.new(0.45, 8.2, 0.6),
			Position = Vector3.new(pos.X, 5.3, pos.Z),
			Color = BEAM_COLOR,
			Material = Enum.Material.Wood,
		}).Parent = parent
	end
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
			Size = Vector3.new(1.4, 9, 1.4),
			Position = Vector3.new(corner.X, WALL_BASE + 4.5 - 0.2, corner.Z),
			Color = BEAM_COLOR,
			Material = Enum.Material.Wood,
		}).Parent = parent
	end
	part({ Name = "EavePlate", Size = Vector3.new(31, 1, 1.4), Position = Vector3.new(0, 9.8, -52), Color = BEAM_COLOR, Material = Enum.Material.Wood }).Parent = parent
	part({ Name = "EavePlate", Size = Vector3.new(31, 1, 1.4), Position = Vector3.new(0, 9.8, -28), Color = BEAM_COLOR, Material = Enum.Material.Wood }).Parent = parent
	part({ Name = "Beam", Size = Vector3.new(1.4, 0.6, 25), Position = Vector3.new(-15, WALL_TOP - 0.3, -40), Color = BEAM_COLOR, Material = Enum.Material.Wood }).Parent = parent
	part({ Name = "Beam", Size = Vector3.new(1.4, 0.6, 25), Position = Vector3.new(15, WALL_TOP - 0.3, -40), Color = BEAM_COLOR, Material = Enum.Material.Wood }).Parent = parent

	-- Rafter tails peeking out under the eaves (skip the doorway canopy zone)
	for _, z in { -52, -28 } do
		local outwardZ = if z == -52 then -1 else 1
		for x = -13.5, 13.5, 3 do
			if z == -28 and math.abs(x) < 4.5 then
				continue
			end
			part({
				Name = "RafterTail",
				Size = Vector3.new(0.5, 0.5, 1.8),
				Position = Vector3.new(x, 9.0, z + outwardZ * 0.9),
				Color = BEAM_COLOR,
				Material = Enum.Material.Wood,
			}).Parent = parent
		end
	end
end

local function roof(parent: Instance)
	local angle = math.atan(RISE / HALF_DEPTH)
	local run = HALF_DEPTH + OVERHANG
	local drop = math.tan(angle) * run
	local slabLength = math.sqrt(run * run + drop * drop)
	local ridgeY = WALL_TOP + RISE + 0.6
	local eaveY = ridgeY - drop

	for _, side in { 1, -1 } do
		local centerZ = -40 + side * run / 2
		local centerY = (ridgeY + eaveY) / 2
		part({
			Name = "RoofSlab",
			Size = Vector3.new(34, 0.5, slabLength),
			CFrame = CFrame.new(0, centerY, centerZ) * CFrame.Angles(side * angle, 0, 0),
			Color = ROOF_COLOR,
			Material = Enum.Material.RoofShingles,
		}).Parent = parent
		-- A second, slightly smaller layer floating just above gives the roof
		-- visual depth (reads as overlapping shingle courses)
		part({
			Name = "RoofSlabDetail",
			Size = Vector3.new(30, 0.3, slabLength * 0.62),
			CFrame = CFrame.new(0, centerY, centerZ)
				* CFrame.Angles(side * angle, 0, 0)
				* CFrame.new(0, 0.3, -side * slabLength * 0.16),
			Color = Color3.fromRGB(100, 58, 42),
			Material = Enum.Material.RoofShingles,
		}).Parent = parent
	end

	part({
		Name = "RidgeCap",
		Size = Vector3.new(34, 0.7, 1.2),
		Position = Vector3.new(0, ridgeY + 0.35, -40),
		Color = BEAM_COLOR,
		Material = Enum.Material.Wood,
	}).Parent = parent
	-- Ridge finials at the gable ends
	for _, x in { -16.6, 16.6 } do
		part({
			Name = "RidgeFinial",
			Size = Vector3.new(0.7, 1.8, 0.7),
			Position = Vector3.new(x, ridgeY + 0.9, -40),
			Color = DARK_WOOD,
			Material = Enum.Material.Wood,
		}).Parent = parent
	end

	local gableRise = RISE
	local gableDepth = HALF_DEPTH - 0.7
	for _, x in { -14.75, 14.75 } do
		for _, side in { 1, -1 } do
			wedge({
				Name = "Gable",
				Size = Vector3.new(1, gableRise, gableDepth),
				CFrame = CFrame.new(x, WALL_TOP + gableRise / 2, -40 + side * gableDepth / 2)
					* CFrame.Angles(0, if side == 1 then math.pi else 0, 0),
				Color = PLASTER_COLOR,
				Material = Enum.Material.Plaster,
			}).Parent = parent
		end
	end
end

local function chimneyAndFireplace(parent: Instance)
	-- Tapered chimney: three embedded stacked sections + cap
	part({ Name = "ChimneyBase", Size = Vector3.new(4.6, 8, 4.6), Position = Vector3.new(8, 4, -53.9), Color = STONE_COLOR, Material = Enum.Material.Cobblestone }).Parent = parent
	part({ Name = "ChimneyMid", Size = Vector3.new(3.8, 7, 3.8), Position = Vector3.new(8, 11.4, -53.9), Color = STONE_COLOR, Material = Enum.Material.Cobblestone }).Parent = parent
	part({ Name = "ChimneyTop", Size = Vector3.new(3.2, 6.2, 3.2), Position = Vector3.new(8, 17.9, -53.9), Color = STONE_COLOR, Material = Enum.Material.Cobblestone }).Parent = parent
	local cap = part({
		Name = "ChimneyCap",
		Size = Vector3.new(4.4, 0.8, 4.4),
		Position = Vector3.new(8, 21.4, -53.9),
		Color = Color3.fromRGB(110, 106, 100),
		Material = Enum.Material.Slate,
	})
	-- Warm ember glow just inside the flue
	local ember = part({
		Name = "ChimneyEmber",
		Size = Vector3.new(2.2, 0.4, 2.2),
		Position = Vector3.new(8, 20.85, -53.9),
		Color = Color3.fromRGB(255, 130, 50),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	local emberLight = Instance.new("PointLight")
	emberLight.Color = Color3.fromRGB(255, 150, 70)
	emberLight.Brightness = 0.8
	emberLight.Range = 8
	emberLight.Parent = ember
	ember.Parent = parent

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
	smoke.Parent = cap
	cap.Parent = parent

	-- Fireplace inside against the north wall
	local hearthZ = -50.6
	part({ Name = "HearthBase", Size = Vector3.new(5, 0.4, 2.5), Position = Vector3.new(8, 1.2, hearthZ), Color = STONE_COLOR, Material = Enum.Material.Slate }).Parent = parent
	part({ Name = "HearthApron", Size = Vector3.new(4.2, 0.16, 1.6), Position = Vector3.new(8, 1.18, -48.6), Color = Color3.fromRGB(110, 106, 100), Material = Enum.Material.Slate }).Parent = parent
	part({ Name = "HearthSideL", Size = Vector3.new(0.8, 4, 2), Position = Vector3.new(5.9, 3.4, hearthZ), Color = STONE_COLOR, Material = Enum.Material.Cobblestone }).Parent = parent
	part({ Name = "HearthSideR", Size = Vector3.new(0.8, 4, 2), Position = Vector3.new(10.1, 3.4, hearthZ), Color = STONE_COLOR, Material = Enum.Material.Cobblestone }).Parent = parent
	part({ Name = "HearthLintel", Size = Vector3.new(5, 0.9, 2), Position = Vector3.new(8, 5.85, hearthZ), Color = STONE_COLOR, Material = Enum.Material.Slate }).Parent = parent
	-- Mantel shelf with candlesticks
	part({ Name = "MantelShelf", Size = Vector3.new(5.6, 0.4, 1.2), Position = Vector3.new(8, 6.5, -50.2), Color = DARK_WOOD, Material = Enum.Material.Wood }).Parent = parent
	for _, x in { 6.2, 9.8 } do
		part({ Name = "Candlestick", Size = Vector3.new(0.25, 0.7, 0.25), Position = Vector3.new(x, 7.05, -50.2), Color = Color3.fromRGB(200, 170, 90), Material = Enum.Material.Metal, CanCollide = false }).Parent = parent
		local flame = part({
			Name = "CandleFlame",
			Size = Vector3.new(0.18, 0.3, 0.18),
			Position = Vector3.new(x, 7.55, -50.2),
			Color = Color3.fromRGB(255, 200, 90),
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		local candleLight = Instance.new("PointLight")
		candleLight.Color = Color3.fromRGB(255, 200, 110)
		candleLight.Brightness = 0.5
		candleLight.Range = 7
		candleLight.Parent = flame
		flame.Parent = parent
	end

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

	-- Firewood stack beside the hearth
	for i = 0, 3 do
		part({
			Name = "Firewood",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.6, 0.55, 0.55),
			CFrame = CFrame.new(11.4, 1.5 + math.floor(i / 2) * 0.55, -50.4 + (i % 2) * 0.6) * CFrame.Angles(0, 0, 0),
			Color = Color3.fromRGB(104, 74, 48),
			Material = Enum.Material.Wood,
		}).Parent = parent
	end
end

local function doorway(parent: Instance)
	local z = -28
	part({ Name = "DoorPostL", Size = Vector3.new(0.8, 8, 1.6), Position = Vector3.new(-3.2, 5, z), Color = BEAM_COLOR, Material = Enum.Material.Wood }).Parent = parent
	part({ Name = "DoorPostR", Size = Vector3.new(0.8, 8, 1.6), Position = Vector3.new(3.2, 5, z), Color = BEAM_COLOR, Material = Enum.Material.Wood }).Parent = parent
	part({ Name = "DoorLintel", Size = Vector3.new(7.6, 0.8, 1.6), Position = Vector3.new(0, 9.0, z), Color = BEAM_COLOR, Material = Enum.Material.Wood }).Parent = parent
	part({ Name = "DoorStep", Size = Vector3.new(7, 0.5, 3), Position = Vector3.new(0, 0.25, z + 1.5), Color = STONE_COLOR, Material = Enum.Material.Slate }).Parent = parent

	-- The door itself, swung open inward against the east side of the opening
	local doorCF = CFrame.new(6.2, 4.2, -28.9) * CFrame.Angles(0, math.rad(4), 0)
	part({
		Name = "OpenDoor",
		Size = Vector3.new(5.4, 7.4, 0.3),
		CFrame = doorCF,
		Color = DARK_WOOD,
		Material = Enum.Material.WoodPlanks,
		CanCollide = false,
	}).Parent = parent
	for _, y in { 6.6, 4.2, 1.9 } do
		part({
			Name = "DoorBand",
			Size = Vector3.new(5.0, 0.4, 0.14),
			CFrame = doorCF * CFrame.new(0, y - 4.2, -0.2),
			Color = Color3.fromRGB(60, 58, 55),
			Material = Enum.Material.Metal,
			CanCollide = false,
		}).Parent = parent
	end
	part({
		Name = "DoorHandle",
		Size = Vector3.new(0.28, 0.7, 0.28),
		CFrame = doorCF * CFrame.new(2.2, 0, -0.26),
		Color = Color3.fromRGB(200, 170, 90),
		Material = Enum.Material.Metal,
		CanCollide = false,
	}).Parent = parent

	-- Gabled canopy over the door on angled brackets
	part({
		Name = "DoorCanopy",
		Size = Vector3.new(7.5, 0.3, 3.4),
		CFrame = CFrame.new(0, 9.9, -26.3) * CFrame.Angles(math.rad(25), 0, 0),
		Color = ROOF_COLOR,
		Material = Enum.Material.RoofShingles,
	}).Parent = parent
	for _, x in { -3.2, 3.2 } do
		part({
			Name = "CanopyBracket",
			Size = Vector3.new(0.4, 0.4, 3.4),
			CFrame = CFrame.new(x, 9.05, -27.05) * CFrame.Angles(math.rad(-40), 0, 0),
			Color = BEAM_COLOR,
			Material = Enum.Material.Wood,
		}).Parent = parent
	end

	-- Name board, hung under the door canopy. There is no legal wall space above
	-- the door — the lintel tops out at y 9.4 and the canopy underside is
	-- already at 9.18 there — so mounting it flat put the board through the
	-- canopy, the eave plate and the roof slab at once. Hanging it from the
	-- canopy's outer half clears all three.
	local cottageSign = part({
		Name = "DoorSign",
		Size = Vector3.new(7, 1.6, 0.4),
		Position = Vector3.new(0, 7.7, -25.2),
		Color = Color3.fromRGB(112, 82, 52),
		Material = Enum.Material.WoodPlanks,
	})
	local signSurface = Instance.new("SurfaceGui")
	-- outward is +Z here (the door step sits at z + 1.5), so the readable face
	-- is Back. Front pointed the canvas into the cottage, which is why the
	-- lettering washed out as you got close to it.
	signSurface.Face = Enum.NormalId.Back
	signSurface.CanvasSize = Vector2.new(420, 96)
	signSurface.Parent = cottageSign
	local signText = Instance.new("TextLabel")
	signText.Size = UDim2.fromScale(0.94, 0.8)
	signText.Position = UDim2.fromScale(0.03, 0.1)
	signText.BackgroundTransparency = 1
	signText.Text = "Rowan Cottage"
	signText.Font = Enum.Font.Merriweather
	signText.TextScaled = true
	signText.TextColor3 = Color3.fromRGB(240, 228, 200)
	signText.TextStrokeColor3 = Color3.fromRGB(48, 34, 20)
	signText.TextStrokeTransparency = 0.4
	signText.Parent = signSurface
	cottageSign.Parent = parent

	-- chains up to the canopy underside (y 9.23 at this depth)
	for _, x in { -2.6, 2.6 } do
		part({
			Name = "SignChain",
			Size = Vector3.new(0.16, 1.0, 0.16),
			Position = Vector3.new(x, 8.9, -25.2),
			Color = Color3.fromRGB(60, 58, 55),
			Material = Enum.Material.Metal,
			CanCollide = false,
		}).Parent = parent
	end

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

local function yard(parent: Instance)
	-- Bench to the right of the door
	part({ Name = "BenchSeat", Size = Vector3.new(4, 0.4, 1.3), Position = Vector3.new(8, 1.7, -26.6), Color = DARK_WOOD, Material = Enum.Material.WoodPlanks }).Parent = parent
	for _, x in { 6.6, 9.4 } do
		part({ Name = "BenchLeg", Size = Vector3.new(0.4, 1.5, 1.1), Position = Vector3.new(x, 0.75, -26.6), Color = BEAM_COLOR, Material = Enum.Material.Wood }).Parent = parent
	end
	part({ Name = "BenchBack", Size = Vector3.new(4, 1.0, 0.3), Position = Vector3.new(8, 2.5, -27.05), Color = DARK_WOOD, Material = Enum.Material.WoodPlanks }).Parent = parent

	-- Rain barrel left of the door
	part({
		Name = "RainBarrel",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.6, 2.2, 2.2),
		CFrame = CFrame.new(-5.5, 1.3, -26.6) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(110, 78, 48),
		Material = Enum.Material.WoodPlanks,
	}).Parent = parent
	part({
		Name = "BarrelWater",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 1.9, 1.9),
		CFrame = CFrame.new(-5.5, 2.5, -26.6) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(60, 90, 110),
		Material = Enum.Material.Glass,
		Transparency = 0.25,
		CanCollide = false,
	}).Parent = parent

	-- Woodpile along the front wall, east end
	for i = 0, 5 do
		part({
			Name = "YardLog",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(2.2, 0.6, 0.6),
			CFrame = CFrame.new(13, 0.6 + math.floor(i / 3) * 0.6, -26.9 + (i % 3) * 0.65)
				* CFrame.Angles(0, math.rad(90), 0),
			Color = Color3.fromRGB(104, 74, 48),
			Material = Enum.Material.Wood,
		}).Parent = parent
	end

	-- Lamp post where the cottage path meets the yard
	part({ Name = "LampPost", Size = Vector3.new(0.45, 5.6, 0.45), Position = Vector3.new(5.5, 2.8, -23.5), Color = BEAM_COLOR, Material = Enum.Material.Wood }).Parent = parent
	local postLamp = part({
		Name = "LampPostLight",
		Size = Vector3.new(0.9, 1.1, 0.9),
		Position = Vector3.new(5.5, 6, -23.5),
		Color = Color3.fromRGB(255, 214, 130),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	local postLight = Instance.new("PointLight")
	postLight.Color = Color3.fromRGB(255, 200, 110)
	postLight.Brightness = 1
	postLight.Range = 14
	postLight.Parent = postLamp
	postLamp.Parent = parent
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
	-- Ceiling rafters spanning the room
	for _, z in { -50, -44, -38, -32 } do
		part({
			Name = "Rafter",
			Size = Vector3.new(29, 0.5, 0.8),
			Position = Vector3.new(0, 10.15, z),
			Color = BEAM_COLOR,
			Material = Enum.Material.Wood,
			CanCollide = false,
		}).Parent = parent
	end
	-- Herb bundles hanging over the kitchen end
	for i = 0, 2 do
		local x = 8.5 + (i % 2) * 2.4
		local z = -44 + (i - 1) * 0.3
		part({ Name = "HerbString", Size = Vector3.new(0.12, 1.2, 0.12), Position = Vector3.new(x, 9.5, z), Color = Color3.fromRGB(180, 160, 120), Material = Enum.Material.Fabric, CanCollide = false }).Parent = parent
		part({
			Name = "HerbBundle",
			Size = Vector3.new(0.7, 1.1, 0.7),
			Position = Vector3.new(x, 8.4, z),
			Color = Color3.fromRGB(96, 128, 70),
			Material = Enum.Material.Grass,
			CanCollide = false,
		}).Parent = parent
	end

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
	part({ Name = "BedBlanket", Size = Vector3.new(4.1, 0.25, 4.4), Position = Vector3.new(-11, 2.58, -44.9), Color = Color3.fromRGB(90, 110, 150), Material = Enum.Material.Fabric, CanCollide = false }).Parent = parent
	-- Storage chest at the foot of the bed
	part({ Name = "BedChest", Size = Vector3.new(2.6, 1.5, 1.4), Position = Vector3.new(-11, 1.85, -41.0), Color = DARK_WOOD, Material = Enum.Material.WoodPlanks }).Parent = parent
	part({ Name = "BedChestLid", Size = Vector3.new(2.7, 0.35, 1.5), Position = Vector3.new(-11, 2.72, -41.0), Color = BEAM_COLOR, Material = Enum.Material.Wood }).Parent = parent
	part({ Name = "BedChestLatch", Size = Vector3.new(0.35, 0.5, 0.14), Position = Vector3.new(-11, 2.2, -40.25), Color = Color3.fromRGB(200, 170, 90), Material = Enum.Material.Metal, CanCollide = false }).Parent = parent

	-- Parents' bed, southwest corner
	part({ Name = "ParentsBedFrame", Size = Vector3.new(5.6, 1, 8.2), Position = Vector3.new(-11.5, 1.3, -31.5), Color = BEAM_COLOR, Material = Enum.Material.Wood }).Parent = parent
	part({ Name = "ParentsBed", Size = Vector3.new(5, 1.5, 7.6), Position = Vector3.new(-11.5, 1.75, -31.5), Color = Color3.fromRGB(120, 96, 70), Material = Enum.Material.Fabric }).Parent = parent
	part({ Name = "ParentsPillowL", Size = Vector3.new(2, 0.6, 1.6), Position = Vector3.new(-12.6, 2.7, -28.7), Color = Color3.fromRGB(235, 228, 210), Material = Enum.Material.Fabric }).Parent = parent
	part({ Name = "ParentsPillowR", Size = Vector3.new(2, 0.6, 1.6), Position = Vector3.new(-10.4, 2.7, -28.7), Color = Color3.fromRGB(235, 228, 210), Material = Enum.Material.Fabric }).Parent = parent
	part({ Name = "ParentsBlanket", Size = Vector3.new(5.1, 0.25, 4.2), Position = Vector3.new(-11.5, 2.58, -33.3), Color = Color3.fromRGB(130, 90, 90), Material = Enum.Material.Fabric, CanCollide = false }).Parent = parent

	-- Wardrobe on the west wall between the windows
	part({ Name = "Wardrobe", Size = Vector3.new(1.8, 6.5, 3.6), Position = Vector3.new(-13.4, 4.25, -36.5), Color = DARK_WOOD, Material = Enum.Material.WoodPlanks }).Parent = parent
	part({ Name = "WardrobeDoorSeam", Size = Vector3.new(0.12, 5.8, 0.16), Position = Vector3.new(-12.44, 4.1, -36.5), Color = Color3.fromRGB(50, 34, 22), Material = Enum.Material.Wood, CanCollide = false }).Parent = parent
	for _, z in { -37.3, -35.7 } do
		part({ Name = "WardrobeKnob", Size = Vector3.new(0.18, 0.18, 0.18), Position = Vector3.new(-12.4, 4.1, z), Color = Color3.fromRGB(200, 170, 90), Material = Enum.Material.Metal, CanCollide = false }).Parent = parent
	end

	-- Rug
	part({
		Name = "Rug",
		Size = Vector3.new(9, 0.12, 6.5),
		Position = Vector3.new(0, 1.17, -40),
		Color = Color3.fromRGB(120, 60, 50),
		Material = Enum.Material.Fabric,
		CanCollide = false,
	}).Parent = parent
	part({
		Name = "RugBorder",
		Size = Vector3.new(9.6, 0.08, 7.1),
		Position = Vector3.new(0, 1.14, -40),
		Color = Color3.fromRGB(180, 150, 90),
		Material = Enum.Material.Fabric,
		CanCollide = false,
	}).Parent = parent

	-- Breakfast table and stools
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
	-- Table setting: candle, bowl, bread
	part({ Name = "TableCandle", Size = Vector3.new(0.3, 0.8, 0.3), Position = Vector3.new(4.8, 4.25, -44.5), Color = Color3.fromRGB(230, 220, 200), Material = Enum.Material.SmoothPlastic, CanCollide = false }).Parent = parent
	local tableFlame = part({
		Name = "TableFlame",
		Size = Vector3.new(0.2, 0.32, 0.2),
		Position = Vector3.new(4.8, 4.8, -44.5),
		Color = Color3.fromRGB(255, 200, 90),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	local tableLight = Instance.new("PointLight")
	tableLight.Color = Color3.fromRGB(255, 200, 110)
	tableLight.Brightness = 0.6
	tableLight.Range = 8
	tableLight.Parent = tableFlame
	tableFlame.Parent = parent
	part({ Name = "TableBowl", Size = Vector3.new(1, 0.35, 1), Position = Vector3.new(3, 4, -43.6), Color = Color3.fromRGB(150, 120, 90), Material = Enum.Material.SmoothPlastic, CanCollide = false }).Parent = parent
	part({ Name = "TableBread", Size = Vector3.new(1.3, 0.5, 0.7), Position = Vector3.new(4.4, 4.1, -43.2), Color = Color3.fromRGB(196, 150, 90), Material = Enum.Material.Sand, CanCollide = false }).Parent = parent

	-- Kitchen counter along the east wall (below the windows)
	part({ Name = "CounterTop", Size = Vector3.new(1.9, 0.4, 9.6), Position = Vector3.new(13.3, 3.1, -41), Color = Color3.fromRGB(110, 78, 48), Material = Enum.Material.WoodPlanks }).Parent = parent
	part({ Name = "CounterBase", Size = Vector3.new(1.7, 2, 9.2), Position = Vector3.new(13.3, 1.9, -41), Color = DARK_WOOD, Material = Enum.Material.Wood }).Parent = parent
	part({ Name = "CounterPot", Size = Vector3.new(1.1, 0.9, 1.1), Position = Vector3.new(13.3, 3.75, -44), Color = Color3.fromRGB(80, 80, 85), Material = Enum.Material.Metal, CanCollide = false }).Parent = parent
	part({ Name = "CounterJug", Size = Vector3.new(0.7, 1.1, 0.7), Position = Vector3.new(13.3, 3.85, -38.5), Color = Color3.fromRGB(160, 110, 70), Material = Enum.Material.SmoothPlastic, CanCollide = false }).Parent = parent
	-- Shelf above the counter with jars
	part({ Name = "KitchenShelf", Size = Vector3.new(1, 0.35, 6), Position = Vector3.new(14.1, 6.2, -41), Color = BEAM_COLOR, Material = Enum.Material.Wood }).Parent = parent
	local jarColors = { Color3.fromRGB(150, 170, 110), Color3.fromRGB(190, 140, 90), Color3.fromRGB(120, 130, 160) }
	for i = 1, 3 do
		part({
			Name = "ShelfJar",
			Size = Vector3.new(0.6, 0.9, 0.6),
			Position = Vector3.new(14.1, 6.85, -43.2 + i * 1.5),
			Color = jarColors[i],
			Material = Enum.Material.Glass,
			Transparency = 0.15,
			CanCollide = false,
		}).Parent = parent
	end

	-- Shelf with clutter on the west wall (above the wardrobe height, south end)
	part({ Name = "Shelf", Size = Vector3.new(0.8, 0.4, 6), Position = Vector3.new(-14.2, 8.3, -34), Color = BEAM_COLOR, Material = Enum.Material.Wood }).Parent = parent
	part({ Name = "ShelfPot", Size = Vector3.new(0.8, 1, 0.8), Position = Vector3.new(-14.2, 9.0, -36), Color = Color3.fromRGB(160, 110, 70), Material = Enum.Material.Slate, CanCollide = false }).Parent = parent
	part({ Name = "ShelfBook", Size = Vector3.new(0.7, 1, 1.6), Position = Vector3.new(-14.2, 9.0, -32.5), Color = Color3.fromRGB(70, 90, 130), Material = Enum.Material.Fabric, CanCollide = false }).Parent = parent

	-- Hanging lantern in the room center
	part({ Name = "LanternChain", Size = Vector3.new(0.2, 4.6, 0.2), Position = Vector3.new(0, 16.5, -40), Color = Color3.fromRGB(80, 80, 80), Material = Enum.Material.Metal, CanCollide = false }).Parent = parent
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

	part({
		Name = "Foundation",
		Size = Vector3.new(32, 1.2, 26),
		Position = Vector3.new(0, 0.4, -40),
		Color = STONE_COLOR,
		Material = Enum.Material.Cobblestone,
	}).Parent = cottage
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
	}, 9.5)
	windowFrame(cottage, Vector3.new(-8, 0, -52), 4, 4, 7.5, true)
	shutters(cottage, Vector3.new(-8, 0, -52), 4, 7.5, true, Vector3.new(0, 0, -1))
	-- South wall: doorway + two windows
	segmentedWall(cottage, Vector3.new(-15, 0, -28), Vector3.new(15, 0, -28), {
		{ center = 15, width = 6, y0 = 1, y1 = 8.8 },
		{ center = 6, width = 4, y0 = 4, y1 = 7.5 },
		{ center = 24, width = 4, y0 = 4, y1 = 7.5 },
	}, 9.5)
	windowFrame(cottage, Vector3.new(-9, 0, -28), 4, 4, 7.5, true)
	windowFrame(cottage, Vector3.new(9, 0, -28), 4, 4, 7.5, true)
	shutters(cottage, Vector3.new(-9, 0, -28), 4, 7.5, true, Vector3.new(0, 0, 1))
	shutters(cottage, Vector3.new(9, 0, -28), 4, 7.5, true, Vector3.new(0, 0, 1))
	-- West wall: two windows
	segmentedWall(cottage, Vector3.new(-15, 0, -52), Vector3.new(-15, 0, -28), {
		{ center = 6, width = 4, y0 = 4, y1 = 7.5 },
		{ center = 18, width = 4, y0 = 4, y1 = 7.5 },
	})
	windowFrame(cottage, Vector3.new(-15, 0, -46), 4, 4, 7.5, false)
	windowFrame(cottage, Vector3.new(-15, 0, -34), 4, 4, 7.5, false)
	shutters(cottage, Vector3.new(-15, 0, -46), 4, 7.5, false, Vector3.new(-1, 0, 0))
	shutters(cottage, Vector3.new(-15, 0, -34), 4, 7.5, false, Vector3.new(-1, 0, 0))
	-- East wall: two windows
	segmentedWall(cottage, Vector3.new(15, 0, -52), Vector3.new(15, 0, -28), {
		{ center = 6, width = 4, y0 = 4, y1 = 7.5 },
		{ center = 18, width = 4, y0 = 4, y1 = 7.5 },
	})
	windowFrame(cottage, Vector3.new(15, 0, -46), 4, 4, 7.5, false)
	windowFrame(cottage, Vector3.new(15, 0, -34), 4, 4, 7.5, false)
	shutters(cottage, Vector3.new(15, 0, -46), 4, 7.5, false, Vector3.new(1, 0, 0))
	shutters(cottage, Vector3.new(15, 0, -34), 4, 7.5, false, Vector3.new(1, 0, 0))

	-- Exterior trim: stone wainscot + studs, per face, avoiding openings.
	-- South face (door x offsets 12..18, windows 4..8 and 22..26; shutters to +-3.2 beyond)
	exteriorTrim(cottage, Vector3.new(-15, 0, -28), Vector3.new(15, 0, -28), Vector3.new(0, 0, 1), {
		{ 0.5, 11.3 },
		{ 18.7, 29.5 },
	}, { 10.2, 19.8 })
	-- North face (window 5..9, chimney x 6.25..9.75 -> offsets 21.25..24.75)
	exteriorTrim(cottage, Vector3.new(-15, 0, -52), Vector3.new(15, 0, -52), Vector3.new(0, 0, -1), {
		{ 0.5, 20.9 },
		{ 25.1, 29.5 },
	}, { 12, 18, 26.5 })
	-- West face (windows at offsets 4..8 and 16..20)
	exteriorTrim(cottage, Vector3.new(-15, 0, -52), Vector3.new(-15, 0, -28), Vector3.new(-1, 0, 0), {
		{ 0.5, 23.5 },
	}, { 12 })
	-- East face
	exteriorTrim(cottage, Vector3.new(15, 0, -52), Vector3.new(15, 0, -28), Vector3.new(1, 0, 0), {
		{ 0.5, 23.5 },
	}, { 12 })

	cornerPostsAndPlates(cottage)
	roof(cottage)
	chimneyAndFireplace(cottage)
	doorway(cottage)
	yard(cottage)
	flowerBoxes(cottage)
	interior(cottage)

	cottage.Parent = parentFolder
	return cottage
end

return CottageBuilder
