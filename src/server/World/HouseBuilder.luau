--!strict
-- Parametric timber-frame house generator. Builds a house in local coordinates
-- (centered on origin, door facing local +Z, ground at y=0) then pivots the
-- whole model to its world position/rotation.
--
-- Z-fighting rules baked in (learned on the Rowan cottage):
--  * no two surfaces ever share a plane; overlaps or offsets of >= 0.1
--  * frame pieces overlap INTO openings so wall cut-faces are buried
--  * eave-side walls stop below the roof slope; eave plates stay inside slabs
--  * gable wedges: full rise, depth trimmed so tips end inside the eave plates

local PartUtil = require(script.Parent.PartUtil)
local part = PartUtil.part
local wedge = PartUtil.wedge

export type HouseConfig = {
	name: string?,
	position: Vector3, -- world ground position of the house center
	rotation: number?, -- degrees around Y; 0 = door faces world +Z
	width: number, -- facade length (local X)
	depth: number, -- local Z
	stories: number,
	storyHeight: number?,
	plasterColor: Color3?,
	beamColor: Color3?,
	roofColor: Color3?,
	stoneGround: boolean?, -- ground story in stone (town style)
	doorWidth: number?,
	doorHeight: number?,
	doorColor: Color3?,
}

local DEFAULT_PLASTER = Color3.fromRGB(232, 224, 205)
local DEFAULT_BEAM = Color3.fromRGB(74, 52, 34)
local DEFAULT_ROOF = Color3.fromRGB(112, 66, 48)
local STONE_COLOR = Color3.fromRGB(130, 126, 120)
local WALL_T = 1

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

-- Evenly spread n window centers along a span, as offsets from the span start.
local function spreadCenters(length: number, n: number): { number }
	local centers = {}
	for i = 1, n do
		table.insert(centers, length * i / (n + 1))
	end
	return centers
end

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

	local wallTop = 1 + stories * storyH
	local halfW = w / 2
	local halfD = d / 2

	-- Anchor part = model pivot at local origin, ground level
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

	-- Foundation + floor
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
		Color = Color3.fromRGB(133, 100, 67),
		Material = Enum.Material.WoodPlanks,
	}).Parent = model

	-- Walls, story by story
	for s = 1, stories do
		local baseY = 1 + (s - 1) * storyH
		local topY = baseY + storyH
		-- Eave-side (front/back) walls stop short on the top story so they
		-- never reach the sloping roof; the eave plate covers the rest.
		local frontTopY = if s == stories then topY - 0.5 else topY
		local isStone = config.stoneGround == true and s == 1
		local wallColor = if isStone then STONE_COLOR else plaster
		local wallMaterial = if isStone then Enum.Material.Cobblestone else Enum.Material.Plaster
		local winY0 = baseY + 2.5
		local winY1 = baseY + 5.5
		local winCount = math.max(1, math.floor(w / 9))
		local sideWinCount = math.max(1, math.floor(d / 12))

		-- Front wall (+Z): door on ground story, windows above/flanking
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

		-- Back wall (-Z): windows every story
		local backOpenings: { Opening } = {}
		for _, c in spreadCenters(w, winCount) do
			table.insert(backOpenings, { center = c, width = 3, y0 = winY0, y1 = winY1 })
		end
		segmentedWall(model, Vector3.new(-halfW, 0, -halfD), Vector3.new(halfW, 0, -halfD), baseY, frontTopY, backOpenings, wallColor, wallMaterial)
		for _, opening in backOpenings do
			windowFrame(model, Vector3.new(-halfW + opening.center, 0, -halfD), 3, opening.y0, opening.y1, true, beamColor)
		end

		-- Side walls (gable sides, +X/-X): full height, windows every story
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

		-- Story-separation band (skip above the top story; the eaves handle it)
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

	-- Corner posts
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

	-- Door: frame + closed slab + step
	local doorFrameInset = 0.2
	part({ Name = "DoorPost", Size = Vector3.new(0.8, doorH + 1, 1.6), Position = Vector3.new(-doorW / 2 - 0.2 + doorFrameInset, (doorH + 1) / 2 + 0.6, halfD), Color = beamColor, Material = Enum.Material.Wood }).Parent = model
	part({ Name = "DoorPost", Size = Vector3.new(0.8, doorH + 1, 1.6), Position = Vector3.new(doorW / 2 + 0.2 - doorFrameInset, (doorH + 1) / 2 + 0.6, halfD), Color = beamColor, Material = Enum.Material.Wood }).Parent = model
	part({ Name = "DoorLintel", Size = Vector3.new(doorW + 1.6, 0.8, 1.6), Position = Vector3.new(0, 1 + doorH + 0.2, halfD), Color = beamColor, Material = Enum.Material.Wood }).Parent = model
	part({
		Name = "Door",
		Size = Vector3.new(doorW - 0.6, doorH - 0.2, 0.3),
		Position = Vector3.new(0, 1 + (doorH - 0.2) / 2, halfD),
		Color = config.doorColor or Color3.fromRGB(96, 62, 38),
		Material = Enum.Material.Wood,
	}).Parent = model
	part({
		Name = "DoorKnob",
		Size = Vector3.new(0.3, 0.3, 0.3),
		Position = Vector3.new(doorW / 2 - 1, 1 + doorH / 2 - 0.4, halfD + 0.25),
		Color = Color3.fromRGB(200, 170, 90),
		Material = Enum.Material.Metal,
		CanCollide = false,
	}).Parent = model
	part({ Name = "DoorStep", Size = Vector3.new(doorW + 1, 0.5, 2.4), Position = Vector3.new(0, 0.25, halfD + 1.6), Color = STONE_COLOR, Material = Enum.Material.Slate }).Parent = model

	-- Roof: gable, ridge along X, slopes toward +/-Z
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

	-- Eave plates on front/back
	for _, z in { -halfD, halfD } do
		part({
			Name = "EavePlate",
			Size = Vector3.new(w + 1, 1, 1.4),
			Position = Vector3.new(0, wallTop - 0.2, z),
			Color = beamColor,
			Material = Enum.Material.Wood,
		}).Parent = model
	end

	-- Gable wedges on the X ends
	local gableDepth = halfD - 0.7
	for _, x in { -(halfW - 0.25), halfW - 0.25 } do
		for _, side in { 1, -1 } do
			wedge({
				Name = "Gable",
				Size = Vector3.new(1, rise, gableDepth),
				-- Wedge slopes up toward its -Z; tall face at the ridge (z=0)
				CFrame = CFrame.new(x, wallTop + rise / 2, side * gableDepth / 2)
					* CFrame.Angles(0, if side == 1 then math.pi else 0, 0),
				Color = if config.stoneGround and stories == 1 then STONE_COLOR else plaster,
				Material = Enum.Material.Plaster,
			}).Parent = model
		end
	end

	model.Parent = parentFolder
	model:PivotTo(CFrame.new(config.position) * CFrame.Angles(0, math.rad(config.rotation or 0), 0))
	return model
end

return HouseBuilder
