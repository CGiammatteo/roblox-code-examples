-- MODULES --
local SuffixHandler = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("SuffixHandler"))

-- SERVICES --
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local backpack = LocalPlayer:WaitForChild("Backpack")
local StarterGui = game:GetService("StarterGui")
local originalBackpackState = true

-- UI --
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local MainUI = PlayerGui:WaitForChild("MainUI")
local DialogueFrame = MainUI:WaitForChild("DialogueFrame")
local DialogueOptionsFrame = MainUI:WaitForChild("DialogueOptionsFrame")

local ShopUI = MainUI:WaitForChild("IngameShopUI")
local ShopTopBar = ShopUI:WaitForChild("TopBar")
local ExitButton = ShopTopBar:WaitForChild("ExitButton")

local TalkSound = script:WaitForChild("TalkSound")

-- REMOTES --
local SellRemoteFunction = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Gameplay"):WaitForChild("SellBunny")

-- STANDS --
local Stands = workspace:WaitForChild("Stands")
local SellPart = Stands:WaitForChild("InteractParts"):WaitForChild("SellPart")
local ShopPart = Stands:WaitForChild("InteractParts"):WaitForChild("ShopPart")
local NPCs = Stands:WaitForChild("NPCs")
local SellNPC = NPCs:WaitForChild("SellNPC")
local ShopNPC = NPCs:WaitForChild("ShopNPC")

-- CONFIG --
local DialogueOffsets = {
	Opened = UDim2.new(0.2, 0, 0.8, 0),
	Closed = UDim2.new(0.2, 0, 1.3, 0),
}

local NPCNames = {
	SellName = "Riley",
	ShopName = "Christian"
}

local Dialogue = {
	SellDialogue = {
		FirstPrompt = "What do ya got for me kid?",
		Options = {
			Option1 = "I want to sell my inventory",
			Option2 = "I want to sell this",
			Option3 = "How much is this worth?",
			Option4 = "Nevermind"
		}
	},
	ShopDialogue = {
		FirstPrompt = "Here's what we got in stock"
	}
}

local lastUsedPrompt = nil

-- FUNCTIONS --
local function restoreUI(prompt)
	Camera.CameraType = Enum.CameraType.Custom

	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 16
		humanoid.JumpHeight = 7.2
	end

	if lastUsedPrompt then
		lastUsedPrompt.Enabled = true
		lastUsedPrompt = nil
	end

	-- Restore backpack visibility and tool functionality
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)

	if backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") then
				tool.Enabled = true
			end
		end
	end

	-- Close dialogue frame
	local closeTween = TweenService:Create(DialogueFrame, TweenInfo.new(0.4, Enum.EasingStyle.Sine), {
		Position = DialogueOffsets.Closed
	})
	closeTween:Play()

	task.wait(0.4)

	DialogueFrame.Visible = false
	DialogueOptionsFrame.Visible = false

	-- Restore other UI
	for _, child in ipairs(MainUI:GetChildren()) do
		if child:IsA("Frame") and child.Name ~= "DialogueFrame" and child.Name ~= "DialogueOptionsFrame" and child.Name ~= "IngameShopUI" and child.Name ~= "GiftPlayerUI" and child.Name ~= "RobuxShopUI" then
			child.Visible = true
		end
	end

	-- Restore ShopButton visibility inside LeftFrame
	local leftFrame = MainUI:FindFirstChild("LeftFrame")
	if leftFrame then
		local shopButton = leftFrame:FindFirstChild("ShopButton")
		if shopButton then
			shopButton.Visible = true
		end
	end
end

local function setupHoverEffects()
	for _, option in ipairs(DialogueOptionsFrame:GetChildren()) do
		if option:IsA("TextButton") then
			local originalPosition = option.Position
			option.MouseEnter:Connect(function()
				TweenService:Create(option, TweenInfo.new(0.2), {
					Position = originalPosition + UDim2.new(0.02, 0, 0, 0)
				}):Play()
			end)
			option.MouseLeave:Connect(function()
				TweenService:Create(option, TweenInfo.new(0.2), {
					Position = originalPosition
				}):Play()
			end)
		end
	end
