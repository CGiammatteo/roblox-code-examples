-- MODULES --
local ItemData = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("ItemData"))
local FlourishmentData = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("FlourishmentData"))
local TimeConversions = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("TimeConversions"))
local SuffixHandler = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("SuffixHandler"))
local TweenService = game:GetService("TweenService")

-- REMOTES --
local GameplayFolder = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Gameplay")
local BuyItemRemote = GameplayFolder:WaitForChild("BuyItem")
local BuyFlourishmentRemote = GameplayFolder:WaitForChild("BuyFlourishment")
local DecreaseStockRemote = GameplayFolder:WaitForChild("DecreaseStock")
local RefreshItemsRemote = GameplayFolder:WaitForChild("RefreshItemsPurchase")

-- UI ELEMENTS --
local ShopUI = script.Parent.Parent:WaitForChild("IngameShopUI")
local ShopTopBar = ShopUI:WaitForChild("TopBar")

-- TOPBAR BUTTONS --
local RefreshButton = ShopTopBar:WaitForChild("RefreshButton")
local EggRefreshTimerLabel = ShopTopBar:WaitForChild("EggRefreshTimer")

-- UI TABBING --
local TabNameLabel = ShopUI:WaitForChild("TabName")
local LeftTabButton = ShopUI:WaitForChild("LeftTabButton")
local RightTabButton = ShopUI:WaitForChild("RightTabButton")

-- SCROLLING FRAME --
local ItemsScrollingFrame = ShopUI:WaitForChild("ItemsFrame")
local ExampleItem = ItemsScrollingFrame:WaitForChild("ItemTemplate"):WaitForChild("Example")
local OptionsItem = ItemsScrollingFrame:WaitForChild("ItemTemplate"):WaitForChild("OptionsExample")

-- GIFTING UI --
local GiftPlayerUI = ShopUI.Parent:WaitForChild("GiftPlayerUI")
local PlayersScrollingFrame = GiftPlayerUI:WaitForChild("PlayersFrame")
local PlayerExample = PlayersScrollingFrame:WaitForChild("ItemTemplate"):WaitForChild("Example")
local ExitButton = GiftPlayerUI:WaitForChild("TopBar"):WaitForChild("ExitButton")

-- SETTINGS --
local RefreshTime = 300 -- 5 minutes in seconds
local activeTab = "Eggs" -- "Eggs" or "Flourishment"
local currentEggItems = {}
local refreshTimer = 0
local refreshConnection

local rarityOrder = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Legendary = 4,
	Mythic = 5
}

local openOptionsItem = nil -- Reusable options frame
local currentParentItem = nil -- Currently open item
local originalLayoutOrders = {} -- Backup original orders
local nextLayoutOrder = 0 -- Tracker during item population
local optionsTween = nil

local currentBBBuyConnection
local currentRobuxBuyConnection
local currentGiftBuyConnection
local currentGiftingItemData -- track item being gifted


-- FUNCTIONS --
local function IsOutOfStock(scriptName : string) : boolean
	local frame = ItemsScrollingFrame:FindFirstChild(scriptName)
	if not frame then return true end          -- cannot find → treat as none left
	local stock = frame:GetAttribute("Stock")
	return (typeof(stock) ~= "number") or (stock <= 0)
end

local function clearItems()
	for _, child in ipairs(ItemsScrollingFrame:GetChildren()) do
		if child:IsA("Frame") and child.Name ~= "ItemTemplate" then
			child:Destroy()
		end
	end

	-- 🧹 Also clear the openOptionsItem state
	if openOptionsItem then
		if optionsTween then optionsTween:Cancel() end
		openOptionsItem:Destroy()
		openOptionsItem = nil
	end

	originalLayoutOrders = {}
	currentParentItem = nil
end


local function getRandomStock(rarity)
	if rarity == "Common" then
		return math.random(8, 15)
	elseif rarity == "Uncommon" then
		return math.random(6, 12)
	elseif rarity == "Rare" then
		return math.random(3, 8)
	elseif rarity == "Legendary" then
		return math.random(1, 3)
	elseif rarity == "Mythic" then
		return math.random(0, 1)
	else
		return math.random(5, 15) -- fallback
	end
