--!strict
-- The Holt smithy: open-front lean-to workshop between the hamlet and the
-- plaza. Forge with glowing coals and smoke, anvil, quench barrel. The
-- blacksmith NPC works at the tagged ForgeSpot / AnvilSpot markers.
-- Footprint: x -50..-34, z -6..10, open side facing east (+X).

local PartUtil = require(script.Parent.PartUtil)
local part = PartUtil.part

local STONE_COLOR = Color3.fromRGB(130, 126, 120)
local BEAM_COLOR = Color3.fromRGB(74, 52, 34)

local SmithyBuilder = {}

function SmithyBuilder.build(parentFolder: Instance): Model
	local smithy = Instance.new("Model")
	smithy.Name = "Smithy"

	-- Stone floor
	part({
		Name = "SmithyFloor",
		Size = Vector3.new(16, 0.5, 16),
		Position = Vector3.new(-42, 0.25, 2),
		Color = Color3.fromRGB(110, 106, 100),
		Material = Enum.Material.Slate,
	}).Parent = smithy

	-- Three walls (west/back, north, south); east side open
	part({ Name = "WallW", Size = Vector3.new(1, 7.2, 16), Position = Vector3.new(-50, 4.05, 2), Color = STONE_COLOR, Material = Enum.Material.Cobblestone }).Parent = smithy
	part({ Name = "WallN", Size = Vector3.new(16, 7.2, 1), Position = Vector3.new(-42, 4.05, 10), Color = STONE_COLOR, Material = Enum.Material.Cobblestone }).Parent = smithy
	part({ Name = "WallS", Size = Vector3.new(16, 7.2, 1), Position = Vector3.new(-42, 4.05, -6), Color = STONE_COLOR, Material = Enum.Material.Cobblestone }).Parent = smithy

	-- Open-front posts
	for _, z in { -5.5, 9.5 } do
		part({
			Name = "SmithyPost",
			Size = Vector3.new(0.8, 9.8, 0.8),
			Position = Vector3.new(-34, 4.9, z),
			Color = BEAM_COLOR,
			Material = Enum.Material.Wood,
		}).Parent = smithy
	end

	-- Lean-to roof, high at the open east side, sloping down to the back
	part({
		Name = "SmithyRoof",
		Size = Vector3.new(19.5, 0.4, 18.5),
		CFrame = CFrame.new(-42, 8.9, 2) * CFrame.Angles(0, 0, math.rad(7)),
		Color = Color3.fromRGB(88, 78, 72),
		Material = Enum.Material.RoofShingles,
	}).Parent = smithy

	-- Forge hearth against the back wall
	part({
		Name = "ForgeHearth",
		Size = Vector3.new(4, 3, 4),
		Position = Vector3.new(-47, 1.5, -2),
		Color = STONE_COLOR,
		Material = Enum.Material.Cobblestone,
	}).Parent = smithy
	local coals = part({
		Name = "ForgeCoals",
		Size = Vector3.new(3, 0.4, 3),
		Position = Vector3.new(-47, 3.3, -2),
		Color = Color3.fromRGB(255, 120, 40),
		Material = Enum.Material.Neon,
	})
	local forgeLight = Instance.new("PointLight")
	forgeLight.Color = Color3.fromRGB(255, 140, 60)
	forgeLight.Brightness = 2
	forgeLight.Range = 16
	forgeLight.Parent = coals
	local forgeSmoke = Instance.new("ParticleEmitter")
	forgeSmoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	forgeSmoke.Rate = 4
	forgeSmoke.Lifetime = NumberRange.new(1.5, 3)
	forgeSmoke.Speed = NumberRange.new(2, 3)
	forgeSmoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(1, 2.5),
	})
	forgeSmoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	forgeSmoke.Color = ColorSequence.new(Color3.fromRGB(90, 90, 90))
	forgeSmoke.Parent = coals
	coals.Parent = smithy

	-- Anvil (base + horn), center of the shop
	part({
		Name = "AnvilBase",
		Size = Vector3.new(1.4, 1, 1.4),
		Position = Vector3.new(-42, 1, -1),
		Color = Color3.fromRGB(70, 68, 66),
		Material = Enum.Material.Metal,
	}).Parent = smithy
	local anvilTop = part({
		Name = "AnvilTop",
		Size = Vector3.new(1, 0.6, 2.6),
		Position = Vector3.new(-42, 1.8, -1),
		Color = Color3.fromRGB(90, 88, 86),
		Material = Enum.Material.Metal,
	})
	-- Spark burst for hammer strikes (emitted by the blacksmith's work loop)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Enabled = false
	sparks.Rate = 0
	sparks.Lifetime = NumberRange.new(0.2, 0.5)
	sparks.Speed = NumberRange.new(8, 14)
	sparks.SpreadAngle = Vector2.new(60, 60)
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 190, 80))
	sparks.LightEmission = 1
	sparks.Parent = anvilTop
	anvilTop.Parent = smithy

	-- Quench barrel
	part({
		Name = "QuenchBarrel",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.4, 2.4, 2.4),
		CFrame = CFrame.new(-38, 1.7, 7) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(110, 78, 48),
		Material = Enum.Material.WoodPlanks,
	}).Parent = smithy

	-- Weapon rack against the north wall
	part({ Name = "RackBoard", Size = Vector3.new(5, 3, 0.4), Position = Vector3.new(-44, 3.5, 9.3), Color = BEAM_COLOR, Material = Enum.Material.Wood }).Parent = smithy
	for i = 0, 2 do
		part({
			Name = "RackBlade",
			Size = Vector3.new(0.3, 2.4, 0.15),
			Position = Vector3.new(-45.5 + i * 1.5, 3.5, 9.05),
			Color = Color3.fromRGB(180, 180, 190),
			Material = Enum.Material.Metal,
			CanCollide = false,
		}).Parent = smithy
	end

	-- Signage: "Holt Forge & Anvil" hung at the open east front
	local function smithyFace(board: BasePart, face: Enum.NormalId)
		local surface = Instance.new("SurfaceGui")
		surface.Face = face
		surface.CanvasSize = Vector2.new(60 * board.Size.Z, 60 * board.Size.Y)
		surface.Parent = board
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(0.94, 0.8)
		text.Position = UDim2.fromScale(0.03, 0.1)
		text.BackgroundTransparency = 1
		text.Text = "Holt Forge & Anvil"
		text.Font = Enum.Font.Merriweather
		text.TextScaled = true
		text.TextColor3 = Color3.fromRGB(246, 226, 160)
		text.TextStrokeColor3 = Color3.fromRGB(40, 28, 16)
		text.TextStrokeTransparency = 0.35
		text.Parent = surface
	end
	part({ Name = "SmithySignBracket", Size = Vector3.new(3.4, 0.3, 0.3), Position = Vector3.new(-32.6, 9.2, 2), Color = Color3.fromRGB(60, 58, 55), Material = Enum.Material.Metal }).Parent = smithy
	for _, dz in { -2.6, 2.6 } do
		part({ Name = "SmithySignChain", Size = Vector3.new(0.16, 1.1, 0.16), Position = Vector3.new(-31.1, 8.6, 2 + dz), Color = Color3.fromRGB(60, 58, 55), Material = Enum.Material.Metal, CanCollide = false }).Parent = smithy
	end
	local smithyBoard = part({
		Name = "SmithySign",
		Size = Vector3.new(0.4, 2.2, 7),
		Position = Vector3.new(-31.1, 6.9, 2),
		Color = Color3.fromRGB(92, 64, 40),
		Material = Enum.Material.WoodPlanks,
	})
	smithyFace(smithyBoard, Enum.NormalId.Right)
	smithyFace(smithyBoard, Enum.NormalId.Left)
	smithyBoard.Parent = smithy

	-- NPC work markers: blacksmith stands west of the anvil facing it
	PartUtil.marker("AnvilSpot", Vector3.new(-43.9, 0.9, -1)).Parent = smithy
	-- Onlookers can watch from the open side
	PartUtil.marker("SmithyWatchSpot", Vector3.new(-32, 0.5, 2)).Parent = smithy

	smithy.Parent = parentFolder
	return smithy
end

return SmithyBuilder
