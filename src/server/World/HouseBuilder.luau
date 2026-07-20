--!strict
-- Parametric timber-frame house generator with REAL interiors: every story has
-- a floor plate, stairs connect stories (walkable ramp + stringers + railing),
-- and rooms are furnished for purpose (living/kitchen below, bedrooms above).
-- Front doors are open — every building can be walked into.
--
-- Houses build in local coordinates (centered on origin, door facing local +Z,
-- ground at y=0) then pivot to their world position/rotation.
--
-- Z-fighting rules baked in (learned on the Rowan cottage):
--  * no two surfaces ever share a plane; overlaps or offsets of >= 0.1
--  * frame pieces overlap INTO openings so wall cut-faces are buried
--  * eave-side walls stop below the roof slope; eave plates stay inside slabs
--  * gable wedges: full rise, depth trimmed so tips end inside the eave plates
--  * nothing floats: furniture sits on floors, wall fixtures embed into walls,
--    hanging lights connect to the ceiling by a chain that reaches it

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
	interior: ("home" | "storage" | "none")?, -- default "home"
	seed: number?, -- deterministic furnishing variation
}

local DEFAULT_PLASTER = Color3.fromRGB(232, 224, 205)
local DEFAULT_BEAM = Color3.fromRGB(74, 52, 34)
local DEFAULT_ROOF = Color3.fromRGB(112, 66, 48)
local STONE_COLOR = Color3.fromRGB(130, 126, 120)
local DARK_WOOD = Color3.fromRGB(96, 62, 38)
local FLOOR_WOOD = Color3.fromRGB(133, 100, 67)
local WALL_T = 1

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

-- Hanging lantern whose chain actually reaches the given ceiling y.
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

-- ------------------------------------------------------------------ stairs

type StairInfo = {
	-- the rectangular hole the floor plate above must leave open
	holeX0: number,
	holeX1: number,
	holeZ0: number,
	holeZ1: number,
}

-- Straight stair run along the west (-X) wall, climbing from front (+Z)
-- toward the back (-Z). Returns the stairwell hole for the plate above.
local function buildStairs(parent: Instance, halfW: number, baseY: number, storyH: number, beamColor: Color3): StairInfo
	local runLength = storyH * 1.3
	local stairW = 3.2
	local cx = -halfW + 0.6 + stairW / 2
	local zBottom = runLength / 2 + 1 -- front end of the run
	local zTop = zBottom - runLength

	-- Walkable ramp (wedge rises toward -Z)
	wedge({
		Name = "StairRamp",
		Size = Vector3.new(stairW, storyH, runLength),
		CFrame = CFrame.new(cx, baseY + storyH / 2, zBottom - runLength / 2),
		Color = FLOOR_WOOD,
		Material = Enum.Material.WoodPlanks,
	}).Parent = parent
	-- Stringer along the open (east) side
	wedge({
		Name = "StairStringer",
		Size = Vector3.new(0.4, storyH + 0.5, runLength + 0.8),
		CFrame = CFrame.new(cx + stairW / 2 + 0.1, baseY + (storyH + 0.5) / 2 - 0.25, zBottom - runLength / 2),
		Color = beamColor,
		Material = Enum.Material.Wood,
	}).Parent = parent
	-- Handrail on the open side: posts at bottom/middle/top + sloped rail
	local railX = cx + stairW / 2 + 0.1
	for i = 0, 2 do
		local t = i / 2
		local z = zBottom - runLength * t
		local baseHeight = baseY + storyH * t
		part({
			Name = "StairPost",
			Size = Vector3.new(0.35, 3.2, 0.35),
			Position = Vector3.new(railX, baseHeight + 1.6, z),
			Color = beamColor,
			Material = Enum.Material.Wood,
		}).Parent = parent
	end
	local railLength = math.sqrt(runLength * runLength + storyH * storyH)
	local angle = math.atan(storyH / runLength)
	part({
		Name = "StairRail",
		Size = Vector3.new(0.3, 0.3, railLength),
		CFrame = CFrame.new(railX, baseY + storyH / 2 + 2.9, zBottom - runLength / 2) * CFrame.Angles(-angle, 0, 0),
		Color = DARK_WOOD,
		Material = Enum.Material.Wood,
	}).Parent = parent

	return {
		holeX0 = -halfW + 0.4,
		holeX1 = cx + stairW / 2 + 0.4,
		holeZ0 = zTop - 1,
		holeZ1 = zTop + runLength * 0.55,
	}
