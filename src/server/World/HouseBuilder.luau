--!strict
-- Parametric timber-frame house generator with REAL interiors.
--   * 9-foot ceilings: default story height is 10 studs
--   * stepped staircases (solid risers, railings) connect stories through
--     stairwell openings in the floor plates
--   * upper floors are a hallway + separate bedrooms behind framed doorways,
--     each bedroom furnished from a different variant
--   * front doors are open — every building can be walked into
--
-- Houses build in local coordinates (centered on origin, door facing local +Z,
-- ground at y=0) then pivot to their world position/rotation.
--
-- Z-fighting rules baked in: no two surfaces ever share a plane; frame/trim
-- pieces overlap INTO openings so cut faces are buried; eave-side walls stop
-- below the roof slope; nothing floats — furniture sits on floors, wall
-- fixtures embed into walls, hanging lights connect to the ceiling.

local PartUtil = require(script.Parent.PartUtil)
local part = PartUtil.part
local wedge = PartUtil.wedge

export type HouseConfig = {
	name: string?,
	position: Vector3,
	rotation: number?,
	width: number, -- facade length (local X); >= 18 recommended for interiors
	depth: number, -- local Z; >= 15 required for stairs
	stories: number,
	storyHeight: number?,
	plasterColor: Color3?,
	beamColor: Color3?,
	roofColor: Color3?,
	stoneGround: boolean?,
	doorWidth: number?,
	doorHeight: number?,
	interior: ("home" | "storage" | "shop" | "none")?,
	workshop: string?, -- "warehouse" | "tannery" | "lumber" | "mason" dressing for a storage interior
	signText: string?, -- identifier sign above the front door
	signMajor: boolean?, -- larger board + perpendicular hanging sign (named venues)
	shopWares: string?, -- what a "shop" interior sells (CarryItems kind for browsers)
	seed: number?,
}

local DEFAULT_PLASTER = Color3.fromRGB(232, 224, 205)
local DEFAULT_BEAM = Color3.fromRGB(74, 52, 34)
local DEFAULT_ROOF = Color3.fromRGB(112, 66, 48)
local STONE_COLOR = Color3.fromRGB(130, 126, 120)
local DARK_WOOD = Color3.fromRGB(96, 62, 38)
local FLOOR_WOOD = Color3.fromRGB(133, 100, 67)
local PARTITION_COLOR = Color3.fromRGB(222, 212, 190)
local WALL_T = 1
local STORY_H = 14 -- grand ceilings: interiors ~2.5x character height

local BLANKET_COLORS = {
	Color3.fromRGB(90, 110, 150),
	Color3.fromRGB(130, 90, 90),
	Color3.fromRGB(96, 128, 88),
	Color3.fromRGB(150, 120, 80),
}
local RUG_COLORS = {
	Color3.fromRGB(120, 60, 50),
	Color3.fromRGB(80, 95, 120),
	Color3.fromRGB(110, 90, 60),
}

local HouseBuilder = {}

type Opening = { center: number, width: number, y0: number, y1: number }