end

local function setupCameraTween(npc, prompt)
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")

	if not npc:FindFirstChild("HumanoidRootPart") then return end

	if humanoid then
		humanoid.WalkSpeed = 0
		humanoid.JumpHeight = 0
	end

	if prompt then
		prompt.Enabled = false
		lastUsedPrompt = prompt -- store the reference
	end

	local root = npc.HumanoidRootPart
	local forwardOffset = root.CFrame.LookVector * 6
	local heightOffset = Vector3.new(0, 2, 0)
	local targetPosition = root.Position + forwardOffset + heightOffset
	local targetLookAt = root.Position + Vector3.new(0, 1.5, 0)

	Camera.CameraType = Enum.CameraType.Scriptable

	local camPart = Instance.new("Part")
	camPart.Anchored = true
	camPart.CanCollide = false
	camPart.Transparency = 1
	camPart.CFrame = CFrame.new(targetPosition, targetLookAt)
	camPart.Parent = workspace

	local tween = TweenService:Create(Camera, TweenInfo.new(0.75), { CFrame = camPart.CFrame })
	tween:Play()

	task.delay(1, function() camPart:Destroy() end)
end

local function handleSellOption(option)
	DialogueOptionsFrame.Visible = false

	local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildWhichIsA("Tool")
	local bunnyName = tool and tool:GetAttribute("EggName")

	if option == 1 then
		SellRemoteFunction:InvokeServer("SellAll")
		DialogueFrame.NPCTalkLabel.Text = "It was a pleasure doing business with you"
		task.wait(2)
		restoreUI()

	elseif option == 2 then
		if bunnyName then
			local success = SellRemoteFunction:InvokeServer("SellOne", bunnyName, tool:GetAttribute("Enchanted") or false)
			DialogueFrame.NPCTalkLabel.Text = success and "It was a pleasure doing business with you" or "I can't buy that"
		else
			DialogueFrame.NPCTalkLabel.Text = "You gotta hold a bunny if you want me to buy it."
		end
		task.wait(2)
		restoreUI()

	elseif option == 3 then
		if bunnyName then
			local price = SellRemoteFunction:InvokeServer("CheckPrice", bunnyName)
			if price then
				DialogueFrame.NPCTalkLabel.Text = "The price of this bunny is $" .. tostring(SuffixHandler.SetSuffix(price)).. " BB"
			else
				DialogueFrame.NPCTalkLabel.Text = "I can't check that."
			end
		else
			DialogueFrame.NPCTalkLabel.Text = "Hold a bunny and I’ll tell you the price."
		end
		task.wait(2)
		restoreUI()

	elseif option == 4 then
		restoreUI()
	end
end

local function setupDialogueButtons()
	for i = 1, 4 do
		local button = DialogueOptionsFrame:FindFirstChild("Option" .. i)
		if button then
			button.MouseButton1Click:Connect(function()
				handleSellOption(i)
			end)
		end
	end
end

