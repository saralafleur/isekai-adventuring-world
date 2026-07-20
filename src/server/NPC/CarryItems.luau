--!strict
-- Visible hand-held purchases for NPCs: after browsing a market stall, an NPC
-- can walk away holding what that stall sells. Items weld to the right hand
-- and are removed at the next destination.

local CarryItems = {}

type ItemBuilder = (hand: BasePart) -> { BasePart }

local CLOTH_COLORS = {
	Color3.fromRGB(160, 60, 70),
	Color3.fromRGB(70, 110, 160),
	Color3.fromRGB(190, 160, 80),
	Color3.fromRGB(90, 140, 90),
}

local function makePart(size: Vector3, color: Color3, material: Enum.Material, cf: CFrame): BasePart
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.Material = material
	p.CanCollide = false
	p.Massless = true
	p.CFrame = cf
	return p
end

local BUILDERS: { [string]: ItemBuilder } = {
	bread = function(hand)
		return {
			makePart(Vector3.new(1.6, 0.55, 0.55), Color3.fromRGB(196, 150, 90), Enum.Material.Sand, hand.CFrame * CFrame.new(0, -0.5, 0) * CFrame.Angles(0, 0, math.rad(90))),
		}
	end,
	produce = function(hand)
		local basket = makePart(Vector3.new(1.1, 0.6, 1.1), Color3.fromRGB(150, 116, 70), Enum.Material.WoodPlanks, hand.CFrame * CFrame.new(0, -0.7, 0))
		local apples = makePart(Vector3.new(0.9, 0.4, 0.9), Color3.fromRGB(200, 60, 55), Enum.Material.SmoothPlastic, hand.CFrame * CFrame.new(0, -0.35, 0))
		return { basket, apples }
	end,
	fish = function(hand)
		return {
			makePart(Vector3.new(0.35, 0.5, 1.9), Color3.fromRGB(140, 155, 165), Enum.Material.SmoothPlastic, hand.CFrame * CFrame.new(0, -0.5, 0.3)),
		}
	end,
	cloth = function(hand)
		local roll = Instance.new("Part")
		roll.Shape = Enum.PartType.Cylinder
		roll.Size = Vector3.new(1.8, 0.6, 0.6)
		roll.Color = CLOTH_COLORS[math.random(1, #CLOTH_COLORS)]
		roll.Material = Enum.Material.Fabric
		roll.CanCollide = false
		roll.Massless = true
		roll.CFrame = hand.CFrame * CFrame.new(0, -0.5, 0.2) * CFrame.Angles(0, 0, math.rad(90))
		return { roll }
	end,
	pottery = function(hand)
		local pot = Instance.new("Part")
		pot.Shape = Enum.PartType.Cylinder
		pot.Size = Vector3.new(0.9, 0.85, 0.85)
		pot.Color = Color3.fromRGB(168, 110, 72)
		pot.Material = Enum.Material.SmoothPlastic
		pot.CanCollide = false
		pot.Massless = true
		pot.CFrame = hand.CFrame * CFrame.new(0, -0.6, 0) * CFrame.Angles(0, 0, math.rad(90))
		return { pot }
	end,
	flowers = function(hand)
		local stems = makePart(Vector3.new(0.16, 1, 0.16), Color3.fromRGB(80, 120, 60), Enum.Material.Grass, hand.CFrame * CFrame.new(0, -0.3, 0))
		local bloom = Instance.new("Part")
		bloom.Shape = Enum.PartType.Ball
		bloom.Size = Vector3.new(0.7, 0.7, 0.7)
		bloom.Color = Color3.fromRGB(230, 120, 150)
		bloom.Material = Enum.Material.Grass
		bloom.CanCollide = false
		bloom.Massless = true
		bloom.CFrame = hand.CFrame * CFrame.new(0, 0.25, 0)
		return { stems, bloom }
	end,
	potion = function(hand)
		local bottle = makePart(Vector3.new(0.5, 0.9, 0.5), Color3.fromRGB(90, 180, 110), Enum.Material.Glass, hand.CFrame * CFrame.new(0, -0.5, 0))
		bottle.Transparency = 0.25
		local cork = makePart(Vector3.new(0.25, 0.3, 0.25), Color3.fromRGB(150, 116, 70), Enum.Material.Wood, hand.CFrame * CFrame.new(0, 0.05, 0))
		return { bottle, cork }
	end,
	book = function(hand)
		return {
			makePart(Vector3.new(1.1, 0.35, 1.5), Color3.fromRGB(90, 60, 50), Enum.Material.Leather, hand.CFrame * CFrame.new(0, -0.5, 0.2)),
		}
	end,
	parcel = function(hand)
		return {
			makePart(Vector3.new(1, 0.8, 1), Color3.fromRGB(170, 140, 100), Enum.Material.Cardboard, hand.CFrame * CFrame.new(0, -0.55, 0)),
		}
	end,
}

-- Attaches the item to the model's right hand; returns a folder holding the
-- parts (destroy it to remove the item).
function CarryItems.attach(model: Model, kind: string): Folder?
	local hand = model:FindFirstChild("RightHand") :: BasePart?
	local builder = BUILDERS[kind]
	if not hand or not builder then
		return nil
	end
	local folder = Instance.new("Folder")
	folder.Name = "CarriedItem"
	for _, p in builder(hand) do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hand
		weld.Part1 = p
		weld.Parent = p
		p.Parent = folder
	end
	folder.Parent = model
	return folder
end

function CarryItems.detach(model: Model)
	local existing = model:FindFirstChild("CarriedItem")
	if existing then
		existing:Destroy()
	end
end

return CarryItems
