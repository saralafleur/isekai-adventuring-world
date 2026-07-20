--!strict
-- Procedurally builds a greybox Briar Glen so systems are testable before real art exists.
-- Gameplay code finds things by CollectionService tags / names, never by geometry,
-- so this can be replaced with hand-built models later without code changes.

local CollectionService = game:GetService("CollectionService")

local CottageBuilder = require(script.Parent.CottageBuilder)
local FarmBuilder = require(script.Parent.FarmBuilder)
local TownBuilder = require(script.Parent.TownBuilder)
local SmithyBuilder = require(script.Parent.SmithyBuilder)

local VillageBuilder = {}

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

local function makeNpc(name: string, displayName: string, position: Vector3, color: Color3): Model
	local model = Instance.new("Model")
	model.Name = name

	local body = part({
		Name = "Body",
		Size = Vector3.new(2, 5, 1.5),
		Position = position + Vector3.new(0, 2.5, 0),
		Color = color,
	})
	body.Parent = model

	local head = part({
		Name = "Head",
		Size = Vector3.new(1.5, 1.5, 1.5),
		Shape = Enum.PartType.Ball,
		Position = position + Vector3.new(0, 5.75, 0),
		Color = Color3.fromRGB(255, 219, 172),
	})
	head.Parent = model

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(200, 40)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = head

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = displayName
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.Parent = billboard

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Talk"
	prompt.ObjectText = displayName
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.Parent = body

	model.PrimaryPart = body
	CollectionService:AddTag(model, "NPC")
	model:SetAttribute("NpcName", name)
	return model
end

local function makeGatherNode(itemId: string, objectText: string, position: Vector3, color: Color3, size: Vector3): Part
	local node = part({
		Name = itemId .. "Node",
		Size = size,
		Position = position,
		Color = color,
		Material = Enum.Material.Neon,
	})

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Gather"
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 6
	prompt.Parent = node

	CollectionService:AddTag(node, "GatherNode")
	node:SetAttribute("ItemId", itemId)
	return node
end