local function startDialogue(npc)
	-- Hide all UI frames EXCEPT LeftFrame
	for _, child in ipairs(MainUI:GetChildren()) do
		if child:IsA("Frame") and child.Name ~= "DialogueFrame" and child.Name ~= "DialogueOptionsFrame" and child.Name ~= "LeftFrame" and child.Name ~= "GiftPlayerUI" and child.Name ~= "RobuxShopUI" then
			child.Visible = false
		end
	end

	-- Specifically hide only the ShopButton inside LeftFrame
	local leftFrame = MainUI:FindFirstChild("LeftFrame")
	if leftFrame then
		local shopButton = leftFrame:FindFirstChild("ShopButton")
		if shopButton then
			shopButton.Visible = false
		end
	end

	-- Hide backpack UI and disable tool equip
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

	if backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") then
				tool.Enabled = false
			end
		end
	end

	-- Set up dialogue UI
	DialogueFrame.Position = DialogueOffsets.Closed
	DialogueFrame.Visible = true
	DialogueOptionsFrame.Visible = false
	DialogueFrame.NPCTalkLabel.Text = ""
	DialogueFrame.NPCNameLabel.Text = npc == SellNPC and NPCNames.SellName or NPCNames.ShopName

	local data = npc == SellNPC and Dialogue.SellDialogue or Dialogue.ShopDialogue
	local fullText = data.FirstPrompt

	local tween = TweenService:Create(DialogueFrame, TweenInfo.new(0.4), {
		Position = DialogueOffsets.Opened
	})
	tween:Play()
	tween.Completed:Wait()

	-- Type out the dialogue
	for i = 1, #fullText do
		DialogueFrame.NPCTalkLabel.Text = string.sub(fullText, 1, i)
		TalkSound:Play()
		task.wait(0.03)
	end

	task.wait(0.25)

	-- If it's the shop NPC, fade out dialogue and fade in the shop UI
	if npc == ShopNPC then
		local closeTween = TweenService:Create(DialogueFrame, TweenInfo.new(0.4, Enum.EasingStyle.Sine), {
			Position = DialogueOffsets.Closed
		})
		closeTween:Play()
		closeTween.Completed:Wait()

		DialogueFrame.Visible = false
		ShopUI.Visible = true

		-- Make sure to re-enable the prompt!
		if lastUsedPrompt then
			lastUsedPrompt.Enabled = true
			lastUsedPrompt = nil
		end

		return
	end


	-- Otherwise (SellNPC), show sell options
	local opts = data.Options
	DialogueOptionsFrame.Option1.Text = opts.Option1
	DialogueOptionsFrame.Option2.Text = opts.Option2
	DialogueOptionsFrame.Option3.Text = opts.Option3
	DialogueOptionsFrame.Option4.Text = opts.Option4

	DialogueOptionsFrame.Visible = true
	for _, btn in ipairs(DialogueOptionsFrame:GetChildren()) do
		if btn:IsA("TextButton") then
			btn.TextTransparency = 1
			TweenService:Create(btn, TweenInfo.new(0.4), {
				TextTransparency = 0
			}):Play()
		end
	end
end

function SetupPrompts()
	local function createPrompt(part, npc)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "TalkPrompt"
		prompt.ActionText = "Talk"
		prompt.ObjectText = "Talk"
		prompt.HoldDuration = 0
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = 10
		prompt.Parent = part

		prompt.Triggered:Connect(function()
			setupCameraTween(npc, prompt)
			task.wait(0.75)
			startDialogue(npc)
		end)
	end

	createPrompt(SellPart, SellNPC)
	createPrompt(ShopPart, ShopNPC)
	setupDialogueButtons()
	setupHoverEffects()
end

--buttons--
ExitButton.Activated:Connect(function()
	-- Restore backpack visibility
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)

	-- Re-enable all tools
	if backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") then
				tool.Enabled = true
			end
		end
	end

	-- Make all MainUI frames visible again (except Dialogue and DialogueOptions)
	for _, child in ipairs(MainUI:GetChildren()) do
		if child:IsA("Frame") and child.Name ~= "DialogueFrame" and child.Name ~= "DialogueOptionsFrame" and child.Name ~= "IngameShopUI" and child.Name ~= "GiftPlayerUI" and child.Name ~= "RobuxShopUI" then
			child.Visible = true
		end
	end

	-- Also make sure ShopButton inside LeftFrame is visible
	local leftFrame = MainUI:FindFirstChild("LeftFrame")
	if leftFrame then
		local shopButton = leftFrame:FindFirstChild("ShopButton")
		if shopButton then
			shopButton.Visible = true
		end
	end

	-- Re-enable last used prompt
	if lastUsedPrompt then
		lastUsedPrompt.Enabled = true
		lastUsedPrompt = nil
	end

	-- Reset camera to custom
	Camera.CameraType = Enum.CameraType.Custom

	-- Reset player movement if it was stopped
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 16
		humanoid.JumpHeight = 7.2
	end

	-- Hide the Shop UI
	ShopUI.Visible = false
end)

SetupPrompts()