end

local RarityColors = {
	Common = Color3.fromRGB(126, 126, 126),
	Uncommon = Color3.fromRGB(85, 255, 0),
	Rare = Color3.fromRGB(0, 170, 255),
	Legendary = Color3.fromRGB(255, 0, 0),
	Mythic = Color3.fromRGB(170, 0, 255),
}

local function SetupOptionsFrame(itemData)
	if not openOptionsItem then return end

	-- Debounce table
	local lastClickedTimes = {
		BB = 0,
		Robux = 0,
		Gift = 0
	}

	-- Update BB Price
	local priceFrame = openOptionsItem:FindFirstChild("PriceFrame")
	if priceFrame then
		local bbLabel = priceFrame:FindFirstChild("PriceLabel")
		if bbLabel then
			local cost = itemData.CostPerEgg or itemData.Cost or 0
			bbLabel.Text = "$" .. SuffixHandler.SetSuffix(cost) .. " BB"
		end

		local buyButton = priceFrame:FindFirstChild("BuyButton")
		if buyButton then
			if currentBBBuyConnection then
				currentBBBuyConnection:Disconnect()
			end
			currentBBBuyConnection = buyButton.MouseButton1Click:Connect(function()
				if tick() - lastClickedTimes.BB < 0.5 then return end
				lastClickedTimes.BB = tick()

				if IsOutOfStock(itemData.ScriptName) then
					print("Out of stock!")
					return                                    -- ⛔ Don’t even ask the server
				end

				BuyItemRemote:FireServer("Normal", itemData.ScriptName, nil)
			end)
		end
	end

	-- Update Robux Price
	local robuxFrame = openOptionsItem:FindFirstChild("RobuxFrame")
	if robuxFrame then
		local robuxLabel = robuxFrame:FindFirstChild("PriceLabel")
		if robuxLabel then
			local robuxPriceMap = {
				EnchantingBook = 79,
				WateringCan = 49,

				-- fallback based on rarity
				Common = 7,
				Uncommon = 19,
				Rare = 49,
				Legendary = 99,
				Mythic = 199
			}

			local scriptName = itemData.ScriptName
			local rarity = itemData.Rarity or "Common"

			local robuxPrice = robuxPriceMap[scriptName] or robuxPriceMap[rarity] or 10
			robuxLabel.Text = tostring(robuxPrice)

		end

		local robuxBuyButton = robuxFrame:FindFirstChild("BuyButton")
		if robuxBuyButton then
			if currentRobuxBuyConnection then
				currentRobuxBuyConnection:Disconnect()
			end
			currentRobuxBuyConnection = robuxBuyButton.MouseButton1Click:Connect(function()
				if tick() - lastClickedTimes.Robux < 0.5 then return end
				lastClickedTimes.Robux = tick()

				BuyItemRemote:FireServer("Robux", itemData.ScriptName, nil)
				print("[BUY WITH ROBUX] Buying:", itemData.ScriptName)
			end)
		end
	end

	-- Setup Gifting
	local giftButtonFrame = openOptionsItem:FindFirstChild("GiftButton")
	if giftButtonFrame then
		local giftBuyButton = giftButtonFrame:FindFirstChild("BuyButton")
		if giftBuyButton then
			if currentGiftBuyConnection then
				currentGiftBuyConnection:Disconnect()
			end
			currentGiftBuyConnection = giftBuyButton.Activated:Connect(function()
				if tick() - lastClickedTimes.Gift < 0.5 then return end
				lastClickedTimes.Gift = tick()

				-- Open the gifting UI
				GiftPlayerUI.Visible = true
				ShopUI.Visible = false -- 🛑 Hide the shop while gifting
				currentGiftingItemData = itemData

				-- Clear old player entries
				for _, child in ipairs(PlayersScrollingFrame:GetChildren()) do
					if child:IsA("Frame") and child.Name ~= "ItemTemplate" then
						child:Destroy()
					end
				end

				local localPlayer = game.Players.LocalPlayer
				for _, player in ipairs(game.Players:GetPlayers()) do
					if player ~= localPlayer then
						local newPlayerEntry = PlayerExample:Clone()
						newPlayerEntry.Name = player.Name
						newPlayerEntry.Visible = true
						newPlayerEntry.Parent = PlayersScrollingFrame

						local nameLabel = newPlayerEntry:FindFirstChild("NameLabel")
						if nameLabel then
							nameLabel.Text = player.DisplayName
						end

						local imageLabel = newPlayerEntry:FindFirstChild("ImageLabel")
						if imageLabel then
							imageLabel.Image = string.format("https://www.roblox.com/headshot-thumbnail/image?userId=%d&width=420&height=420&format=png", player.UserId)
						end

						local selectButton = newPlayerEntry:FindFirstChild("SelectPlayerButton")
						if selectButton then
							selectButton.MouseButton1Click:Connect(function()
								-- 🎯 When a player is selected:
								GiftPlayerUI.Visible = false
								ShopUI.Visible = true -- ✅ Bring shop back
								BuyItemRemote:FireServer("Gift", currentGiftingItemData.ScriptName, player)
								print("[GIFT ITEM] Gifting:", currentGiftingItemData.ScriptName, "to", player.Name)
							end)
						end
					end
				end
			end)
		end
	end
