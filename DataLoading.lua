--modules--
local ProfileHandler = require(script.ProfileHandler)
local Plots = require(game:GetService("ServerScriptService"):WaitForChild("Gameplay"):WaitForChild("Modules"):WaitForChild("Plots"))
local Planting = require(game:GetService("ServerScriptService"):WaitForChild("Gameplay"):WaitForChild("Modules"):WaitForChild("Planting"))
local BackpackSaving = require(game:GetService("ServerScriptService"):WaitForChild("Gameplay"):WaitForChild("Modules"):WaitForChild("BackpackSaving"))

--helpers--
local function waitForCharacterRoot(player, timeoutSeconds)
	timeoutSeconds = timeoutSeconds or 10
	local deadline  = os.clock() + timeoutSeconds

	local function currentRoot()
		local char = player.Character
		if char then
			return char, char:FindFirstChild("HumanoidRootPart")
		end
	end

	local char, root = currentRoot()
	if root then return char, root end

	-- wait for CharacterAdded then HumanoidRootPart
	repeat
		char = player.Character or player.CharacterAdded:Wait()
		root = char:FindFirstChild("HumanoidRootPart") or char.ChildAdded:Wait()
	until root or os.clock() > deadline

	return char, root
end
--connections--
local AddedConnection = game:GetService("Players").PlayerAdded:Connect(function(Player)
	ProfileHandler.LoadProfile(Player)
	local PlayerData = ProfileHandler.GetData(Player)

	if PlayerData then
		--stat loading--
		local DataFolder = Instance.new("Folder", Player)
		DataFolder.Name = "Data"

		--item loading--
		local BunnyBucks = Instance.new("NumberValue", DataFolder)
		BunnyBucks.Name = "BunnyBucks"
		BunnyBucks.Value = PlayerData["BunnyBucks"]

		local OwnedGamepasses = Instance.new("Folder", DataFolder)
		OwnedGamepasses.Name = "OwnedGamepasses"
		for i,v in pairs(PlayerData["OwnedGamepasses"]) do
			local item = Instance.new("BoolValue", OwnedGamepasses)
			item.Name = tostring(i)
			item.Value = v
		end
		
		BackpackSaving.DeserializeBackpack(Player, PlayerData["BackpackData"])

		Plots.AssignPlot(Player)

		-- ⬇️ Wait for character and move to plot
		task.spawn(function()
			local _, root = waitForCharacterRoot(Player)
			if not root then
				warn("GotoPlot skipped; character/root not ready for", Player)
				return
			end
			Plots.GotoPlot(Player)          -- relies on HumanoidRootPart now present
		end)

		Planting.LoadPlanterData(Player, PlayerData["PlanterData"])
		print("Loaded "..Player.Name.."'s data!")

		--give badge--
		--[[
		if game:GetService("BadgeService"):UserHasBadgeAsync(Player.UserId, 2525068660472728) == false then
			game:GetService("BadgeService"):AwardBadge(Player.UserId, 2525068660472728)
		end
		--]]
	else
		Player:Kick("Unable to load your data, please rejoin!")
	end
end)

local LeaveConnection = game:GetService("Players").PlayerRemoving:Connect(function(Player)
	local PlayerData = ProfileHandler.GetData(Player)

	--save data--
	PlayerData["BunnyBucks"] = Player:FindFirstChild("Data").BunnyBucks.Value

	--save tables--
	local NewOwnedGamepasses = {}
	for _,v in ipairs(Player:FindFirstChild("Data").OwnedGamepasses:GetChildren()) do
		NewOwnedGamepasses[v.Name] = {""}
	end
	PlayerData["OwnedGamepasses"] = NewOwnedGamepasses
	
	PlayerData["BackpackData"] = BackpackSaving.SerializeBackpack(Player)
	PlayerData["PlanterData"] = Planting.GrabPlanterData(Player)
	--unload data--
	Plots.CleanupPlot(Player)
	ProfileHandler.UnloadProfile(Player)
	print("Saved "..Player.Name.."'s data!")
end)