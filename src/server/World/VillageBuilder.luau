--!strict
-- Procedurally builds a greybox Briar Glen so systems are testable before real art exists.
-- Gameplay code finds things by CollectionService tags / names, never by geometry,
-- so this can be replaced with hand-built models later without code changes.

local CollectionService = game:GetService("CollectionService")

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

	-- Ground
	local ground = part({
		Name = "Ground",
		Size = Vector3.new(400, 2, 400),
		Position = Vector3.new(0, -1, 0),
		Color = Color3.fromRGB(106, 152, 82),
		Material = Enum.Material.Grass,
	})
	ground.Parent = village

	-- Rowan cottage (open-top greybox: floor + 3 walls, gap for a door)
	local cottage = Instance.new("Model")
	cottage.Name = "RowanCottage"
	local floorPart = part({
		Name = "Floor",
		Size = Vector3.new(30, 1, 24),
		Position = Vector3.new(0, 0.5, -40),
		Color = Color3.fromRGB(133, 100, 67),
		Material = Enum.Material.WoodPlanks,
	})
	floorPart.Parent = cottage
	local wallColor = Color3.fromRGB(170, 140, 100)
	part({ Name = "WallN", Size = Vector3.new(30, 10, 1), Position = Vector3.new(0, 6, -52), Color = wallColor, Material = Enum.Material.Wood }).Parent = cottage
	part({ Name = "WallW", Size = Vector3.new(1, 10, 24), Position = Vector3.new(-15, 6, -40), Color = wallColor, Material = Enum.Material.Wood }).Parent = cottage
	part({ Name = "WallE", Size = Vector3.new(1, 10, 24), Position = Vector3.new(15, 6, -40), Color = wallColor, Material = Enum.Material.Wood }).Parent = cottage
	-- South wall with door gap
	part({ Name = "WallS1", Size = Vector3.new(12, 10, 1), Position = Vector3.new(-9, 6, -28), Color = wallColor, Material = Enum.Material.Wood }).Parent = cottage
	part({ Name = "WallS2", Size = Vector3.new(12, 10, 1), Position = Vector3.new(9, 6, -28), Color = wallColor, Material = Enum.Material.Wood }).Parent = cottage
	-- Kael's bed
	local bed = part({
		Name = "KaelBed",
		Size = Vector3.new(4, 1.5, 8),
		Position = Vector3.new(-11, 1.75, -47),
		Color = Color3.fromRGB(196, 40, 28),
		Material = Enum.Material.Fabric,
	})
	bed.Parent = cottage
	cottage.Parent = village

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

	-- Village square + baker stall
	local square = Instance.new("Folder")
	square.Name = "VillageSquare"
	local plaza = part({
		Name = "Plaza",
		Size = Vector3.new(50, 0.4, 50),
		Position = Vector3.new(0, 0.2, 50),
		Color = Color3.fromRGB(180, 170, 150),
		Material = Enum.Material.Cobblestone,
	})
	plaza.Parent = square
	local stall = part({
		Name = "BakerStall",
		Size = Vector3.new(10, 8, 6),
		Position = Vector3.new(15, 4, 60),
		Color = Color3.fromRGB(120, 80, 50),
		Material = Enum.Material.Wood,
	})
	stall.Parent = square
	square.Parent = village

	-- NPCs
	makeNpc("Mira", "Mira", Vector3.new(6, 0, -45), Color3.fromRGB(120, 90, 150)).Parent = village
	makeNpc("Daren", "Daren", Vector3.new(10, 0, -35), Color3.fromRGB(90, 110, 140)).Parent = village
	makeNpc("Baker", "Baker Hobb", Vector3.new(15, 0, 55), Color3.fromRGB(220, 180, 120)).Parent = village

	village.Parent = workspace
	return village
end

return VillageBuilder
