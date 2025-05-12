-- SERVICES --
local RunService       = game:GetService("RunService")
local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")

-- REMOTES --
local GameplayFolder   = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Gameplay")
local HarvestReadyRemote = GameplayFolder:WaitForChild("HarvestReady")
local HarvestRemote      = GameplayFolder:WaitForChild("Harvest")

local player = Players.LocalPlayer
local PLOTS_FOLDER = workspace:WaitForChild("Plots")

local function waitForAssignedPlot()
	while true do
		for _, plot in ipairs(PLOTS_FOLDER:GetChildren()) do
			if plot:GetAttribute("Owner") == player.UserId then
				return plot
			end
		end
		PLOTS_FOLDER.ChildAdded:Wait()
	end
end

local function findPlantedPart(plot, guid)
	local plantedFolder = plot:FindFirstChild("PlantedItems")
	if not plantedFolder then return nil end

	for _, obj in ipairs(plantedFolder:GetDescendants()) do
		if obj:IsA("BasePart") and obj:GetAttribute("HarvestID") == guid then
			return obj
		end
	end
	return nil
end

HarvestReadyRemote.OnClientEvent:Connect(function(guid : string)
	local plot = waitForAssignedPlot()

	local deadline = os.clock() + 5
	local part

	repeat
		part = findPlantedPart(plot, guid)
		if part then break end

		if not plot or plot:GetAttribute("Owner") ~= player.UserId then
			plot = waitForAssignedPlot()
		end
		RunService.Heartbeat:Wait()
	until os.clock() > deadline

	if not part then
		warn("HarvestReadyRemote: part with id "..guid.." not found in plot")
		return
	end

	if part:FindFirstChild("HarvestPrompt") then return end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name                  = "HarvestPrompt"
	prompt.ActionText            = "Harvest"
	prompt.ObjectText            = "Bunny"
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight   = false
	prompt.Exclusivity           = Enum.ProximityPromptExclusivity.OnePerButton
	prompt.Parent                = part

	prompt.Triggered:Connect(function()
		HarvestRemote:FireServer(part)
		prompt:Destroy()
	end)
end)