--!strict
-- Opening flyby: one continuous camera glide over the whole village — farm,
-- fields, windmill, market plaza, town hall — then back through the cottage
-- doorway and smoothly INTO the back of the player's head, ending in first
-- person. Catmull-Rom splines for position and look-target give constant,
-- never-stopping motion. Clicking accelerates the flight instead of cutting,
-- so the ending is always seamless.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local FlybyCinematic = {}

local DURATION = 30
local SKIP_SPEED = 6

-- Fixed route (positions/looks); the final door-and-head points are appended
-- at runtime from the character's actual position and facing.
local ROUTE_POS = {
	Vector3.new(0, 150, -230), -- high over the southern farmland
	Vector3.new(-160, 95, -80), -- wheat fields and windmill
	Vector3.new(-30, 45, -75), -- over the cottage
	Vector3.new(0, 40, -5), -- following the road north
	Vector3.new(48, 32, 50), -- market plaza and guild banners
	Vector3.new(0, 58, 168), -- the town hall
	Vector3.new(-60, 48, 55), -- sweeping back west
	Vector3.new(0, 28, 0), -- descending over the path home
	Vector3.new(1, 9, -14), -- lining up on the cottage door
	Vector3.new(0, 5.8, -26.6), -- through the doorway
}
local ROUTE_LOOK = {
	Vector3.new(0, 0, -40),
	Vector3.new(-100, 10, -140),
	Vector3.new(0, 6, -40),
	Vector3.new(0, 4, 50),
	Vector3.new(0, 6, 52),
	Vector3.new(0, 18, 120),
	Vector3.new(-15, 6, 15),
	Vector3.new(0, 6, -20),
	Vector3.new(0, 5.5, -28),
	Vector3.new(-4, 5, -38), -- into the room
}

local function catmullRom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number): Vector3
	local t2 = t * t
	local t3 = t2 * t
	return 0.5
		* ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
end

-- Samples a Catmull-Rom spline through `points` into a dense polyline.
local function samplePath(points: { Vector3 }, perSegment: number): { Vector3 }
	local samples = {}
	local count = #points
	for segment = 1, count - 1 do
		local p0 = points[math.max(segment - 1, 1)]
		local p1 = points[segment]
		local p2 = points[segment + 1]
		local p3 = points[math.min(segment + 2, count)]
		for step = 0, perSegment - 1 do
			table.insert(samples, catmullRom(p0, p1, p2, p3, step / perSegment))
		end
	end
	table.insert(samples, points[count])
	return samples
end

-- Arc-length lookup so playback speed is uniform regardless of segment length
local function buildArcTable(samples: { Vector3 }): ({ number }, number)
	local cumulative = { 0 }
	local total = 0
	for i = 2, #samples do
		total += (samples[i] - samples[i - 1]).Magnitude
		cumulative[i] = total
	end
	return cumulative, total
end

local function sampleAtDistance(samples: { Vector3 }, cumulative: { number }, distance: number): Vector3
	if distance <= 0 then
		return samples[1]
	end
	local count = #samples
	if distance >= cumulative[count] then
		return samples[count]
	end
	-- binary search for the bracketing samples
	local lo, hi = 1, count
	while hi - lo > 1 do
		local mid = (lo + hi) // 2
		if cumulative[mid] <= distance then
			lo = mid
		else
			hi = mid
		end
	end
	local span = cumulative[hi] - cumulative[lo]
	local alpha = if span > 0 then (distance - cumulative[lo]) / span else 0
	return samples[lo]:Lerp(samples[hi], alpha)
end

local function smoothstep(t: number): number
	return t * t * (3 - 2 * t)
end

function FlybyCinematic.play(blackGui: ScreenGui?)
	local camera = workspace.CurrentCamera
	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	local head = character:WaitForChild("Head") :: BasePart

	root.Anchored = true
	local headPos = head.Position
	local facing = root.CFrame.LookVector

	-- Complete the route with runtime points: behind the player, then the head
	local posPoints = table.clone(ROUTE_POS)
	table.insert(posPoints, headPos - facing * 5) -- directly behind the head
	table.insert(posPoints, headPos) -- inside the head: first person
	local lookPoints = table.clone(ROUTE_LOOK)
	table.insert(lookPoints, headPos + facing * 2)
	table.insert(lookPoints, headPos + facing * 10) -- ends looking where the player looks

	local posSamples = samplePath(posPoints, 24)
	local lookSamples = samplePath(lookPoints, 24)
	local posArc, posTotal = buildArcTable(posSamples)
	local lookArc, lookTotal = buildArcTable(lookSamples)

	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(posSamples[1], lookSamples[1])

	-- Skip = accelerate (keeps the motion continuous all the way into the head)
	local speedup = 1
	local skipGui = Instance.new("ScreenGui")
	skipGui.Name = "FlybySkipGui"
	skipGui.ResetOnSpawn = false
	skipGui.DisplayOrder = 90
	local skipLabel = Instance.new("TextLabel")
	skipLabel.AnchorPoint = Vector2.new(1, 1)
	skipLabel.Position = UDim2.new(1, -24, 1, -20)
	skipLabel.Size = UDim2.fromOffset(220, 24)
	skipLabel.BackgroundTransparency = 1
	skipLabel.Text = "Click to skip"
	skipLabel.TextXAlignment = Enum.TextXAlignment.Right
	skipLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
	skipLabel.TextStrokeTransparency = 0.5
	skipLabel.Font = Enum.Font.Gotham
	skipLabel.TextSize = 16
	skipLabel.Parent = skipGui
	skipGui.Parent = player:WaitForChild("PlayerGui")
	local conn = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			speedup = SKIP_SPEED
			skipLabel.Text = ""
		end
	end)

	-- Fade in from black while already gliding
	if blackGui then
		local frame = blackGui:FindFirstChildOfClass("Frame")
		if frame then
			TweenService:Create(frame, TweenInfo.new(2), { BackgroundTransparency = 1 }):Play()
			task.delay(2.1, function()
				blackGui:Destroy()
			end)
		end
	end

	-- One continuous glide, parameterized by arc length
	local characterParts: { BasePart } = {}
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			table.insert(characterParts, part)
		end
	end

	local elapsed = 0
	while elapsed < DURATION do
		local dt = RunService.RenderStepped:Wait()
		elapsed += dt * speedup
		local progress = smoothstep(math.clamp(elapsed / DURATION, 0, 1))
		local pos = sampleAtDistance(posSamples, posArc, posTotal * progress)
		local look = sampleAtDistance(lookSamples, lookArc, lookTotal * progress)
		if (look - pos).Magnitude > 0.05 then
			camera.CFrame = CFrame.lookAt(pos, look)
		end
		-- Fade the character out as the camera closes the last few studs so
		-- backing into the head never shows clipping geometry
		local headDistance = (pos - headPos).Magnitude
		local fade = 1 - math.clamp(headDistance / 6, 0, 1)
		for _, part in characterParts do
			part.LocalTransparencyModifier = fade
		end
	end

	conn:Disconnect()
	skipGui:Destroy()
	-- Hand off in true first person: clamp the zoom to minimum for one frame so
	-- the Custom camera snaps inside the head, then restore the max so the
	-- player can scroll out to third person whenever they like.
	player.CameraMaxZoomDistance = 0.5
	player.CameraMinZoomDistance = 0.5
	camera.CameraType = Enum.CameraType.Custom
	for _, part in characterParts do
		part.LocalTransparencyModifier = 0
	end
	root.Anchored = false
	task.delay(0.3, function()
		player.CameraMaxZoomDistance = 128
	end)
end

return FlybyCinematic
