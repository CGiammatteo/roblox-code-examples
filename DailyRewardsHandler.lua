--modules--
local DailyRewardsCalculator = require(game:GetService("ReplicatedStorage"):WaitForChild("ReplicatedModules"):WaitForChild("DailyRewardsCalculator"))
local LevelCalculator = require(game:GetService("ReplicatedStorage").ReplicatedModules.LevelCalculator)

--remotes--
local DailyRewardsFolder = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("DailyRewards")
local ClaimDailyReward = DailyRewardsFolder:WaitForChild("ClaimDailyReward")
local SendNotification = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Notifications"):WaitForChild("SendNotification")

--connections--
ClaimDailyReward.OnServerEvent:Connect(function(Player)
	local Data = Player:WaitForChild("Data")
	
	if Data then
		local Cash = Data:WaitForChild("Cash")
		local XP = Data:WaitForChild("XP")
		local Level = Data:WaitForChild("Level")
		local LoginStreak = Data:WaitForChild("LoginStreak")
		local LastLogin = Data:WaitForChild("LastLogin")
		local CanClaimDailyReward = Data:WaitForChild("CanClaimDailyReward")
		
		if CanClaimDailyReward.Value == true then
			local calculatedCash = DailyRewardsCalculator.calculateCashGrowth(Cash.Value, LoginStreak.Value)
			local calculatedXP = DailyRewardsCalculator.calculateXPGrowth(XP.Value, LoginStreak.Value)
			
			if LoginStreak.Value % 2 == 0 then
				Cash.Value += calculatedCash
			else
				local xpNeeded = LevelCalculator.calculateLevelXP((Level.Value + 1))

				if (XP.Value + calculatedXP) >= xpNeeded then
					Player:WaitForChild("Data"):WaitForChild("XP").Value = 0
					Player:WaitForChild("Data"):WaitForChild("Level").Value += 1
					SendNotification:FireClient(Player, "You have leveled up!", 4)
				else
					Player:WaitForChild("Data"):WaitForChild("XP").Value += calculatedXP
				end
			end
			
			CanClaimDailyReward.Value = false
			SendNotification:FireClient(Player, "Claimed Daily Reward!", 4)
		end 
	end
end)