end

-- Upper floor plate with a stairwell hole, plus a guard railing around it.
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
	local function slab(x0: number, x1: number, z0: number, z1: number)
		if x1 - x0 <= 0.1 or z1 - z0 <= 0.1 then
			return
		end
		part({
			Name = "FloorPlate",
			Size = Vector3.new(x1 - x0, thickness, z1 - z0),
			Position = Vector3.new((x0 + x1) / 2, y, (z0 + z1) / 2),
			Color = FLOOR_WOOD,
			Material = Enum.Material.WoodPlanks,
		}).Parent = parent
	end

	local x0, x1 = -halfW + 0.4, halfW - 0.4
	local z0, z1 = -halfD + 0.4, halfD - 0.4
	if hole then
		slab(hole.holeX1, x1, z0, z1) -- main area east of the stairwell
		slab(x0, hole.holeX1, hole.holeZ1, z1) -- west strip in front of the hole
		slab(x0, hole.holeX1, z0, hole.holeZ0) -- west strip behind the hole
		-- Guard railing along the hole's east edge and front edge
		local railY = plateTopY + 1.5
		part({
			Name = "GuardRail",
			Size = Vector3.new(0.3, 0.3, hole.holeZ1 - hole.holeZ0),
			Position = Vector3.new(hole.holeX1 + 0.15, railY + 1.3, (hole.holeZ0 + hole.holeZ1) / 2),
			Color = DARK_WOOD,
			Material = Enum.Material.Wood,
		}).Parent = parent
		for _, z in { hole.holeZ0 + 0.3, (hole.holeZ0 + hole.holeZ1) / 2, hole.holeZ1 - 0.3 } do
			part({
				Name = "GuardPost",
				Size = Vector3.new(0.3, 2.8, 0.3),
				Position = Vector3.new(hole.holeX1 + 0.15, plateTopY + 1.4, z),
				Color = beamColor,
				Material = Enum.Material.Wood,
			}).Parent = parent
		end
	else
		slab(x0, x1, z0, z1)
	end
end

-- ------------------------------------------------------------------ furnishings

