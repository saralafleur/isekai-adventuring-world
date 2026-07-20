--!strict
-- Village map: press M to toggle. A stylized top-down parchment map of Briar
-- Glen — tinted districts, named roads, markers for major locations, a live
-- player dot, and a compass. Pure Gui drawing (no renders): world (x,z) maps
-- into a square frame, north (+z) up.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local MapUI = {}

-- World bounds shown on the map
local MIN_X, MAX_X = -230, 230
local MIN_Z, MAX_Z = -240, 280

local PARCHMENT = Color3.fromRGB(226, 210, 178)
local FOREST_EDGE = Color3.fromRGB(96, 128, 84)
local ROAD_COLOR = Color3.fromRGB(150, 120, 88)
local LABEL_COLOR = Color3.fromRGB(70, 52, 36)

local gui: ScreenGui
local mapFrame: Frame
local playerDot: Frame
local renderConn: RBXScriptConnection? = nil

local function toScale(x: number, z: number): (number, number)
	return (x - MIN_X) / (MAX_X - MIN_X), 1 - (z - MIN_Z) / (MAX_Z - MIN_Z)
end

local function districtZone(x0: number, z0: number, x1: number, z1: number, color: Color3, transparency: number)
	local sx0, sy1 = toScale(x0, z0)
	local sx1, sy0 = toScale(x1, z1)
	local zone = Instance.new("Frame")
	zone.Position = UDim2.fromScale(sx0, sy0)
	zone.Size = UDim2.fromScale(sx1 - sx0, sy1 - sy0)
	zone.BackgroundColor3 = color
	zone.BackgroundTransparency = transparency
	zone.BorderSizePixel = 0
	zone.ZIndex = 2
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = zone
	zone.Parent = mapFrame
end

local function roadLine(x0: number, z0: number, x1: number, z1: number, thickness: number)
	local sx0, sy0 = toScale(x0, z0)
	local sx1, sy1 = toScale(x1, z1)
	local dx, dy = sx1 - sx0, sy1 - sy0
	local length = math.sqrt(dx * dx + dy * dy)
	local line = Instance.new("Frame")
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Position = UDim2.fromScale((sx0 + sx1) / 2, (sy0 + sy1) / 2)
	line.Size = UDim2.fromScale(length, thickness)
	line.Rotation = math.deg(math.atan2(dy, dx))
	line.BackgroundColor3 = ROAD_COLOR
	line.BorderSizePixel = 0
	line.ZIndex = 3
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = line
	line.Parent = mapFrame
end

local function roadPath(points: { { number } }, thickness: number)
	for i = 1, #points - 1 do
		roadLine(points[i][1], points[i][2], points[i + 1][1], points[i + 1][2], thickness)
	end
end

local function label(x: number, z: number, text: string, size: number, bold: boolean, rotation: number?)
	local sx, sy = toScale(x, z)
	local textLabel = Instance.new("TextLabel")
	textLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	textLabel.Position = UDim2.fromScale(sx, sy)
	textLabel.Size = UDim2.fromScale(0.3, 0.05)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = text
	textLabel.Font = if bold then Enum.Font.Merriweather else Enum.Font.Gotham
	textLabel.TextScaled = false
	textLabel.TextSize = size
	textLabel.TextColor3 = LABEL_COLOR
	textLabel.TextStrokeColor3 = PARCHMENT
	textLabel.TextStrokeTransparency = 0.4
	textLabel.Rotation = rotation or 0
	textLabel.ZIndex = 6
	textLabel.Parent = mapFrame
end

local function marker(x: number, z: number, color: Color3, labelText: string, labelDx: number?, labelDz: number?)
	local sx, sy = toScale(x, z)
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(sx, sy)
	dot.Size = UDim2.fromOffset(10, 10)
	dot.BackgroundColor3 = color
	dot.BorderSizePixel = 0
	dot.ZIndex = 5
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = dot
	local stroke = Instance.new("UIStroke")
	stroke.Color = LABEL_COLOR
	stroke.Thickness = 1.4
	stroke.Parent = dot
	dot.Parent = mapFrame
	label(x + (labelDx or 0), z + (labelDz or -14), labelText, 13, false)
end

