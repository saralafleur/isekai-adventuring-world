--!strict
-- Shared avatar generation for every NPC (villagers, shopkeepers, travelers).
-- Bodies use Roblox's official human-contoured Man/Woman body parts instead of
-- the default blocky rig, morphed toward human proportions, with three body
-- shapes (heavy / average / thin) so the population reads as real people.

local Players = game:GetService("Players")

local IDLE_ANIM = "rbxassetid://507766388"

-- Official free Roblox bundles: "Man" (238) and "Woman" (239) body parts
local BODY_PARTS = {
	masc = {
		Torso = 86500008,
		RightArm = 86500036,
		LeftArm = 86500054,
		LeftLeg = 86500064,
		RightLeg = 86500078,
	},
	fem = {
		Torso = 86499666,
		RightArm = 86499698,
		LeftArm = 86499716,
		LeftLeg = 86499753,
		RightLeg = 86499793,
	},
}

-- Body archetypes: scales multiply the persona's own height/width tweaks
local SHAPES = {
	heavy = { bodyType = 0.65, width = 1.28, depth = 1.3, proportion = 0.1 },
	average = { bodyType = 0.75, width = 1.0, depth = 1.05, proportion = 0.4 },
	thin = { bodyType = 0.85, width = 0.82, depth = 0.88, proportion = 0.85 },
}

local AvatarFactory = {}

export type BodyKind = "masc" | "fem"
export type BodyShape = "heavy" | "average" | "thin"

export type DescribeOpts = {
	shirtId: number,
	pantsId: number,
	skin: Color3,
	heightScale: number?,
	widthScale: number?,
	hairId: number?,
	hatId: number?,
	body: BodyKind?,
	shape: BodyShape?,
}

function AvatarFactory.describe(opts: DescribeOpts): HumanoidDescription
	local description = Instance.new("HumanoidDescription")
	description.Shirt = opts.shirtId
	description.Pants = opts.pantsId

	local shape = SHAPES[opts.shape or "average"]
	description.BodyTypeScale = shape.bodyType
	description.ProportionScale = shape.proportion
	description.WidthScale = (opts.widthScale or 1) * shape.width
	description.DepthScale = shape.depth
	description.HeightScale = opts.heightScale or 1

	local parts = BODY_PARTS[opts.body or "masc"]
	description.Torso = parts.Torso
	description.RightArm = parts.RightArm
	description.LeftArm = parts.LeftArm
	description.LeftLeg = parts.LeftLeg
	description.RightLeg = parts.RightLeg

	description.HeadColor = opts.skin
	description.TorsoColor = opts.skin
	description.LeftArmColor = opts.skin
	description.RightArmColor = opts.skin
	description.LeftLegColor = opts.skin
	description.RightLegColor = opts.skin

	if opts.hairId then
		description.HairAccessory = tostring(opts.hairId)
	end
	if opts.hatId then
		description.HatAccessory = tostring(opts.hatId)
	end
	return description
end

export type StaticAvatarConfig = {
	name: string,
	shirtId: number,
	pantsId: number,
	skin: Color3,
	position: Vector3,
	facing: Vector3,
	heightScale: number?,
	widthScale: number?,
	hairId: number?,
	hatId: number?,
	body: BodyKind?,
	shape: BodyShape?,
}

function AvatarFactory.createStatic(config: StaticAvatarConfig): Model?
	local description = AvatarFactory.describe({
		shirtId = config.shirtId,
		pantsId = config.pantsId,
		skin = config.skin,
		heightScale = config.heightScale,
		widthScale = config.widthScale,
		hairId = config.hairId,
		hatId = config.hatId,
		body = config.body,
		shape = config.shape,
	})

	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn(`[AvatarFactory] failed to create {config.name}: {model}`)
		return nil
	end

	model.Name = config.name
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.HealthDisplayDistance = 0
	humanoid.NameDisplayDistance = 50

	local root = model.PrimaryPart :: BasePart
	model:PivotTo(CFrame.lookAlong(config.position + Vector3.new(0, 3.2, 0), config.facing))
	root.Anchored = true
	model.Parent = workspace

	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local idleAnim = Instance.new("Animation")
	idleAnim.AnimationId = IDLE_ANIM
	local idleTrack = animator:LoadAnimation(idleAnim)
	idleTrack.Priority = Enum.AnimationPriority.Idle
	idleTrack.Looped = true
	idleTrack:Play()

	return model
end

return AvatarFactory
