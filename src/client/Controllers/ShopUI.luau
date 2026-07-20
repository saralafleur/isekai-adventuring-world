--!strict
-- Guild shop window: item list with prices, live coin balance, buy buttons.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local player = Players.LocalPlayer

type ShopItem = { itemId: string, name: string, description: string, price: number }

local ShopUI = {}

local gui: ScreenGui
local frame: Frame
local titleLabel: TextLabel
local coinsLabel: TextLabel
local listFrame: ScrollingFrame

local currentShopId: string? = nil
local currentCoins = 0

local function buildGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "ShopGui"
	gui.ResetOnSpawn = false
	gui.Enabled = false

	frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(440, 420)
	frame.BackgroundColor3 = Color3.fromRGB(30, 26, 34)
	frame.BackgroundTransparency = 0.05
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(200, 170, 90)
	stroke.Thickness = 2
	stroke.Parent = frame

	titleLabel = Instance.new("TextLabel")
	titleLabel.Position = UDim2.new(0, 20, 0, 12)
	titleLabel.Size = UDim2.new(1, -120, 0, 30)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextColor3 = Color3.fromRGB(240, 205, 110)
	titleLabel.Font = Enum.Font.FredokaOne
	titleLabel.TextSize = 24
	titleLabel.Parent = frame

	coinsLabel = Instance.new("TextLabel")
	coinsLabel.AnchorPoint = Vector2.new(1, 0)
	coinsLabel.Position = UDim2.new(1, -52, 0, 16)
	coinsLabel.Size = UDim2.fromOffset(120, 24)
	coinsLabel.BackgroundTransparency = 1
	coinsLabel.TextXAlignment = Enum.TextXAlignment.Right
	coinsLabel.TextColor3 = Color3.fromRGB(230, 190, 90)
	coinsLabel.Font = Enum.Font.GothamBold
	coinsLabel.TextSize = 18
	coinsLabel.Parent = frame

	local closeButton = Instance.new("TextButton")
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -12, 0, 12)
	closeButton.Size = UDim2.fromOffset(30, 30)
	closeButton.BackgroundColor3 = Color3.fromRGB(60, 50, 55)
	closeButton.Text = "✕"
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextSize = 16
	closeButton.Parent = frame
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeButton
	closeButton.Activated:Connect(function()
		gui.Enabled = false
		currentShopId = nil
	end)

	listFrame = Instance.new("ScrollingFrame")
	listFrame.Position = UDim2.new(0, 14, 0, 52)
	listFrame.Size = UDim2.new(1, -28, 1, -66)
	listFrame.BackgroundTransparency = 1
	listFrame.BorderSizePixel = 0
	listFrame.ScrollBarThickness = 6
	listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listFrame.CanvasSize = UDim2.new()
	listFrame.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = listFrame

	gui.Parent = player:WaitForChild("PlayerGui")
end

local function renderItems(items: { ShopItem })
	for _, child in listFrame:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for order, item in items do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -8, 0, 64)
		row.BackgroundColor3 = Color3.fromRGB(42, 37, 46)
		row.LayoutOrder = order
		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 10)
		rowCorner.Parent = row

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Position = UDim2.new(0, 12, 0, 8)
		nameLabel.Size = UDim2.new(1, -140, 0, 20)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Text = item.name
		nameLabel.TextColor3 = Color3.new(1, 1, 1)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 16
		nameLabel.Parent = row

		local descLabel = Instance.new("TextLabel")
		descLabel.Position = UDim2.new(0, 12, 0, 30)
		descLabel.Size = UDim2.new(1, -140, 0, 28)
		descLabel.BackgroundTransparency = 1
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.TextYAlignment = Enum.TextYAlignment.Top
		descLabel.TextWrapped = true
		descLabel.Text = item.description
		descLabel.TextColor3 = Color3.fromRGB(190, 185, 195)
		descLabel.Font = Enum.Font.Gotham
		descLabel.TextSize = 12
		descLabel.Parent = row

		local buyButton = Instance.new("TextButton")
		buyButton.AnchorPoint = Vector2.new(1, 0.5)
		buyButton.Position = UDim2.new(1, -12, 0.5, 0)
		buyButton.Size = UDim2.fromOffset(104, 36)
		buyButton.Text = `{item.price} 🪙  Buy`
		buyButton.TextColor3 = Color3.new(1, 1, 1)
		buyButton.Font = Enum.Font.GothamBold
		buyButton.TextSize = 14
		buyButton.BackgroundColor3 = if currentCoins >= item.price
			then Color3.fromRGB(70, 120, 70)
			else Color3.fromRGB(80, 70, 70)
		local buyCorner = Instance.new("UICorner")
		buyCorner.CornerRadius = UDim.new(0, 8)
		buyCorner.Parent = buyButton
		buyButton.Activated:Connect(function()
			local shopId = currentShopId
			if shopId then
				Remotes.get("ShopBuy"):FireServer(shopId, item.itemId)
			end
		end)
		buyButton.Parent = row

		row.Parent = listFrame
	end
end

local lastItems: { ShopItem } = {}

local function onShopOpen(shopId: string, shopName: string, items: { ShopItem })
	currentShopId = shopId
	lastItems = items
	titleLabel.Text = shopName
	coinsLabel.Text = `{currentCoins} 🪙`
	renderItems(items)
	gui.Enabled = true
end

function ShopUI.init()
	buildGui()
	Remotes.get("ShopOpen").OnClientEvent:Connect(onShopOpen)
	Remotes.get("InventoryUpdated").OnClientEvent:Connect(function(_items, coins: number)
		currentCoins = coins
		if gui.Enabled then
			coinsLabel.Text = `{currentCoins} 🪙`
			renderItems(lastItems)
		end
	end)
end

return ShopUI