local function buildMap()
	gui = Instance.new("ScreenGui")
	gui.Name = "MapGui"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 60

	-- dim the world behind the map
	local dim = Instance.new("Frame")
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.45
	dim.BorderSizePixel = 0
	dim.Parent = gui

	-- square map panel: forest-green border wrapping a parchment field
	local border = Instance.new("Frame")
	border.AnchorPoint = Vector2.new(0.5, 0.5)
	border.Position = UDim2.fromScale(0.5, 0.5)
	border.Size = UDim2.fromScale(0.78, 0.78)
	border.SizeConstraint = Enum.SizeConstraint.RelativeYY
	border.BackgroundColor3 = FOREST_EDGE
	border.BorderSizePixel = 0
	border.Parent = gui
	local borderCorner = Instance.new("UICorner")
	borderCorner.CornerRadius = UDim.new(0, 18)
	borderCorner.Parent = border
	local borderStroke = Instance.new("UIStroke")
	borderStroke.Color = Color3.fromRGB(52, 40, 28)
	borderStroke.Thickness = 3
	borderStroke.Parent = border

	mapFrame = Instance.new("Frame")
	mapFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	mapFrame.Position = UDim2.fromScale(0.5, 0.5)
	mapFrame.Size = UDim2.fromScale(0.94, 0.94)
	mapFrame.BackgroundColor3 = PARCHMENT
	mapFrame.BorderSizePixel = 0
	mapFrame.ClipsDescendants = true
	mapFrame.Parent = border
	local mapCorner = Instance.new("UICorner")
	mapCorner.CornerRadius = UDim.new(0, 12)
	mapCorner.Parent = mapFrame

	-- title + close hint + compass
	local title = Instance.new("TextLabel")
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.new(0.5, 0, 0, 6)
	title.Size = UDim2.fromScale(0.6, 0.07)
	title.BackgroundTransparency = 1
	title.Text = "~ BRIAR GLEN ~"
	title.Font = Enum.Font.Merriweather
	title.TextScaled = true
	title.TextColor3 = LABEL_COLOR
	title.ZIndex = 7
	title.Parent = mapFrame

	local hint = Instance.new("TextLabel")
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -6)
	hint.Size = UDim2.fromScale(0.5, 0.04)
	hint.BackgroundTransparency = 1
	hint.Text = "Press M to close"
	hint.Font = Enum.Font.Gotham
	hint.TextScaled = true
	hint.TextColor3 = LABEL_COLOR
	hint.TextTransparency = 0.3
	hint.ZIndex = 7
	hint.Parent = mapFrame

	local compass = Instance.new("TextLabel")
	compass.Position = UDim2.new(0, 12, 0, 8)
	compass.Size = UDim2.fromOffset(34, 40)
	compass.BackgroundTransparency = 1
	compass.Text = "▲\nN"
	compass.Font = Enum.Font.GothamBold
	compass.TextSize = 16
	compass.TextColor3 = LABEL_COLOR
	compass.ZIndex = 7
	compass.Parent = mapFrame

	-- district tints
	districtZone(-110, 80, 110, 245, Color3.fromRGB(214, 190, 160), 0.55) -- residential north
	districtZone(-70, 20, 70, 80, Color3.fromRGB(210, 176, 120), 0.45) -- market
	districtZone(66, 14, 200, 86, Color3.fromRGB(196, 170, 140), 0.5) -- shopping
	districtZone(-200, 14, -66, 86, Color3.fromRGB(180, 172, 160), 0.5) -- industry
	districtZone(-115, -170, 85, -40, Color3.fromRGB(206, 196, 132), 0.5) -- farmland

	-- district names
	label(0, 235, "RESIDENTIAL", 14, true)
	label(133, 78, "SHOPPING", 14, true)
	label(-133, 78, "INDUSTRY", 14, true)
	label(-15, -160, "FARMSTEAD", 14, true)

	-- roads (drawn under markers)
	roadPath({ { 0, -235 }, { 0, 275 } }, 0.014) -- King's Road
	roadPath({ { 66, 50 }, { 185, 50 } }, 0.012) -- Merchant Row
	roadPath({ { -66, 50 }, { -185, 50 } }, 0.012) -- Forge Row
	roadPath({ { 28, 32 }, { 52, 27 }, { 72, 46 } }, 0.008)
	roadPath({ { -28, 32 }, { -52, 27 }, { -72, 46 } }, 0.008)
	roadPath({ { -26, 80 }, { -46, 104 }, { -64, 134 }, { -78, 174 } }, 0.009) -- Hearth Lane
	roadPath({ { 26, 80 }, { 46, 104 }, { 64, 134 }, { 78, 174 } }, 0.009) -- Willow Lane
	roadPath({ { -70, 200 }, { -30, 217 }, { 30, 217 }, { 70, 200 } }, 0.008) -- Crescent Way
	roadPath({ { -70, -60 }, { 70, -60 } }, 0.009) -- Harvest Lane
	roadPath({ { 20, -20 }, { 20, -60 } }, 0.007)

	-- road names (angled roughly along their roads)
	label(12, -110, "King's Road", 13, true, 90)
	label(126, 42, "Merchant Row", 13, true)
	label(-126, 42, "Forge Row", 13, true)
	label(-64, 118, "Hearth Lane", 12, true, 55)
	label(64, 118, "Willow Lane", 12, true, -55)
	label(0, 210, "Crescent Way", 12, true)
	label(-30, -52, "Harvest Lane", 12, true)

	-- major locations
	marker(0, 50, Color3.fromRGB(220, 170, 60), "Market Plaza", 0, 16)
	marker(-52, 55, Color3.fromRGB(180, 60, 60), "Adventurers' Guild", -34, 14)
	marker(52, 55, Color3.fromRGB(70, 110, 180), "Merchants' Guild", 36, 14)
	marker(0, 120, Color3.fromRGB(150, 130, 190), "Town Hall", 26, 4)
	marker(-42, 2, Color3.fromRGB(110, 105, 100), "Smithy", -22, -6)
	marker(0, -40, Color3.fromRGB(200, 80, 60), "Home", 18, 2)
	marker(45, -80, Color3.fromRGB(152, 60, 48), "Barn", 18, -4)
	marker(-90, -140, Color3.fromRGB(150, 142, 130), "Windmill", 0, -14)
	marker(0, -188, Color3.fromRGB(96, 72, 48), "South Gate", 0, -14)
	marker(0, 240, Color3.fromRGB(96, 72, 48), "North Gate", 0, 14)

	-- player dot (updated live while the map is open)
	playerDot = Instance.new("Frame")
	playerDot.AnchorPoint = Vector2.new(0.5, 0.5)
	playerDot.Size = UDim2.fromOffset(12, 12)
	playerDot.BackgroundColor3 = Color3.fromRGB(230, 50, 40)
	playerDot.BorderSizePixel = 0
	playerDot.ZIndex = 8
	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(1, 0)
	dotCorner.Parent = playerDot
	local dotStroke = Instance.new("UIStroke")
	dotStroke.Color = Color3.new(1, 1, 1)
	dotStroke.Thickness = 2
	dotStroke.Parent = playerDot
	playerDot.Parent = mapFrame
	label(0, 0, "", 1, false) -- spacer no-op keeps layout simple

	gui.Parent = player:WaitForChild("PlayerGui")