end

local function cloneItemTemplate(itemData, isEgg)
	local newItem = ExampleItem:Clone()
	newItem.Name = itemData.ScriptName or itemData.Name or "Unnamed"
	newItem.Visible = true
	newItem.LayoutOrder = nextLayoutOrder
	nextLayoutOrder += 1
	newItem.Parent = ItemsScrollingFrame

	-- Setup labels
	newItem.NameLabel.Text = itemData.DisplayName or itemData.Name or "???"
	local cost = itemData.CostPerEgg or itemData.Cost or 0
	newItem.PriceLabel.Text = "$" .. SuffixHandler.SetSuffix(cost) .. " BB"
	newItem.RarityLabel.RarityText.Text = itemData.Rarity or "Unknown"
	newItem.RarityLabel.Pattern10.BackgroundColor3 = RarityColors[itemData.Rarity] or Color3.fromRGB(255, 255, 255)

	local stock = 0
	if isEgg then
		stock = getRandomStock(itemData.Rarity)
	elseif itemData.ScriptName == "WateringCan" then
		stock = math.random(2, 6)
	elseif itemData.ScriptName == "EnchantingBook" then
		stock = math.random(0, 2)
	end

	if stock > 0 then
		newItem.StockLabel.Text = "Stock: " .. stock
	else
		newItem.StockLabel.Text = "Out of stock"
	end
	newItem:SetAttribute("Stock", stock)

	newItem:SetAttribute("ScriptName", itemData.ScriptName) 

	-- Viewport Setup
	local viewport = newItem:FindFirstChild("ViewportFrame")
	if viewport and viewport:IsA("ViewportFrame") then
		for _, obj in ipairs(viewport:GetChildren()) do
			if obj:IsA("Model") or obj:IsA("BasePart") then
				obj:Destroy()
			end
		end

		local modelSource = itemData.EggModelPath or itemData.ModelPath
		if modelSource then
			local modelClone = modelSource:Clone()
			modelClone.Parent = viewport

			local primary = modelClone.PrimaryPart or modelClone:FindFirstChildWhichIsA("BasePart")
			if not primary then
				warn("No PrimaryPart found for", modelClone.Name)
				return
			end

			modelClone.PrimaryPart = primary

			-- Weld all parts to PrimaryPart so they move together
			for _, part in ipairs(modelClone:GetDescendants()) do
				if part:IsA("BasePart") and part ~= primary then
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = primary
					weld.Part1 = part
					weld.Parent = part
				end
			end

			-- Setup camera
			local cam = Instance.new("Camera")
			cam.CFrame = CFrame.new(Vector3.new(0, 0, 1.2), Vector3.new(0, 0, 0))
			viewport.CurrentCamera = cam

			-- Positioning logic based on item
			local scriptName = itemData.ScriptName
			local baseOffset, baseRotation

			if scriptName == "EnchantingBook" then
				baseOffset = Vector3.new(0, 0, -0.5)
				baseRotation = CFrame.Angles(0, math.rad(90), math.rad(90))
			elseif scriptName == "WateringCan" then
				baseOffset = Vector3.new(0, 0, -0.6)
				baseRotation = CFrame.Angles(0, 0, 0)
			else
				baseOffset = Vector3.new(0, 0, 0)
				baseRotation = CFrame.Angles(0, 0, 0)
			end

			local baseCFrame = CFrame.new(baseOffset) * baseRotation
			local hoverCFrame = CFrame.new(baseOffset + Vector3.new(0, 0, 0.2)) * baseRotation

			modelClone:SetPrimaryPartCFrame(baseCFrame)


			local rotating = false
			local rotationConnection
			local hoverTween

			local button = newItem:FindFirstChild("SelectItemButton")
			if button then
				button.MouseEnter:Connect(function()
					rotating = true
					rotationConnection = game:GetService("RunService").RenderStepped:Connect(function(dt)
						if rotating and modelClone.PrimaryPart then
							modelClone:SetPrimaryPartCFrame(modelClone.PrimaryPart.CFrame * CFrame.Angles(0, math.rad(30 * dt), 0))
						end
					end)

					if hoverTween then hoverTween:Cancel() end
					hoverTween = TweenService:Create(modelClone.PrimaryPart, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
						CFrame = hoverCFrame
					})

					hoverTween:Play()
				end)

				button.MouseLeave:Connect(function()
					rotating = false
					if rotationConnection then
						rotationConnection:Disconnect()
						rotationConnection = nil
					end

					if hoverTween then hoverTween:Cancel() end
					hoverTween = TweenService:Create(modelClone.PrimaryPart, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
						CFrame = baseCFrame
					})
					hoverTween:Play()
				end)

				button.MouseButton1Click:Connect(function()
					-- If Options are open and this item is the one that opened them, close it
					if openOptionsItem and openOptionsItem.Visible and openOptionsItem.LayoutOrder == (newItem.LayoutOrder + 1) then
						-- Close the options frame
						if optionsTween then optionsTween:Cancel() end
						optionsTween = TweenService:Create(openOptionsItem, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
							Size = UDim2.new(0.8, 0, 0, 0)
						})
						optionsTween:Play()
						optionsTween.Completed:Wait()

						-- Restore LayoutOrders
						for item, order in pairs(originalLayoutOrders) do
							item.LayoutOrder = order
						end

						openOptionsItem.Visible = false
						return -- 🚨 STOP here! Do NOT reopen!
					end

					-- Otherwise, open it for THIS item
					if not openOptionsItem then
						openOptionsItem = OptionsItem:Clone()
						openOptionsItem.Name = "OptionsItem"
						openOptionsItem.Size = UDim2.new(0.8, 0, 0, 0)
						openOptionsItem.Visible = false
						openOptionsItem.Parent = ItemsScrollingFrame
					end

					-- Backup layout orders
					originalLayoutOrders = {}
					for _, child in ipairs(ItemsScrollingFrame:GetChildren()) do
						if child:IsA("Frame") and child.Name ~= "ItemTemplate" then
							originalLayoutOrders[child] = child.LayoutOrder
						end
					end

					local clickedOrder = newItem.LayoutOrder

					-- Shift everything below down
					for _, child in ipairs(ItemsScrollingFrame:GetChildren()) do
						if child:IsA("Frame") and child.Name ~= "ItemTemplate" then
							if child.LayoutOrder > clickedOrder then
								child.LayoutOrder += 1
							end
						end
					end

					openOptionsItem.LayoutOrder = clickedOrder + 1
					openOptionsItem.Visible = true

					SetupOptionsFrame(itemData)

					-- Animate it open
					openOptionsItem.Size = UDim2.new(0.8, 0, 0, 0)
					if optionsTween then optionsTween:Cancel() end
					optionsTween = TweenService:Create(openOptionsItem, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
						Size = UDim2.new(0.8, 0, 0.025, 0)
					})
					optionsTween:Play()
				end)
			end
		end
	end
