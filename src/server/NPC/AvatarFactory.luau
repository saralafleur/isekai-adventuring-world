--!strict
-- Creates stationary R15 avatar NPCs (shopkeepers etc.) from catalog outfits.
-- These stand in place with the idle animation; interaction is added by the
-- service that owns them.

local Players = game:GetService("Players")

local IDLE_ANIM = "rbxassetid://507766388"

local AvatarFactory = {}

export type StaticAvatarConfig = {
	name: string,
	shirtId: number,
	pantsId: number,
	skin: Color3,
	position: Vector3,
	facing: Vector3,
	heightScale: number?,
	widthScale: number?,
}

function AvatarFactory.createStatic(config: StaticAvatarConfig): Model?
	local description = Instance.new("HumanoidDescription")
	description.Shirt = config.shirtId
	description.Pants = config.pantsId
	description.HeightScale = config.heightScale or 1
	description.WidthScale = config.widthScale or 1
	description.BodyTypeScale = 0.15
	description.HeadColor = config.skin
	description.TorsoColor = config.skin
	description.LeftArmColor = config.skin
	description.RightArmColor = config.skin
	description.LeftLegColor = config.skin
	description.RightLegColor = config.skin

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