end

local function setOpen(open: boolean)
	gui.Enabled = open
	if open then
		renderConn = RunService.RenderStepped:Connect(function()
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local sx, sy = toScale(root.Position.X, root.Position.Z)
				playerDot.Position = UDim2.fromScale(math.clamp(sx, 0, 1), math.clamp(sy, 0, 1))
			end
		end)
	elseif renderConn then
		renderConn:Disconnect()
		renderConn = nil
	end
end

function MapUI.init()
	buildMap()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.M then
			setOpen(not gui.Enabled)
		end
	end)

	-- small persistent hint so the feature is discoverable
	local hintGui = Instance.new("ScreenGui")
	hintGui.Name = "MapHintGui"
	hintGui.ResetOnSpawn = false
	local hintLabel = Instance.new("TextLabel")
	hintLabel.AnchorPoint = Vector2.new(0, 1)
	hintLabel.Position = UDim2.new(0, 14, 1, -12)
	hintLabel.Size = UDim2.fromOffset(110, 22)
	hintLabel.BackgroundColor3 = Color3.fromRGB(25, 22, 30)
	hintLabel.BackgroundTransparency = 0.35
	hintLabel.Text = "M — Map"
	hintLabel.Font = Enum.Font.Gotham
	hintLabel.TextSize = 14
	hintLabel.TextColor3 = Color3.fromRGB(230, 225, 215)
	local hintCorner = Instance.new("UICorner")
	hintCorner.CornerRadius = UDim.new(0, 6)
	hintCorner.Parent = hintLabel
	hintLabel.Parent = hintGui
	hintGui.Parent = player:WaitForChild("PlayerGui")
end

return MapUI