local function livingRoom(parent: Instance, halfW: number, halfD: number, floorY: number, ceilingY: number, seed: number)
	local rug = RUG_COLORS[seed % #RUG_COLORS + 1]
	-- Rug in the middle of the open (east) side
	part({
		Name = "Rug",
		Size = Vector3.new(6.5, 0.12, 5),
		Position = Vector3.new(halfW * 0.25, floorY + 0.06, -1),
		Color = rug,
		Material = Enum.Material.Fabric,
		CanCollide = false,
	}).Parent = parent

	-- Dining table + stools
	local tx = halfW * 0.25
	part({ Name = "TableTop", Size = Vector3.new(5, 0.45, 3), Position = Vector3.new(tx, floorY + 2.6, -1), Color = Color3.fromRGB(110, 78, 48), Material = Enum.Material.WoodPlanks }).Parent = parent
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

	-- Sideboard cabinet in the back-east corner (clear of windows)
	local cabX = halfW - 2.2
	local cabZ = -halfD + 1.7
	part({ Name = "Cabinet", Size = Vector3.new(3, 4.5, 1.8), Position = Vector3.new(cabX, floorY + 2.25, cabZ), Color = DARK_WOOD, Material = Enum.Material.WoodPlanks }).Parent = parent
	part({ Name = "CabinetJug", Size = Vector3.new(0.6, 0.9, 0.6), Position = Vector3.new(cabX - 0.5, floorY + 4.95, cabZ), Color = Color3.fromRGB(160, 110, 70), Material = Enum.Material.SmoothPlastic, CanCollide = false }).Parent = parent
	part({ Name = "CabinetPlate", Size = Vector3.new(0.8, 0.15, 0.8), Position = Vector3.new(cabX + 0.7, floorY + 4.58, cabZ), Color = Color3.fromRGB(200, 195, 185), Material = Enum.Material.SmoothPlastic, CanCollide = false }).Parent = parent

	-- Bench along the west wall behind the stairs' entry (front-west corner)
	part({ Name = "WallBench", Size = Vector3.new(1.2, 1.5, 4), Position = Vector3.new(halfW - 1.35, floorY + 0.75, halfD - 3.4), Color = Color3.fromRGB(110, 78, 48), Material = Enum.Material.WoodPlanks }).Parent = parent

	hangingLantern(parent, halfW * 0.2, -halfD / 2, ceilingY, 1.2, 18)
end

local function bedroom(parent: Instance, halfW: number, halfD: number, floorY: number, ceilingY: number, seed: number, bedCount: number)
	local blanket = BLANKET_COLORS[seed % #BLANKET_COLORS + 1]
	for i = 1, bedCount do
		-- Beds along the back wall, spaced eastward (stair landing owns the west)
		local bx = -halfW + 6.5 + (i - 1) * 6
		if bx + 2.3 > halfW - 0.8 then
			break
		end
		local bz = -halfD + 4.2
		part({ Name = "BedFrame", Size = Vector3.new(4.2, 0.9, 7), Position = Vector3.new(bx, floorY + 0.45, bz), Color = DEFAULT_BEAM, Material = Enum.Material.Wood }).Parent = parent
		part({ Name = "BedMattress", Size = Vector3.new(3.8, 1.1, 6.6), Position = Vector3.new(bx, floorY + 1.15, bz), Color = Color3.fromRGB(225, 218, 200), Material = Enum.Material.Fabric }).Parent = parent
		part({ Name = "BedPillow", Size = Vector3.new(2.6, 0.5, 1.5), Position = Vector3.new(bx, floorY + 1.9, bz - 2.3), Color = Color3.fromRGB(240, 235, 220), Material = Enum.Material.Fabric }).Parent = parent
		part({ Name = "BedBlanket", Size = Vector3.new(3.9, 0.22, 3.8), Position = Vector3.new(bx, floorY + 1.78, bz + 1.2), Color = blanket, Material = Enum.Material.Fabric, CanCollide = false }).Parent = parent
		part({ Name = "BedChest", Size = Vector3.new(2.2, 1.3, 1.2), Position = Vector3.new(bx, floorY + 0.65, bz + 4.2), Color = DARK_WOOD, Material = Enum.Material.WoodPlanks }).Parent = parent
	end

	-- Wardrobe against the east wall
	part({
		Name = "Wardrobe",
		Size = Vector3.new(1.7, 5.5, 3.2),
		Position = Vector3.new(halfW - 1.3, floorY + 2.75, 0),
		Color = DARK_WOOD,
		Material = Enum.Material.WoodPlanks,
	}).Parent = parent

	part({
		Name = "Rug",
		Size = Vector3.new(4.5, 0.12, 3.5),
		Position = Vector3.new(0, floorY + 0.06, 2),
		Color = RUG_COLORS[(seed + 1) % #RUG_COLORS + 1],
		Material = Enum.Material.Fabric,
		CanCollide = false,
	}).Parent = parent

	hangingLantern(parent, 0, -halfD / 2, ceilingY, 1, 15)
end

local function storageRoom(parent: Instance, halfW: number, halfD: number, floorY: number, ceilingY: number)
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
	hangingLantern(parent, 0, -halfD / 2, ceilingY, 0.8, 12)
end

-- ------------------------------------------------------------------ main build

function HouseBuilder.build(parentFolder: Instance, config: HouseConfig): Model
	local model = Instance.new("Model")
	model.Name = config.name or "House"

	local w = config.width
	local d = config.depth
	local stories = config.stories
	local storyH = config.storyHeight or 7
	local plaster = config.plasterColor or DEFAULT_PLASTER
	local beamColor = config.beamColor or DEFAULT_BEAM
	local roofColor = config.roofColor or DEFAULT_ROOF
	local doorW = config.doorWidth or 4
	local doorH = math.min(config.doorHeight or 6, storyH - 1)
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
		local winY0 = baseY + 2.5
		local winY1 = baseY + 5.5
		local winCount = math.max(1, math.floor(w / 9))
		local sideWinCount = math.max(1, math.floor(d / 12))

		local frontOpenings: { Opening } = {}
		if s == 1 then
			table.insert(frontOpenings, { center = halfW, width = doorW, y0 = 1, y1 = 1 + doorH })
			if w >= 16 then
				table.insert(frontOpenings, { center = halfW / 2.2, width = 3, y0 = winY0, y1 = winY1 })
				table.insert(frontOpenings, { center = w - halfW / 2.2, width = 3, y0 = winY0, y1 = winY1 })
			end
		else
			for _, c in spreadCenters(w, winCount) do
				table.insert(frontOpenings, { center = c, width = 3, y0 = winY0, y1 = winY1 })
			end
		end
		segmentedWall(model, Vector3.new(-halfW, 0, halfD), Vector3.new(halfW, 0, halfD), baseY, frontTopY, frontOpenings, wallColor, wallMaterial)
		for _, opening in frontOpenings do
			if opening.width == 3 then
				windowFrame(model, Vector3.new(-halfW + opening.center, 0, halfD), 3, opening.y0, opening.y1, true, beamColor)
			end
		end

		local backOpenings: { Opening } = {}
		for _, c in spreadCenters(w, winCount) do
			table.insert(backOpenings, { center = c, width = 3, y0 = winY0, y1 = winY1 })
		end
		segmentedWall(model, Vector3.new(-halfW, 0, -halfD), Vector3.new(halfW, 0, -halfD), baseY, frontTopY, backOpenings, wallColor, wallMaterial)
		for _, opening in backOpenings do
			windowFrame(model, Vector3.new(-halfW + opening.center, 0, -halfD), 3, opening.y0, opening.y1, true, beamColor)
		end

		for _, x in { -halfW, halfW } do
			local sideOpenings: { Opening } = {}
			for _, c in spreadCenters(d, sideWinCount) do
				table.insert(sideOpenings, { center = c, width = 3, y0 = winY0, y1 = winY1 })
			end
			segmentedWall(model, Vector3.new(x, 0, -halfD), Vector3.new(x, 0, halfD), baseY, topY, sideOpenings, wallColor, wallMaterial)
			for _, opening in sideOpenings do
				windowFrame(model, Vector3.new(x, 0, -halfD + opening.center), 3, opening.y0, opening.y1, false, beamColor)
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

	-- Open doorway: frame + step, no slab
	local doorFrameInset = 0.2
	part({ Name = "DoorPost", Size = Vector3.new(0.8, doorH + 1, 1.6), Position = Vector3.new(-doorW / 2 - 0.2 + doorFrameInset, (doorH + 1) / 2 + 0.6, halfD), Color = beamColor, Material = Enum.Material.Wood }).Parent = model
	part({ Name = "DoorPost", Size = Vector3.new(0.8, doorH + 1, 1.6), Position = Vector3.new(doorW / 2 + 0.2 - doorFrameInset, (doorH + 1) / 2 + 0.6, halfD), Color = beamColor, Material = Enum.Material.Wood }).Parent = model
	part({ Name = "DoorLintel", Size = Vector3.new(doorW + 1.6, 0.8, 1.6), Position = Vector3.new(0, 1 + doorH + 0.2, halfD), Color = beamColor, Material = Enum.Material.Wood }).Parent = model
	local doorStep = part({ Name = "DoorStep", Size = Vector3.new(doorW + 1, 0.5, 2.4), Position = Vector3.new(0, 0.25, halfD + 1.6), Color = STONE_COLOR, Material = Enum.Material.Slate })
	doorStep.Parent = model
	game:GetService("CollectionService"):AddTag(doorStep, "HouseDoor")

	-- Roof
	local rise = math.clamp(d * 0.4, 4, 7)
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
		-- Collar rafters under the top of the walls (also anchor the top-floor lantern)
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
			storageRoom(model, halfW, halfD, 1.1, wallTop)
		else
			local hole: StairInfo? = nil
			for s = 1, stories do
				local floorY = 1 + (s - 1) * storyH + (if s == 1 then 0.1 else 0.05)
				local ceilingY = if s < stories then 1 + s * storyH - 0.5 else wallTop
				if s > 1 then
					buildFloorPlate(model, halfW, halfD, 1 + (s - 1) * storyH, hole, beamColor)
				end
				if s < stories then
					hole = buildStairs(model, halfW, 1 + (s - 1) * storyH, storyH, beamColor)
				end
				if s == 1 then
					livingRoom(model, halfW, halfD, floorY, ceilingY, seed + s)
				else
					local bedCount = math.max(1, math.floor((w - 6) / 6))
					bedroom(model, halfW, halfD, 1 + (s - 1) * storyH, ceilingY, seed + s, bedCount)
				end
			end
		end
	end

	model.Parent = parentFolder
	model:PivotTo(CFrame.new(config.position) * CFrame.Angles(0, math.rad(config.rotation or 0), 0))
	return model
end

return HouseBuilder