end

local function loadEggsTab()
	clearItems()

	local allEggs = {}
	local legendaryEgg
	local mythicEgg

	for _, data in pairs(ItemData) do
		if data.Rarity and rarityOrder[data.Rarity] then
			table.insert(allEggs, data)

			if data.Rarity == "Legendary" and not legendaryEgg then
				legendaryEgg = data
			elseif data.Rarity == "Mythic" and not mythicEgg then
				mythicEgg = data
			end
		end
	end

	-- Sort all eggs by rarity and cost
	table.sort(allEggs, function(a, b)
		local rA, rB = rarityOrder[a.Rarity], rarityOrder[b.Rarity]
		if rA == rB then
			return (a.CostPerEgg or a.Cost or 0) < (b.CostPerEgg or b.Cost or 0)
		else
			return rA < rB
		end
	end)

	local selectedEggs = {}

	-- Fill the shop with 8 eggs (excluding Legendary and Mythic)
	for _, egg in ipairs(allEggs) do
		if #selectedEggs >= 8 then break end

		if egg.Rarity ~= "Legendary" and egg.Rarity ~= "Mythic" then
			table.insert(selectedEggs, egg)
		end
	end

	-- Add 1 guaranteed Legendary + Mythic at the bottom (even if out of stock)
	if legendaryEgg then table.insert(selectedEggs, legendaryEgg) end
	if mythicEgg then table.insert(selectedEggs, mythicEgg) end

	currentEggItems = selectedEggs

	for _, egg in ipairs(currentEggItems) do
		cloneItemTemplate(egg, true)
	end