local function segmentedWall(
	parent: Instance,
	p1: Vector3,
	p2: Vector3,
	baseY: number,
	topY: number,
	openings: { Opening },
	color: Color3,
	material: Enum.Material
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
		part({
			Name = "WallPanel",
			Size = if alongX
				then Vector3.new(segLength, y1 - y0, WALL_T)
				else Vector3.new(WALL_T, y1 - y0, segLength),
			Position = Vector3.new(mid.X, (y0 + y1) / 2, mid.Z),
			Color = color,
			Material = material,
		}).Parent = parent
	end

	table.sort(openings, function(a, b)
		return a.center < b.center
	end)

	local cursor = 0
	for _, opening in openings do
		local left = opening.center - opening.width / 2
		local right = opening.center + opening.width / 2
		panel(cursor, left, baseY, topY)
		panel(left, right, baseY, opening.y0)
		panel(left, right, opening.y1, topY)
		cursor = right
	end
	panel(cursor, length, baseY, topY)
end

local function windowFrame(
	parent: Instance,
	center: Vector3,
	width: number,
	y0: number,
	y1: number,
	alongX: boolean,
	beamColor: Color3
)
	local frameT = 0.5
	local inset = 0.2
	local depth = WALL_T + 0.4
	local h = y1 - y0
	local cy = (y0 + y1) / 2

	local function piece(size: Vector3, pos: Vector3)
		part({
			Name = "WindowFrame",
			Size = size,
			Position = pos,
			Color = beamColor,
			Material = Enum.Material.Wood,
		}).Parent = parent
	end

	if alongX then
		piece(Vector3.new(width + frameT * 2, frameT, depth), Vector3.new(center.X, y1 + frameT / 2 - inset, center.Z))
		piece(Vector3.new(width + frameT * 2, frameT, depth), Vector3.new(center.X, y0 - frameT / 2 + inset, center.Z))
		piece(Vector3.new(frameT, h, depth), Vector3.new(center.X - width / 2 - frameT / 2 + inset, cy, center.Z))
		piece(Vector3.new(frameT, h, depth), Vector3.new(center.X + width / 2 + frameT / 2 - inset, cy, center.Z))
		piece(Vector3.new(width, 0.24, 0.24), Vector3.new(center.X, cy, center.Z))
		piece(Vector3.new(0.24, h, 0.24), Vector3.new(center.X, cy, center.Z))
	else
		piece(Vector3.new(depth, frameT, width + frameT * 2), Vector3.new(center.X, y1 + frameT / 2 - inset, center.Z))
		piece(Vector3.new(depth, frameT, width + frameT * 2), Vector3.new(center.X, y0 - frameT / 2 + inset, center.Z))
		piece(Vector3.new(depth, h, frameT), Vector3.new(center.X, cy, center.Z - width / 2 - frameT / 2 + inset))
		piece(Vector3.new(depth, h, frameT), Vector3.new(center.X, cy, center.Z + width / 2 + frameT / 2 - inset))
		piece(Vector3.new(0.24, 0.24, width), Vector3.new(center.X, cy, center.Z))
		piece(Vector3.new(0.24, h, 0.24), Vector3.new(center.X, cy, center.Z))
	end

	part({
		Name = "WindowGlass",
		Size = if alongX then Vector3.new(width, h, 0.15) else Vector3.new(0.15, h, width),
		Position = Vector3.new(center.X, cy, center.Z),
		Color = Color3.fromRGB(170, 200, 220),
		Material = Enum.Material.Glass,
		Transparency = 0.4,
		CanCollide = false,
	}).Parent = parent
end

local function spreadCenters(length: number, n: number): { number }
	local centers = {}
	for i = 1, n do
		table.insert(centers, length * i / (n + 1))
	end
	return centers
end

local function hangingLantern(parent: Instance, x: number, z: number, ceilingY: number, brightness: number, range: number)
	local lanternY = ceilingY - 2.4
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

-- Wall-mounted candle sconce (bracket embeds into the wall at wallX plane,
-- facing +X into the room when sideSign is 1)
local function sconce(parent: Instance, wallX: number, y: number, z: number, sideSign: number)
	part({
		Name = "SconceBracket",
		Size = Vector3.new(0.7, 0.25, 0.25),
		Position = Vector3.new(wallX + sideSign * 0.25, y, z),
		Color = Color3.fromRGB(70, 68, 66),
		Material = Enum.Material.Metal,
		CanCollide = false,
	}).Parent = parent
	local flame = part({
		Name = "SconceFlame",
		Size = Vector3.new(0.22, 0.4, 0.22),
		Position = Vector3.new(wallX + sideSign * 0.55, y + 0.3, z),
		Color = Color3.fromRGB(255, 200, 90),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 200, 110)
	light.Brightness = 0.7
	light.Range = 10
	light.Parent = flame
	flame.Parent = parent
end

-- ------------------------------------------------------------------ stairs

type StairInfo = {
	holeX0: number,
	holeX1: number,
	holeZ0: number,
	holeZ1: number,
	topZ: number,
	eastSide: boolean, -- which wall the run hugs (upper floors mirror off this)
}

-- Stepped stair run along the west (-X) wall, climbing front (+Z) -> back (-Z).
local LANDING_DEPTH = 4.5

-- Stepped stair run hugging one side wall. Successive stories ALTERNATE SIDES
-- (story 1 west, story 2 east, ...) — reversing the climb direction alone is
-- not enough, since that reverses the run without moving its footprint, and an
-- upper run sitting over a lower one fills its stairwell and kills headroom.
-- The run is shortened on shallow footprints so LANDING_DEPTH always fits.
local function buildStairs(
	parent: Instance,
	halfW: number,
	halfD: number,
	baseY: number,
	storyH: number,
	beamColor: Color3,
	eastSide: boolean
): StairInfo
	local stairW = 4.2
	local cx = if eastSide then halfW - 0.7 - stairW / 2 else -halfW + 0.7 + stairW / 2
	local nearEdge = halfD - 1.5
	local farEdge = -halfD + 0.4
	local maxRun = (nearEdge - farEdge) - LANDING_DEPTH
	local runLength = math.max(6, math.min(storyH * 1.3, maxRun))
	local zStart = math.min(nearEdge, farEdge + LANDING_DEPTH + runLength)
	local zEnd = zStart - runLength

	PartUtil.steppedStairs(parent, Vector3.new(cx, baseY + 0.05, zStart), -Vector3.zAxis, storyH, runLength, stairW, {
		stepColor = FLOOR_WOOD,
		stepMaterial = Enum.Material.WoodPlanks,
		railColor = DARK_WOOD,
		-- open side faces the room
		railSides = { if eastSide then -Vector3.xAxis else Vector3.xAxis },
	})

	return {
		holeX0 = if eastSide then cx - stairW / 2 - 0.4 else -halfW + 0.4,
		holeX1 = if eastSide then halfW - 0.4 else cx + stairW / 2 + 0.4,
		holeZ0 = zEnd,
		holeZ1 = zEnd + runLength * 0.5,
		topZ = zEnd,
		eastSide = eastSide,
	}
end

local function buildFloorPlate(
	parent: Instance,
	halfW: number,
	halfD: number,
	plateTopY: number,
	hole: StairInfo?,
	beamColor: Color3
)
	local thickness = 0.5
	local y = plateTopY - thickness / 2
	local function slab(sx0: number, sx1: number, sz0: number, sz1: number)
		if sx1 - sx0 <= 0.1 or sz1 - sz0 <= 0.1 then
			return
		end
		part({
			Name = "FloorPlate",
			Size = Vector3.new(sx1 - sx0, thickness, sz1 - sz0),
			Position = Vector3.new((sx0 + sx1) / 2, y, (sz0 + sz1) / 2),
			Color = FLOOR_WOOD,
			Material = Enum.Material.WoodPlanks,
		}).Parent = parent
	end

	local x0, x1 = -halfW + 0.4, halfW - 0.4
	local z0, z1 = -halfD + 0.4, halfD - 0.4
	if not hole then
		slab(x0, x1, z0, z1)
		return
	end

	slab(x0, hole.holeX0, z0, z1) -- west of the stairwell
	slab(hole.holeX1, x1, z0, z1) -- east of it
	slab(hole.holeX0, hole.holeX1, z0, hole.holeZ0) -- behind (the landing)
	slab(hole.holeX0, hole.holeX1, hole.holeZ1, z1) -- in front

	-- Railing: the room-facing long edge, plus the +Z end. The -Z end is the
	-- stair arrival and must stay open.
	local railX = if hole.eastSide then hole.holeX0 - 0.15 else hole.holeX1 + 0.15
	part({
		Name = "GuardRail",
		Size = Vector3.new(0.3, 0.3, hole.holeZ1 - hole.holeZ0),
		Position = Vector3.new(railX, plateTopY + 2.8, (hole.holeZ0 + hole.holeZ1) / 2),
		Color = DARK_WOOD,
		Material = Enum.Material.Wood,
	}).Parent = parent
	part({
		Name = "GuardRail",
		Size = Vector3.new(hole.holeX1 - hole.holeX0, 0.3, 0.3),
		Position = Vector3.new((hole.holeX0 + hole.holeX1) / 2, plateTopY + 2.8, hole.holeZ1 + 0.15),
		Color = DARK_WOOD,
		Material = Enum.Material.Wood,
	}).Parent = parent
	for _, z in { hole.holeZ0 + 0.3, (hole.holeZ0 + hole.holeZ1) / 2, hole.holeZ1 - 0.3 } do
		part({
			Name = "GuardPost",
			Size = Vector3.new(0.3, 2.8, 0.3),
			Position = Vector3.new(railX, plateTopY + 1.4, z),
			Color = beamColor,
			Material = Enum.Material.Wood,
		}).Parent = parent
	end
	for _, gx in { hole.holeX0 + 0.3, hole.holeX1 - 0.3 } do
		part({
			Name = "GuardPost",
			Size = Vector3.new(0.3, 2.8, 0.3),
			Position = Vector3.new(gx, plateTopY + 1.4, hole.holeZ1 + 0.15),
			Color = beamColor,
			Material = Enum.Material.Wood,
		}).Parent = parent
	end
end

-- ------------------------------------------------------------- ground floor

local function livingRoom(parent: Instance, halfW: number, halfD: number, floorY: number, ceilingY: number, seed: number, withBed: boolean?)
	local rug = RUG_COLORS[seed % #RUG_COLORS + 1]
	part({
		Name = "Rug",
		Size = Vector3.new(10, 0.12, 8),
		Position = Vector3.new(halfW * 0.28, floorY + 0.06, -1),
		Color = rug,
		Material = Enum.Material.Fabric,
		CanCollide = false,
	}).Parent = parent

	local tx = halfW * 0.3
	part({ Name = "TableTop", Size = Vector3.new(6.5, 0.5, 4), Position = Vector3.new(tx, floorY + 2.65, -1), Color = Color3.fromRGB(110, 78, 48), Material = Enum.Material.WoodPlanks }).Parent = parent
	for _, offset in { Vector3.new(-2, 0, -1.2), Vector3.new(2, 0, -1.2), Vector3.new(-2, 0, 1.2), Vector3.new(2, 0, 1.2) } do
		part({
			Name = "TableLeg",
			Size = Vector3.new(0.35, 2.4, 0.35),
			Position = Vector3.new(tx, floorY + 1.2, -1) + offset,
			Color = DEFAULT_BEAM,
			Material = Enum.Material.Wood,
		}).Parent = parent
	end
	for _, dz in { -2.8, 2.8 } do
		part({ Name = "Stool", Size = Vector3.new(1.3, 1.5, 1.3), Position = Vector3.new(tx, floorY + 0.75, -1 + dz), Color = Color3.fromRGB(110, 78, 48), Material = Enum.Material.Wood }).Parent = parent
	end
	part({ Name = "TableBowl", Size = Vector3.new(0.9, 0.3, 0.9), Position = Vector3.new(tx - 0.8, floorY + 2.97, -1.4), Color = Color3.fromRGB(150, 120, 90), Material = Enum.Material.SmoothPlastic, CanCollide = false }).Parent = parent

	local cabX = halfW - 2.2
	local cabZ = -halfD + 1.7
	part({ Name = "Cabinet", Size = Vector3.new(4, 6, 2), Position = Vector3.new(cabX, floorY + 2.25, cabZ), Color = DARK_WOOD, Material = Enum.Material.WoodPlanks }).Parent = parent
	part({ Name = "CabinetJug", Size = Vector3.new(0.7, 1, 0.7), Position = Vector3.new(cabX - 0.7, floorY + 5.75, cabZ), Color = Color3.fromRGB(160, 110, 70), Material = Enum.Material.SmoothPlastic, CanCollide = false }).Parent = parent

	part({ Name = "WallBench", Size = Vector3.new(1.2, 1.5, 4), Position = Vector3.new(halfW - 1.35, floorY + 0.75, halfD - 3.4), Color = Color3.fromRGB(110, 78, 48), Material = Enum.Material.WoodPlanks }).Parent = parent

	if withBed then
		-- No upstairs: give the home a sleeping alcove in the back-west corner
		local bx = -halfW + 3
		local bz = -halfD + 4.5
		part({ Name = "BedFrame", Size = Vector3.new(4.2, 0.9, 7), Position = Vector3.new(bx, floorY + 0.45, bz), Color = DEFAULT_BEAM, Material = Enum.Material.Wood }).Parent = parent
		part({ Name = "BedMattress", Size = Vector3.new(3.8, 1.1, 6.6), Position = Vector3.new(bx, floorY + 1.15, bz), Color = Color3.fromRGB(225, 218, 200), Material = Enum.Material.Fabric }).Parent = parent
		part({ Name = "BedPillow", Size = Vector3.new(2.6, 0.5, 1.5), Position = Vector3.new(bx, floorY + 1.9, bz - 2.3), Color = Color3.fromRGB(240, 235, 220), Material = Enum.Material.Fabric }).Parent = parent
		part({ Name = "BedBlanket", Size = Vector3.new(3.9, 0.22, 3.8), Position = Vector3.new(bx, floorY + 1.78, bz + 1.2), Color = BLANKET_COLORS[seed % #BLANKET_COLORS + 1], Material = Enum.Material.Fabric, CanCollide = false }).Parent = parent
		part({ Name = "BedChest", Size = Vector3.new(2.2, 1.3, 1.2), Position = Vector3.new(bx, floorY + 0.65, bz + 4.6), Color = DARK_WOOD, Material = Enum.Material.WoodPlanks }).Parent = parent
		sconce(parent, -halfW + 0.5, floorY + 7, bz, 1)
	end

	hangingLantern(parent, halfW * 0.2, -halfD / 2, ceilingY, 1.2, 20)
end

-- --------------------------------------------------- upper floors: bedrooms

-- Partition wall along the x = px plane with framed door openings.
local function partitionWallX(parent: Instance, px: number, z0: number, z1: number, baseY: number, topY: number, doorZs: { number }, beamColor: Color3)
	local doorW = 4
	local doorH = 9
	local openings: { Opening } = {}
	for _, dz in doorZs do
		table.insert(openings, { center = dz - z0, width = doorW, y0 = baseY, y1 = baseY + doorH })
	end
	local length = z1 - z0
	table.sort(openings, function(a, b)
		return a.center < b.center
	end)
	local function panel(fromOffset: number, toOffset: number, y0: number, y1: number)
		local segLength = toOffset - fromOffset
		if segLength <= 0.05 or (y1 - y0) <= 0.05 then
			return
		end
		part({
			Name = "Partition",
			Size = Vector3.new(0.45, y1 - y0, segLength),
			Position = Vector3.new(px, (y0 + y1) / 2, z0 + (fromOffset + toOffset) / 2),
			Color = PARTITION_COLOR,
			Material = Enum.Material.Plaster,
		}).Parent = parent
	end
	local cursor = 0
	for _, opening in openings do
		local left = opening.center - opening.width / 2
		local right = opening.center + opening.width / 2
		panel(cursor, left, baseY, topY)
		panel(left, right, opening.y1, topY)
		cursor = right
	end
	panel(cursor, length, baseY, topY)
	-- Door trim: posts + lintel, proud of the thin partition on both sides
	for _, dz in doorZs do
		for _, side in { -1, 1 } do
			part({
				Name = "DoorTrim",
				Size = Vector3.new(0.75, doorH + 0.4, 0.45),
				Position = Vector3.new(px, baseY + (doorH + 0.4) / 2 - 0.1, dz + side * (doorW / 2 + 0.05)),
				Color = beamColor,
				Material = Enum.Material.Wood,
			}).Parent = parent
		end
		part({
			Name = "DoorLintelTrim",
			Size = Vector3.new(0.75, 0.5, doorW + 1.3),
			Position = Vector3.new(px, baseY + doorH + 0.15, dz),
			Color = beamColor,
			Material = Enum.Material.Wood,
		}).Parent = parent
	end
end

-- Solid partition along the z = pz plane (between bedrooms).
local function partitionWallZ(parent: Instance, pz: number, x0: number, x1: number, baseY: number, topY: number)
	part({
		Name = "Partition",
		Size = Vector3.new(x1 - x0, topY - baseY, 0.45),
		Position = Vector3.new((x0 + x1) / 2, (baseY + topY) / 2, pz),
		Color = PARTITION_COLOR,
		Material = Enum.Material.Plaster,
	}).Parent = parent
end

-- One furnished bedroom in the region x [x0,x1], z [z0,z1]; variant changes
-- the furniture mix so no two rooms feel identical.
local function furnishBedroom(parent: Instance, x0: number, x1: number, z0: number, z1: number, floorY: number, variant: number, bedAgainstEast: boolean)
	local cx = (x0 + x1) / 2
	local cz = (z0 + z1) / 2
	local blanket = BLANKET_COLORS[variant % #BLANKET_COLORS + 1]
	-- Bed along the outer (east) wall
	local outerX = if bedAgainstEast then x1 else x0
	local innerX = if bedAgainstEast then x0 else x1
	local bedSign = if bedAgainstEast then -1 else 1
	local bedX = outerX + bedSign * 2.6
	local bedZ = cz
	part({ Name = "BedFrame", Size = Vector3.new(4.2, 0.9, 6.6), Position = Vector3.new(bedX, floorY + 0.45, bedZ), Color = DEFAULT_BEAM, Material = Enum.Material.Wood }).Parent = parent
	part({ Name = "BedMattress", Size = Vector3.new(3.8, 1.1, 6.2), Position = Vector3.new(bedX, floorY + 1.15, bedZ), Color = Color3.fromRGB(225, 218, 200), Material = Enum.Material.Fabric }).Parent = parent
	part({ Name = "BedPillow", Size = Vector3.new(2.6, 0.5, 1.4), Position = Vector3.new(bedX, floorY + 1.9, bedZ - 2.1), Color = Color3.fromRGB(240, 235, 220), Material = Enum.Material.Fabric }).Parent = parent
	part({ Name = "BedBlanket", Size = Vector3.new(3.9, 0.22, 3.5), Position = Vector3.new(bedX, floorY + 1.78, bedZ + 1.1), Color = blanket, Material = Enum.Material.Fabric, CanCollide = false }).Parent = parent

	part({
		Name = "Rug",
		Size = Vector3.new(3.6, 0.12, 2.8),
		Position = Vector3.new(cx - 1.5, floorY + 0.06, cz),
		Color = RUG_COLORS[(variant + 1) % #RUG_COLORS + 1],
		Material = Enum.Material.Fabric,
		CanCollide = false,
	}).Parent = parent

	-- Every bedroom is lit regardless of variant (wall sconce on the outer
	-- wall); variant-specific candles are extra flavor on top of this.
	sconce(parent, outerX, floorY + 7, cz + 2.4, bedSign)

	local m = variant % 3
	if m == 0 then
		-- chest at the bed's foot + wall shelf
		part({ Name = "BedChest", Size = Vector3.new(2.2, 1.3, 1.2), Position = Vector3.new(innerX - bedSign * 1.6, floorY + 0.65, z1 - 1.2), Color = DARK_WOOD, Material = Enum.Material.WoodPlanks }).Parent = parent
		part({ Name = "WallShelf", Size = Vector3.new(0.9, 0.35, 3), Position = Vector3.new(outerX + bedSign * 0.35, floorY + 5.4, cz - 4), Color = DEFAULT_BEAM, Material = Enum.Material.Wood }).Parent = parent
		part({ Name = "ShelfPot", Size = Vector3.new(0.6, 0.8, 0.6), Position = Vector3.new(outerX + bedSign * 0.35, floorY + 5.93, cz - 4), Color = Color3.fromRGB(160, 110, 70), Material = Enum.Material.SmoothPlastic, CanCollide = false }).Parent = parent
	elseif m == 1 then
		-- wardrobe + bedside table with a candle
		part({ Name = "Wardrobe", Size = Vector3.new(1.7, 5.5, 3), Position = Vector3.new(innerX - bedSign * 1.3, floorY + 2.75, z1 - 1.9), Color = DARK_WOOD, Material = Enum.Material.WoodPlanks }).Parent = parent
		part({ Name = "BedsideTable", Size = Vector3.new(1.3, 2.1, 1.3), Position = Vector3.new(bedX, floorY + 1.05, bedZ - 3.6), Color = Color3.fromRGB(110, 78, 48), Material = Enum.Material.Wood }).Parent = parent
		part({ Name = "BedsideCandle", Size = Vector3.new(0.25, 0.6, 0.25), Position = Vector3.new(bedX, floorY + 2.45, bedZ - 3.6), Color = Color3.fromRGB(230, 220, 200), Material = Enum.Material.SmoothPlastic, CanCollide = false }).Parent = parent
		local flame = part({
			Name = "CandleFlame",
			Size = Vector3.new(0.16, 0.26, 0.16),
			Position = Vector3.new(bedX, floorY + 2.88, bedZ - 3.6),
			Color = Color3.fromRGB(255, 200, 90),
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 200, 110)
		light.Brightness = 0.5
		light.Range = 8
		light.Parent = flame
		flame.Parent = parent
	else
		-- writing desk + stool
		part({ Name = "DeskTop", Size = Vector3.new(3.2, 0.4, 1.8), Position = Vector3.new(innerX - bedSign * 2.2, floorY + 2.5, z0 + 1.4), Color = Color3.fromRGB(110, 78, 48), Material = Enum.Material.WoodPlanks }).Parent = parent
		for _, offset in { Vector3.new(-1.3, 0, -0.6), Vector3.new(1.3, 0, -0.6), Vector3.new(-1.3, 0, 0.6), Vector3.new(1.3, 0, 0.6) } do
			part({ Name = "DeskLeg", Size = Vector3.new(0.3, 2.2, 0.3), Position = Vector3.new(innerX - bedSign * 2.2, floorY + 1.2, z0 + 1.4) + offset, Color = DEFAULT_BEAM, Material = Enum.Material.Wood }).Parent = parent
		end
		part({ Name = "DeskPaper", Size = Vector3.new(1, 0.08, 0.8), Position = Vector3.new(innerX - bedSign * 2.2, floorY + 2.74, z0 + 1.4), Color = Color3.fromRGB(228, 214, 180), Material = Enum.Material.SmoothPlastic, CanCollide = false }).Parent = parent
		part({ Name = "DeskStool", Size = Vector3.new(1.2, 1.4, 1.2), Position = Vector3.new(innerX - bedSign * 2.2, floorY + 0.7, z0 + 2.9), Color = Color3.fromRGB(110, 78, 48), Material = Enum.Material.Wood }).Parent = parent
	end
end

-- Upper story: hallway along the stairwell + two bedrooms behind doors.
local function hallwayAndBedrooms(
	parent: Instance,
	halfW: number,
	halfD: number,
	baseY: number,
	topY: number,
	hole: StairInfo,
	beamColor: Color3,
	seed: number
)
	-- Mirror the whole floor when the stair below hugged the east wall, so the
	-- hallway always runs alongside the stairwell and the bedrooms sit on the
	-- far side of it.
	local eastStairs = hole.eastSide
	local hallX = if eastStairs then hole.holeX0 - 4.6 else hole.holeX1 + 4.6
	local roomInner = if eastStairs then -halfW + 0.5 else halfW - 0.5
	local doorZs = { halfD / 2, -halfD / 2 }
	partitionWallX(parent, hallX, -halfD + 0.4, halfD - 0.4, baseY, topY, doorZs, beamColor)
	partitionWallZ(parent, 0, math.min(hallX, roomInner) + 0.25, math.max(hallX, roomInner) - 0.25, baseY, topY)

	local runnerX = if eastStairs then hallX + 1.4 else hallX - 1.4
	part({
		Name = "HallRunner",
		Size = Vector3.new(2, 0.1, (halfD - 1) * 2),
		Position = Vector3.new(runnerX, baseY + 0.05, 0),
		Color = Color3.fromRGB(110, 70, 60),
		Material = Enum.Material.Fabric,
		CanCollide = false,
	}).Parent = parent
	for _, dz in doorZs do
		sconce(parent, hallX, baseY + 7.4, dz + 3, if eastStairs then 1 else -1)
	end

	local roomX0 = math.min(hallX, roomInner) + 0.5
	local roomX1 = math.max(hallX, roomInner) - 0.5
	furnishBedroom(parent, roomX0, roomX1, 0.3, halfD - 0.5, baseY, seed, not eastStairs)
	furnishBedroom(parent, roomX0, roomX1, -halfD + 0.5, -0.3, baseY, seed + 1, not eastStairs)
end

-- Ground-floor shop: counter across the back, stocked shelves, display table,
-- and a BrowseSpot so villagers/travelers come in, chat, and buy.
local function shopRoom(parent: Instance, halfW: number, halfD: number, floorY: number, ceilingY: number, wares: string, beamColor: Color3)
	part({ Name = "ShopCounterBase", Size = Vector3.new(halfW * 1.1, 2.4, 2), Position = Vector3.new(0, floorY + 1.2, -halfD + 4), Color = DARK_WOOD, Material = Enum.Material.Wood }).Parent = parent
	part({ Name = "ShopCounterTop", Size = Vector3.new(halfW * 1.1 + 0.4, 0.5, 2.4), Position = Vector3.new(0, floorY + 2.65, -halfD + 4), Color = Color3.fromRGB(110, 78, 48), Material = Enum.Material.WoodPlanks }).Parent = parent
	-- Stocked shelves on the back wall, kept below the window band
	for _, shelfY in { 1.6, 3.2 } do
		part({ Name = "ShopShelf", Size = Vector3.new(halfW * 1.3, 0.35, 1), Position = Vector3.new(0, floorY + shelfY, -halfD + 0.9), Color = beamColor, Material = Enum.Material.Wood }).Parent = parent
		for i = 0, 4 do
			part({
				Name = "ShopStock",
				Size = Vector3.new(0.9, 1, 0.9),
				Position = Vector3.new(-halfW * 0.55 + i * halfW * 0.27, floorY + shelfY + 0.67, -halfD + 0.9),
				Color = if i % 2 == 0 then Color3.fromRGB(160, 126, 80) else Color3.fromRGB(120, 130, 160),
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
			}).Parent = parent
		end
	end
	part({ Name = "DisplayTable", Size = Vector3.new(5, 0.5, 3.5), Position = Vector3.new(halfW * 0.25, floorY + 2.6, 1), Color = Color3.fromRGB(110, 78, 48), Material = Enum.Material.WoodPlanks }).Parent = parent
	part({ Name = "DisplayTableBase", Size = Vector3.new(4.4, 2.1, 2.9), Position = Vector3.new(halfW * 0.25, floorY + 1.05, 1), Color = DARK_WOOD, Material = Enum.Material.Wood }).Parent = parent
	part({ Name = "DisplayGoods", Size = Vector3.new(3.6, 0.7, 2.4), Position = Vector3.new(halfW * 0.25, floorY + 3.2, 1), Color = Color3.fromRGB(190, 160, 100), Material = Enum.Material.Fabric, CanCollide = false }).Parent = parent
	for i = 0, 1 do
		part({ Name = "ShopCrate", Size = Vector3.new(1.8, 1.8, 1.8), Position = Vector3.new(halfW - 2 - i * 2.1, floorY + 0.9, halfD - 2.2), Color = Color3.fromRGB(160, 126, 80), Material = Enum.Material.WoodPlanks }).Parent = parent
	end
	part({
		Name = "Rug",
		Size = Vector3.new(8, 0.12, 6),
		Position = Vector3.new(0, floorY + 0.06, halfD * 0.1),
		Color = RUG_COLORS[1],
		Material = Enum.Material.Fabric,
		CanCollide = false,
	}).Parent = parent
	hangingLantern(parent, 0, 0, ceilingY, 1.4, 24)
	local marker = PartUtil.marker("BrowseSpot", Vector3.new(-2.5, floorY + 0.5, -halfD + 8))
	marker:SetAttribute("Wares", wares)
	marker.Parent = parent
end

local function storageRoom(parent: Instance, halfW: number, halfD: number, floorY: number, ceilingY: number, kind: string?)
	for i = 0, 2 do
		part({
			Name = "StorageCrate",
			Size = Vector3.new(1.8, 1.8, 1.8),
			Position = Vector3.new(-halfW + 1.6 + i * 2.1, floorY + 0.9, -halfD + 1.6),
			Color = Color3.fromRGB(160, 126, 80),
			Material = Enum.Material.WoodPlanks,
		}).Parent = parent
	end
	part({
		Name = "StorageBarrel",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.2, 2, 2),
		CFrame = CFrame.new(halfW - 1.6, floorY + 1.1, -halfD + 1.6) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(110, 78, 48),
		Material = Enum.Material.WoodPlanks,
	}).Parent = parent
	if kind == "tannery" then
		for i = 0, 2 do
			part({ Name = "TanningFrame", Size = Vector3.new(0.4, 6, 5), Position = Vector3.new(-halfW + 4 + i * 5, floorY + 3, halfD - 5), Color = DEFAULT_BEAM, Material = Enum.Material.Wood }).Parent = parent
			part({ Name = "StretchedHide", Size = Vector3.new(0.25, 4.6, 3.8), Position = Vector3.new(-halfW + 4 + i * 5, floorY + 3, halfD - 5), Color = Color3.fromRGB(168, 130, 92), Material = Enum.Material.Leather, CanCollide = false }).Parent = parent
		end
		part({ Name = "TanningBench", Size = Vector3.new(7, 2.4, 2.4), Position = Vector3.new(halfW - 4, floorY + 1.2, 0), Color = Color3.fromRGB(110, 78, 48), Material = Enum.Material.WoodPlanks }).Parent = parent
	elseif kind == "lumber" then
		for i = 0, 3 do
			part({ Name = "PlankStack", Size = Vector3.new(9, 1.2, 3.2), Position = Vector3.new(halfW - 7, floorY + 0.6 + i * 1.25, -halfD + 4 + (i % 2) * 0.4), Color = Color3.fromRGB(186, 150, 104), Material = Enum.Material.WoodPlanks }).Parent = parent
		end
		part({ Name = "SawBench", Size = Vector3.new(6, 2.6, 2.6), Position = Vector3.new(-halfW + 5, floorY + 1.3, halfD - 5), Color = Color3.fromRGB(110, 78, 48), Material = Enum.Material.WoodPlanks }).Parent = parent
		part({ Name = "SawBlade", Size = Vector3.new(3.4, 0.2, 1.6), Position = Vector3.new(-halfW + 5, floorY + 2.7, halfD - 5), Color = Color3.fromRGB(180, 180, 190), Material = Enum.Material.Metal, CanCollide = false }).Parent = parent
	elseif kind == "mason" then
		part({ Name = "MasonBench", Size = Vector3.new(7, 2.6, 3), Position = Vector3.new(halfW - 5, floorY + 1.3, halfD - 5), Color = Color3.fromRGB(110, 78, 48), Material = Enum.Material.WoodPlanks }).Parent = parent
		for i = 0, 2 do
			part({ Name = "Chisel", Size = Vector3.new(0.3, 0.3, 1.4), Position = Vector3.new(halfW - 7 + i * 1.4, floorY + 2.75, halfD - 5), Color = Color3.fromRGB(150, 150, 160), Material = Enum.Material.Metal, CanCollide = false }).Parent = parent
		end
		for i = 0, 3 do
			part({ Name = "CutBlock", Size = Vector3.new(2.4, 1.8, 2), Position = Vector3.new(-halfW + 4 + (i % 2) * 3, floorY + 0.9 + math.floor(i / 2) * 1.85, -halfD + 4), Color = Color3.fromRGB(150, 146, 140), Material = Enum.Material.Rock }).Parent = parent
		end
	elseif kind == "warehouse" then
		for row = 0, 2 do
			for col = 0, 2 do
				part({ Name = "FreightCrate", Size = Vector3.new(2.4, 2.4, 2.4), Position = Vector3.new(-halfW + 4 + col * 6, floorY + 1.2 + (if col == 1 then 2.5 else 0), -halfD + 5 + row * 6), Color = Color3.fromRGB(160, 126, 80), Material = Enum.Material.WoodPlanks }).Parent = parent
			end
		end
		part({ Name = "LoadingBench", Size = Vector3.new(8, 2.4, 2.4), Position = Vector3.new(halfW - 5, floorY + 1.2, halfD - 5), Color = Color3.fromRGB(110, 78, 48), Material = Enum.Material.WoodPlanks }).Parent = parent
	end

	hangingLantern(parent, 0, -halfD / 2, ceilingY, 0.9, 16)
end

-- ------------------------------------------------------------------ main build

function HouseBuilder.build(parentFolder: Instance, config: HouseConfig): Model
	local model = Instance.new("Model")
	model.Name = config.name or "House"

	local w = config.width
	local d = config.depth
	local stories = config.stories
	local storyH = config.storyHeight or STORY_H
	local plaster = config.plasterColor or DEFAULT_PLASTER
	local beamColor = config.beamColor or DEFAULT_BEAM
	local roofColor = config.roofColor or DEFAULT_ROOF
	local doorW = config.doorWidth or 6
	local doorH = math.min(config.doorHeight or 10, storyH - 2)
	local interiorKind = config.interior or "home"
	local seed = config.seed or 0

	local wallTop = 1 + stories * storyH
	local halfW = w / 2
	local halfD = d / 2

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

	part({
		Name = "Foundation",
		Size = Vector3.new(w + 2, 1.2, d + 2),
		Position = Vector3.new(0, 0.4, 0),
		Color = STONE_COLOR,
		Material = Enum.Material.Cobblestone,
	}).Parent = model
	part({
		Name = "Floor",
		Size = Vector3.new(w, 0.4, d),
		Position = Vector3.new(0, 0.9, 0),
		Color = FLOOR_WOOD,
		Material = Enum.Material.WoodPlanks,
	}).Parent = model

	for s = 1, stories do
		local baseY = 1 + (s - 1) * storyH
		local topY = baseY + storyH
		local frontTopY = if s == stories then topY - 0.5 else topY
		local isStone = config.stoneGround == true and s == 1
		local wallColor = if isStone then STONE_COLOR else plaster
		local wallMaterial = if isStone then Enum.Material.Cobblestone else Enum.Material.Plaster
		local winY0 = baseY + storyH * 0.29
		local winY1 = baseY + storyH * 0.71
		local winCount = math.max(1, math.floor(w / 10))
		local sideWinCount = math.max(1, math.floor(d / 12))

		local frontOpenings: { Opening } = {}
		if s == 1 then
			table.insert(frontOpenings, { center = halfW, width = doorW, y0 = 1, y1 = 1 + doorH })
			if w >= 16 then
				table.insert(frontOpenings, { center = halfW / 2.2, width = 4, y0 = winY0, y1 = winY1 })
				table.insert(frontOpenings, { center = w - halfW / 2.2, width = 4, y0 = winY0, y1 = winY1 })
			end
		else
			for _, c in spreadCenters(w, winCount) do
				table.insert(frontOpenings, { center = c, width = 4, y0 = winY0, y1 = winY1 })
			end
		end
		segmentedWall(model, Vector3.new(-halfW, 0, halfD), Vector3.new(halfW, 0, halfD), baseY, frontTopY, frontOpenings, wallColor, wallMaterial)
		for _, opening in frontOpenings do
			if opening.width == 4 then
				windowFrame(model, Vector3.new(-halfW + opening.center, 0, halfD), 4, opening.y0, opening.y1, true, beamColor)
			end
		end

		local backOpenings: { Opening } = {}
		for _, c in spreadCenters(w, winCount) do
			table.insert(backOpenings, { center = c, width = 4, y0 = winY0, y1 = winY1 })
		end
		segmentedWall(model, Vector3.new(-halfW, 0, -halfD), Vector3.new(halfW, 0, -halfD), baseY, frontTopY, backOpenings, wallColor, wallMaterial)
		for _, opening in backOpenings do
			windowFrame(model, Vector3.new(-halfW + opening.center, 0, -halfD), 4, opening.y0, opening.y1, true, beamColor)
		end

		for _, x in { -halfW, halfW } do
			local sideOpenings: { Opening } = {}
			for _, c in spreadCenters(d, sideWinCount) do
				table.insert(sideOpenings, { center = c, width = 4, y0 = winY0, y1 = winY1 })
			end
			segmentedWall(model, Vector3.new(x, 0, -halfD), Vector3.new(x, 0, halfD), baseY, topY, sideOpenings, wallColor, wallMaterial)
			for _, opening in sideOpenings do
				windowFrame(model, Vector3.new(x, 0, -halfD + opening.center), 4, opening.y0, opening.y1, false, beamColor)
			end
		end

		if s < stories then
			for _, z in { -halfD, halfD } do
				part({
					Name = "StoryBand",
					Size = Vector3.new(w + 1, 0.6, WALL_T + 0.4),
					Position = Vector3.new(0, topY, z),
					Color = beamColor,
					Material = Enum.Material.Wood,
				}).Parent = model
			end
			for _, x in { -halfW, halfW } do
				part({
					Name = "StoryBand",
					Size = Vector3.new(WALL_T + 0.4, 0.6, d + 1),
					Position = Vector3.new(x, topY, 0),
					Color = beamColor,
					Material = Enum.Material.Wood,
				}).Parent = model
			end
		end
	end

	for _, x in { -halfW, halfW } do
		for _, z in { -halfD, halfD } do
			part({
				Name = "CornerPost",
				Size = Vector3.new(1.4, wallTop - 1.2, 1.4),
				Position = Vector3.new(x, 1 + (wallTop - 1.2) / 2 - 0.2, z),
				Color = beamColor,
				Material = Enum.Material.Wood,
			}).Parent = model
		end
	end

	local doorFrameInset = 0.2
	part({ Name = "DoorPost", Size = Vector3.new(0.8, doorH + 1, 1.6), Position = Vector3.new(-doorW / 2 - 0.2 + doorFrameInset, (doorH + 1) / 2 + 0.6, halfD), Color = beamColor, Material = Enum.Material.Wood }).Parent = model
	part({ Name = "DoorPost", Size = Vector3.new(0.8, doorH + 1, 1.6), Position = Vector3.new(doorW / 2 + 0.2 - doorFrameInset, (doorH + 1) / 2 + 0.6, halfD), Color = beamColor, Material = Enum.Material.Wood }).Parent = model
	part({ Name = "DoorLintel", Size = Vector3.new(doorW + 1.6, 0.8, 1.6), Position = Vector3.new(0, 1 + doorH + 0.2, halfD), Color = beamColor, Material = Enum.Material.Wood }).Parent = model
	local doorStep = part({ Name = "DoorStep", Size = Vector3.new(doorW + 1, 0.5, 2.4), Position = Vector3.new(0, 0.25, halfD + 1.6), Color = STONE_COLOR, Material = Enum.Material.Slate })
	doorStep.Parent = model
	PartUtil.marker("HouseDoor", Vector3.new(0, 1.2, halfD + 3.6)).Parent = model

	-- Identifier sign above the door (readable name so any building can be
	-- referenced unambiguously: "House 7", "Apothecary", "Town Hall"...)
	if config.signText then
		local signName = config.signText
		local major = config.signMajor == true
		local boardHeight = if major then 2.6 else 1.5
		local boardWidth = math.max(if major then 9 else 5, #signName * (if major then 0.72 else 0.55) + 2)
		local trimColor = Color3.fromRGB(74, 52, 34)

		local function signFace(board: BasePart, face: Enum.NormalId)
			local surface = Instance.new("SurfaceGui")
			surface.Face = face
			surface.CanvasSize = Vector2.new(60 * board.Size.X, 60 * board.Size.Y)
			surface.Parent = board
			local text = Instance.new("TextLabel")
			text.Size = UDim2.fromScale(0.94, 0.8)
			text.Position = UDim2.fromScale(0.03, 0.1)
			text.BackgroundTransparency = 1
			text.Text = signName
			text.Font = Enum.Font.Merriweather
			text.TextScaled = true
			text.TextColor3 = if major then Color3.fromRGB(246, 226, 160) else Color3.fromRGB(240, 228, 200)
			text.TextStrokeColor3 = Color3.fromRGB(40, 28, 16)
			text.TextStrokeTransparency = 0.35
			text.Parent = surface
		end

		-- Board mounted flat above the door
		local signBoard = part({
			Name = "DoorSign",
			Size = Vector3.new(boardWidth, boardHeight, 0.4),
			Position = Vector3.new(0, 1 + doorH + boardHeight / 2 + 0.7, halfD + 0.45),
			Color = if major then Color3.fromRGB(92, 64, 40) else Color3.fromRGB(112, 82, 52),
			Material = Enum.Material.WoodPlanks,
		})
		signFace(signBoard, Enum.NormalId.Back)
		signBoard.Parent = model

		if major then
			-- carved frame around the board
			for _, dx in { -(boardWidth / 2 + 0.2), boardWidth / 2 + 0.2 } do
				part({
					Name = "SignTrim",
					Size = Vector3.new(0.45, boardHeight + 0.8, 0.55),
					Position = Vector3.new(dx, signBoard.Position.Y, halfD + 0.5),
					Color = trimColor,
					Material = Enum.Material.Wood,
				}).Parent = model
			end
			for _, dy in { -(boardHeight / 2 + 0.25), boardHeight / 2 + 0.25 } do
				part({
					Name = "SignTrim",
					Size = Vector3.new(boardWidth + 1.3, 0.45, 0.55),
					Position = Vector3.new(0, signBoard.Position.Y + dy, halfD + 0.5),
					Color = trimColor,
					Material = Enum.Material.Wood,
				}).Parent = model
			end
			-- perpendicular hanging sign, readable from down the street
			local hangX = doorW / 2 + 3.5
			local hangY = 1 + doorH - 0.4
			part({
				Name = "HangingSignBracket",
				Size = Vector3.new(3.2, 0.3, 0.3),
				Position = Vector3.new(hangX - 1.4, hangY + 2.4, halfD + 0.5),
				Color = Color3.fromRGB(60, 58, 55),
				Material = Enum.Material.Metal,
			}).Parent = model
			for _, dx in { -1.1, 1.1 } do
				part({
					Name = "HangingSignChain",
					Size = Vector3.new(0.16, 1.2, 0.16),
					Position = Vector3.new(hangX + dx, hangY + 1.8, halfD + 1.9),
					Color = Color3.fromRGB(60, 58, 55),
					Material = Enum.Material.Metal,
					CanCollide = false,
				}).Parent = model
			end
			part({
				Name = "HangingSignArm",
				Size = Vector3.new(2.6, 0.3, 0.3),
				Position = Vector3.new(hangX, hangY + 2.4, halfD + 1.9),
				Color = Color3.fromRGB(60, 58, 55),
				Material = Enum.Material.Metal,
			}).Parent = model
			local hangBoard = part({
				Name = "HangingSign",
				Size = Vector3.new(0.4, 2.2, math.max(6, #signName * 0.5 + 1.5)),
				Position = Vector3.new(hangX, hangY + 0.1, halfD + 1.9),
				Color = Color3.fromRGB(92, 64, 40),
				Material = Enum.Material.WoodPlanks,
			})
            -- both faces so it reads from either direction along the street
			signFace(hangBoard, Enum.NormalId.Right)
			signFace(hangBoard, Enum.NormalId.Left)
			hangBoard.Parent = model
		end
	end

	local rise = math.clamp(d * 0.38, 5, 10)
	local overhang = 1.5
	local lift = 0.6
	local angle = math.atan(rise / halfD)
	local run = halfD + overhang
	local drop = math.tan(angle) * run
	local ridgeY = wallTop + rise + lift
	local eaveY = ridgeY - drop
	local slabLength = math.sqrt(run * run + drop * drop)

	for _, side in { 1, -1 } do
		part({
			Name = "RoofSlab",
			Size = Vector3.new(w + overhang * 2, 0.5, slabLength),
			CFrame = CFrame.new(0, (ridgeY + eaveY) / 2, side * run / 2) * CFrame.Angles(side * angle, 0, 0),
			Color = roofColor,
			Material = Enum.Material.RoofShingles,
		}).Parent = model
	end
	part({
		Name = "RidgeCap",
		Size = Vector3.new(w + overhang * 2, 0.7, 1.2),
		Position = Vector3.new(0, ridgeY + 0.1, 0),
		Color = beamColor,
		Material = Enum.Material.Wood,
	}).Parent = model
	for _, z in { -halfD, halfD } do
		part({
			Name = "EavePlate",
			Size = Vector3.new(w + 1, 1, 1.4),
			Position = Vector3.new(0, wallTop - 0.2, z),
			Color = beamColor,
			Material = Enum.Material.Wood,
		}).Parent = model
	end
	local gableDepth = halfD - 0.7
	for _, x in { -(halfW - 0.25), halfW - 0.25 } do
		for _, side in { 1, -1 } do
			wedge({
				Name = "Gable",
				Size = Vector3.new(1, rise, gableDepth),
				CFrame = CFrame.new(x, wallTop + rise / 2, side * gableDepth / 2)
					* CFrame.Angles(0, if side == 1 then math.pi else 0, 0),
				Color = if config.stoneGround and stories == 1 then STONE_COLOR else plaster,
				Material = Enum.Material.Plaster,
			}).Parent = model
		end
	end

	-- ------------------------------------------------------ interior
	if interiorKind ~= "none" then
		for _, z in { -halfD / 2, halfD / 2 } do
			part({
				Name = "CollarRafter",
				Size = Vector3.new(w - 1, 0.5, 0.7),
				Position = Vector3.new(0, wallTop + 0.15, z),
				Color = beamColor,
				Material = Enum.Material.Wood,
				CanCollide = false,
			}).Parent = model
		end

		if interiorKind == "storage" or (interiorKind == "home" and d < 15) then
			storageRoom(model, halfW, halfD, 1.1, wallTop, config.workshop)
		else
			local hole: StairInfo? = nil
			for s = 1, stories do
				local floorY = 1 + (s - 1) * storyH + (if s == 1 then 0.1 else 0.05)
				local ceilingY = if s < stories then 1 + s * storyH - 0.5 else wallTop
				if s > 1 then
					buildFloorPlate(model, halfW, halfD, 1 + (s - 1) * storyH, hole, beamColor)
				end
				if s < stories then
					hole = buildStairs(model, halfW, halfD, 1 + (s - 1) * storyH, storyH, beamColor, s % 2 == 0)
				end
				if s == 1 then
					if interiorKind == "shop" then
						shopRoom(model, halfW, halfD, floorY, ceilingY, config.shopWares or "parcel", beamColor)
					else
						livingRoom(model, halfW, halfD, floorY, ceilingY, seed + s, stories == 1)
					end
				elseif hole then
					hallwayAndBedrooms(model, halfW, halfD, 1 + (s - 1) * storyH, ceilingY, hole, beamColor, seed + s * 2)
					hangingLantern(model, hole.holeX1 + 2, halfD / 2, ceilingY, 0.9, 14)
				end
			end
		end
	end

	model.Parent = parentFolder
	model:PivotTo(CFrame.new(config.position) * CFrame.Angles(0, math.rad(config.rotation or 0), 0))
	return model
end

return HouseBuilder
