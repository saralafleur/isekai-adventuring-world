--!strict
-- Small helpers shared by the world-builder modules.

local PartUtil = {}

function PartUtil.part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

-- Invisible, non-colliding marker part used as an NPC destination; found at
-- runtime via its CollectionService tag.
function PartUtil.marker(tag: string, position: Vector3): Part
	local CollectionService = game:GetService("CollectionService")
	local m = Instance.new("Part")
	m.Name = tag
	m.Size = Vector3.new(1, 1, 1)
	m.Position = position
	m.Anchored = true
	m.Transparency = 1
	m.CanCollide = false
	m.CanQuery = false
	CollectionService:AddTag(m, tag)
	return m
end

-- Real stepped staircase: solid riser blocks (each step ~0.8 rise, walkable),
-- with sloped handrails on the given open sides. `dir` is the horizontal unit
-- direction of climb and must be axis-aligned (+/-X or +/-Z).
export type StairOpts = {
	stepColor: Color3,
	stepMaterial: Enum.Material,
	railColor: Color3,
	railSides: { Vector3 }?, -- perpendicular unit vectors with an open edge
}

function PartUtil.steppedStairs(
	parent: Instance,
	bottomCenter: Vector3, -- floor-level center of the first step's leading edge
	dir: Vector3,
	rise: number,
	run: number,
	width: number,
	opts: StairOpts
)
	local count = math.max(4, math.ceil(rise / 0.8))
	local riseInc = rise / count
	local tread = run / count
	local alongX = math.abs(dir.X) > 0.5

	for i = 1, count do
		local stepHeight = riseInc * i
		local center = bottomCenter + dir * (tread * (i - 0.5)) + Vector3.new(0, stepHeight / 2, 0)
		local step = Instance.new("Part")
		step.Name = "StairStep"
		step.Anchored = true
		step.Size = if alongX then Vector3.new(tread, stepHeight, width) else Vector3.new(width, stepHeight, tread)
		step.Position = center
		step.Color = opts.stepColor
		step.Material = opts.stepMaterial
		step.TopSurface = Enum.SurfaceType.Smooth
		step.BottomSurface = Enum.SurfaceType.Smooth
		step.Parent = parent
	end

	local railSides: { Vector3 } = opts.railSides or {}
	for _, side in railSides do
		local offset = side * (width / 2 + 0.18)
		for _, t in { 0.05, 0.5, 0.95 } do
			local post = Instance.new("Part")
			post.Name = "StairPost"
			post.Anchored = true
			post.Size = Vector3.new(0.32, 3.1, 0.32)
			post.Position = bottomCenter + dir * (run * t) + offset + Vector3.new(0, rise * t + 1.55, 0)
			post.Color = opts.railColor
			post.Material = Enum.Material.Wood
			post.Parent = parent
		end
		local railLength = math.sqrt(run * run + rise * rise) + 0.6
		local mid = bottomCenter + dir * (run / 2) + offset + Vector3.new(0, rise / 2 + 2.95, 0)
		local rail = Instance.new("Part")
		rail.Name = "StairRail"
		rail.Anchored = true
		rail.Size = Vector3.new(0.3, 0.3, railLength)
		rail.CFrame = CFrame.lookAlong(mid, (dir * run + Vector3.new(0, rise, 0)).Unit)
		rail.Color = opts.railColor
		rail.Material = Enum.Material.Wood
		rail.Parent = parent
	end
end

function PartUtil.wedge(props: { [string]: any }): WedgePart
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(w :: any)[key] = value
	end
	return w
end

return PartUtil