end

local function loadFlourishmentTab()
	clearItems()

	for _, data in pairs(FlourishmentData) do
		cloneItemTemplate(data, false) -- false = not an egg
	end
end

local function refreshEggs()
	refreshTimer = RefreshTime
	loadEggsTab()
end

local function updateTabDisplay()
	if activeTab == "Eggs" then
		TabNameLabel.Text = "Eggs"
		LeftTabButton.Visible = false
		RightTabButton.Visible = true
		loadEggsTab()
	elseif activeTab == "Flourishment" then
		TabNameLabel.Text = "Flourishment"
		LeftTabButton.Visible = true
		RightTabButton.Visible = false
		loadFlourishmentTab()
	end
end

local function setupRefreshTimer()
	if refreshConnection then
		refreshConnection:Disconnect()
	end

	refreshTimer = RefreshTime

	refreshConnection = task.spawn(function()
		while true do
			task.wait(1)
			refreshTimer -= 1

			if refreshTimer <= 0 then
				refreshTimer = RefreshTime
				refreshEggs()
			end

			EggRefreshTimerLabel.Text = "New eggs in: "..TimeConversions.FormatSeconds(math.max(refreshTimer, 0))
		end
	end)
end

-- UI BUTTONS --

LeftTabButton.Activated:Connect(function()
	if activeTab == "Flourishment" then
		activeTab = "Eggs"
		updateTabDisplay()
	end
end)

RightTabButton.Activated:Connect(function()
	if activeTab == "Eggs" then
		activeTab = "Flourishment"
		updateTabDisplay()
	end
end)

local db = false
RefreshButton.Activated:Connect(function()
	if db then return end
	db = true
	RefreshItemsRemote:FireServer()
	task.wait(1)
	db  = false
end)

ExitButton.Activated:Connect(function()
	GiftPlayerUI.Visible = false
	ShopUI.Visible = true
	currentGiftingItemData = nil
end)

DecreaseStockRemote.OnClientEvent:Connect(function(scriptName)
	-- Find the corresponding frame (they’re already named with ScriptName)
	local itemFrame = ItemsScrollingFrame:FindFirstChild(scriptName)
	if not itemFrame then return end

	local currentStock = itemFrame:GetAttribute("Stock")
	if typeof(currentStock) ~= "number" then return end

	currentStock -= 1
	itemFrame:SetAttribute("Stock", currentStock)

	local label = itemFrame:FindFirstChild("StockLabel")
	if label then
		if currentStock > 0 then
			label.Text = "Stock: " .. currentStock
		else
			label.Text = "No more stock."
		end
	end
end)

RefreshItemsRemote.OnClientEvent:Connect(function()
	refreshEggs()
end)

-- INITIALIZE --

local function InitialSetup()
	ShopUI.Visible = false
	updateTabDisplay()
	setupRefreshTimer()
end

InitialSetup()