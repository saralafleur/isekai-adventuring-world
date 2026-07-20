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

	-- Ground: the whole valley — farm hamlet, town, and the forest around them
	local ground = part({
		Name = "Ground",
		Size = Vector3.new(1100, 2, 1100),
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

	local GuildBuilder = require(script.Parent.GuildBuilder)
	GuildBuilder.build(village)

	local DistrictBuilder = require(script.Parent.DistrictBuilder)
	DistrictBuilder.build(village)

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

	-- Connector roads to the forest gates (heights differ from the lanes and
	-- streets they cross so overlapping tops never share a plane)
	part({
		Name = "SouthConnector",
		Size = Vector3.new(12, 0.28, 130),
		Position = Vector3.new(0, 0.14, -124),
		Color = Color3.fromRGB(150, 125, 95),
		Material = Enum.Material.Ground,
	}).Parent = village
	part({
		Name = "NorthConnector",
		Size = Vector3.new(12, 0.26, 106),
		Position = Vector3.new(0, 0.13, 187),
		Color = Color3.fromRGB(150, 125, 95),
		Material = Enum.Material.Ground,
	}).Parent = village

	-- Forest surrounds the whole valley (also builds the exit roads + gates)
	local ForestBuilder = require(script.Parent.ForestBuilder)
	ForestBuilder.build(village)

	-- Quest NPCs (Baker Hobb is created by the market as the bread vendor).
	-- Same avatar system as the villagers, wired into the dialogue system via
	-- the NPC tag + NpcName attribute + Talk prompt.
	local AvatarFactory = require(script.Parent.Parent.NPC.AvatarFactory)
	local function makeQuestNpc(npcName: string, displayName: string, position: Vector3, facing: Vector3, config: { [string]: any })
		task.spawn(function()
			local model = AvatarFactory.createStatic({
				name = displayName,
				shirtId = config.shirtId,
				pantsId = config.pantsId,
				skin = config.skin,
				position = position,
				facing = facing,
				body = config.body,
				shape = config.shape,
				hairId = config.hairId,
				gestures = true,
			})
			if not model then
				return
			end
			model:SetAttribute("NpcName", npcName)
			local torso = model:FindFirstChild("UpperTorso") or model.PrimaryPart
			if torso then
				local prompt = Instance.new("ProximityPrompt")
				prompt.ActionText = "Talk"
				prompt.ObjectText = displayName
				prompt.HoldDuration = 0
				prompt.MaxActivationDistance = 8
				prompt.Parent = torso
			end
			CollectionService:AddTag(model, "NPC")
		end)
	end
	makeQuestNpc("Mira", "Mira", Vector3.new(6, 0.5, -45), -Vector3.xAxis, {
		shirtId = 18715074963, -- tavern dress
		pantsId = 18715064441,
		skin = Color3.fromRGB(255, 219, 172),
		body = "fem",
		shape = "average",
		hairId = 110290888975881, -- brown wavy
	})
	makeQuestNpc("Daren", "Daren", Vector3.new(10, 0.5, -35), -Vector3.xAxis, {
		shirtId = 5834523569, -- medieval work shirt
		pantsId = 13124170939,
		skin = Color3.fromRGB(214, 173, 130),
		body = "masc",
		shape = "heavy",
		hairId = 62234425, -- brown
	})

	village.Parent = workspace
	return village
end

return VillageBuilder