function VillageBuilder.build(): Folder
	local village = Instance.new("Folder")
	village.Name = "BriarGlen"

	-- Ground: covers the farm hamlet (south) through the town (north)
	local ground = part({
		Name = "Ground",
		Size = Vector3.new(700, 2, 700),
		Position = Vector3.new(0, -1, 30),
		Color = Color3.fromRGB(106, 152, 82),
		Material = Enum.Material.Grass,
	})
	ground.Parent = village

	-- Rowan cottage (timber-frame build, includes Kael's bed and interior)
	CottageBuilder.build(village)

	-- Spawn next to the bed
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "BedSpawn"
	spawn.Size = Vector3.new(4, 1, 4)
	spawn.Position = Vector3.new(-6, 1.5, -45)
	spawn.Anchored = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Duration = 0
	spawn.Parent = village

	-- Garden with sunroot nodes
	local garden = Instance.new("Folder")
	garden.Name = "Garden"
	local gardenPlot = part({
		Name = "Plot",
		Size = Vector3.new(24, 0.4, 16),
		Position = Vector3.new(-35, 0.2, -20),
		Color = Color3.fromRGB(86, 66, 54),
		Material = Enum.Material.Ground,
	})
	gardenPlot.Parent = garden
	for i = 1, 6 do
		local row = math.floor((i - 1) / 3)
		local col = (i - 1) % 3
		local node = makeGatherNode(
			"Sunroot",
			"Sunroot",
			Vector3.new(-42 + col * 7, 1, -24 + row * 8),
			Color3.fromRGB(255, 140, 40),
			Vector3.new(1.5, 1.5, 1.5)
		)
		node.Parent = garden
	end
	garden.Parent = village

	-- Chicken pen with egg nodes
	local pen = Instance.new("Folder")
	pen.Name = "ChickenPen"
	local penFloor = part({
		Name = "PenFloor",
		Size = Vector3.new(20, 0.4, 20),
		Position = Vector3.new(35, 0.2, -20),
		Color = Color3.fromRGB(160, 140, 90),
		Material = Enum.Material.Sand,
	})
	penFloor.Parent = pen
	for i = 1, 4 do
		local node = makeGatherNode(
			"Egg",
			"Egg",
			Vector3.new(29 + (i % 2) * 12, 0.9, -26 + math.floor((i - 1) / 2) * 12),
			Color3.fromRGB(250, 245, 230),
			Vector3.new(1, 1.2, 1)
		)
		node.Parent = pen
	end
	-- General Cluck, guardian of the final egg
	local cluck = makeNpc("GeneralCluck", "General Cluck", Vector3.new(35, 0, -14), Color3.fromRGB(240, 240, 240))
	local cluckBody = cluck:FindFirstChild("Body") :: Part
	cluckBody.Size = Vector3.new(2, 2, 2.5)
	cluckBody.Position = Vector3.new(35, 1, -14);
	(cluckBody:FindFirstChildOfClass("ProximityPrompt") :: ProximityPrompt):Destroy()
	local cluckHead = cluck:FindFirstChild("Head") :: Part
	cluckHead.Position = Vector3.new(35, 2.6, -14.8)
	cluckHead.Size = Vector3.new(1, 1, 1)
	cluckHead.Color = Color3.fromRGB(240, 240, 240)
	cluck.Parent = pen
	pen.Parent = village

	-- Market plaza (stalls, well, town hall and townhouses come from TownBuilder)
	local square = Instance.new("Folder")
	square.Name = "VillageSquare"
	local plaza = part({
		Name = "Plaza",
		Size = Vector3.new(60, 0.4, 60),
		Position = Vector3.new(0, 0.2, 50),
		Color = Color3.fromRGB(180, 170, 150),
		Material = Enum.Material.Cobblestone,
	})
	plaza.Parent = square
	square.Parent = village

	FarmBuilder.build(village)
	TownBuilder.build(village)
	SmithyBuilder.build(village)

	-- Dirt path from the cottage door to the plaza
	local path = Instance.new("Folder")
	path.Name = "Path"
	for i = 0, 5 do
		part({
			Name = "PathStone",
			Size = Vector3.new(6 + (i % 2) * 1.5, 0.3, 9),
			Position = Vector3.new((i % 2 - 0.5) * 1.2, 0.15, -22 + i * 8.5),
			Color = Color3.fromRGB(150, 125, 95),
			Material = Enum.Material.Ground,
		}).Parent = path
	end
	path.Parent = village

	-- Trees ring the settled area (buildings now occupy the old inner spots)
	local trees = Instance.new("Folder")
	trees.Name = "Trees"
	local treeSpots = {
		Vector3.new(-150, 0, -150),
		Vector3.new(-160, 0, -60),
		Vector3.new(-155, 0, 40),
		Vector3.new(-150, 0, 130),
		Vector3.new(-120, 0, 200),
		Vector3.new(-60, 0, 240),
		Vector3.new(20, 0, 250),
		Vector3.new(90, 0, 235),
		Vector3.new(140, 0, 180),
		Vector3.new(155, 0, 100),
		Vector3.new(160, 0, 20),
		Vector3.new(150, 0, -70),
		Vector3.new(130, 0, -140),
		Vector3.new(60, 0, -160),
		Vector3.new(-20, 0, -170),
		Vector3.new(-140, 0, -110),
		Vector3.new(-20, 0, -90),
		Vector3.new(95, 0, -115),
	}
	for index, spot in treeSpots do
		local scale = 1 + (index % 3) * 0.25
		local trunk = part({
			Name = "TreeTrunk",
			Size = Vector3.new(2 * scale, 12 * scale, 2 * scale),
			Position = spot + Vector3.new(0, 6 * scale, 0),
			Color = Color3.fromRGB(92, 64, 44),
			Material = Enum.Material.Wood,
		})
		trunk.Parent = trees
		local canopyLow = part({
			Name = "TreeCanopy",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(11 * scale, 11 * scale, 11 * scale),
			Position = spot + Vector3.new(0, 13 * scale, 0),
			Color = Color3.fromRGB(64, 110, 52),
			Material = Enum.Material.LeafyGrass,
			CanCollide = false,
		})
		canopyLow.Parent = trees
		local canopyHigh = part({
			Name = "TreeCanopyTop",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(7 * scale, 7 * scale, 7 * scale),
			Position = spot + Vector3.new(1.5, 17 * scale, 1),
			Color = Color3.fromRGB(78, 128, 60),
			Material = Enum.Material.LeafyGrass,
			CanCollide = false,
		})
		canopyHigh.Parent = trees
	end
	trees.Parent = village

	-- NPCs
	makeNpc("Mira", "Mira", Vector3.new(6, 0, -45), Color3.fromRGB(120, 90, 150)).Parent = village
	makeNpc("Daren", "Daren", Vector3.new(10, 0, -35), Color3.fromRGB(90, 110, 140)).Parent = village
	makeNpc("Baker", "Baker Hobb", Vector3.new(15, 0, 55), Color3.fromRGB(220, 180, 120)).Parent = village

	village.Parent = workspace
	return village
end

return VillageBuilder
