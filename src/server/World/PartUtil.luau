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
