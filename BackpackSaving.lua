-- BackpackSaving.lua
--------------------------------------------------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerModules   = game:GetService("ServerScriptService"):WaitForChild("Gameplay"):WaitForChild("Modules")

local Givers          = require(ServerModules:WaitForChild("Givers"))
local ItemData        = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ItemData"))
local FlourishmentData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FlourishmentData"))


--------------------------------------------------------------------
-- Utilities
--------------------------------------------------------------------
local function WeldModelParts(model: Model)
	if not model or not model:IsA("Model") then return end
	if not model.PrimaryPart then return end
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part ~= model.PrimaryPart then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = model.PrimaryPart
			weld.Part1 = part
			weld.Parent = part
		end
	end
end

local function round2(n:number) return math.floor(n*100+0.5)/100 end

local function getDataByScriptName(name)
	for _, d in pairs(ItemData) do
		if d.ScriptName == name then return d end
	end
end

local function getFlourishmentDataByScriptName(name)
	for _, d in pairs(FlourishmentData) do
		if d.ScriptName == name then return d end
	end
end

local function createBunnyTool(player: Player, scriptName: string, weight: number, enchanted: boolean, amount: number)
	local data = getDataByScriptName(scriptName)
	if not data then return end

	-- base Tool template comes from ReplicatedStorage
	local tool = ReplicatedStorage:WaitForChild("Tools"):WaitForChild("BunnyTool"):Clone()
	tool:SetAttribute("Amount", amount or 1)
	tool:SetAttribute("Weight", weight)
	tool:SetAttribute("EggName", scriptName)
	tool:SetAttribute("Type", "Bunny")
	tool:SetAttribute("Enchanted", enchanted)
	tool.Name = string.format("%s %.2fkg x%d", scriptName, weight, amount)

	-- model visual
	local modelClone = data.ModelPath:Clone()
	WeldModelParts(modelClone)

	local handle = modelClone:FindFirstChild("Main")
	if not handle or not handle:IsA("BasePart") then
		warn("Handle missing on model for", scriptName)
		modelClone:Destroy()
	else
		handle.Name       = "Handle"
		handle.Anchored   = false
		modelClone.Name   = "Model"

		if enchanted then
			local sparkles   = Instance.new("Sparkles")
			sparkles.Name    = "EnchantSparkles"
			sparkles.Parent  = handle
		end

		modelClone.Parent = tool
		handle.Parent     = tool
	end

	tool.Parent = player.Backpack
	return tool
end

--------------------------------------------------------------------
-- Module
--------------------------------------------------------------------
local BackpackSaving = {}

function BackpackSaving.SerializeBackpack(player: Player)
	local backpackData = {}

	local function scan(container)
		if not container then return end
		for _, tool in ipairs(container:GetChildren()) do
			if tool:IsA("Tool") then
				local entry = {
					Type     = tool:GetAttribute("Type"),
					Name = tool:GetAttribute("ScriptName") or tool:GetAttribute("EggName") or tool.Name,
					Amount   = tool:GetAttribute("Amount") or 1,
				}
				if entry.Type == "Bunny" then
					entry.Weight    = round2(tool:GetAttribute("Weight") or 1)
					entry.Enchanted = tool:GetAttribute("Enchanted") or false
				end
				table.insert(backpackData, entry)
			end
		end
	end

	scan(player:FindFirstChild("Backpack"))
	scan(player:FindFirstChild("Character"))

	return backpackData
end

function BackpackSaving.DeserializeBackpack(player: Player, savedData)
	if typeof(savedData) ~= "table" then return end

	-- wipe current backpack
	for _, t in ipairs(player.Backpack:GetChildren()) do
		if t:IsA("Tool") then t:Destroy() end
	end

	for _, entry in ipairs(savedData) do
		local name   = entry.Name
		local amount = entry.Amount or 1

		if entry.Type == "Bunny" and name then
			createBunnyTool(
				player,
				name,
				entry.Weight or 1,
				entry.Enchanted or false,
				amount
			)

		elseif entry.Type == "Egg" and name then
			for i = 1, amount do
				Givers.GiveEgg(player, name)
			end

		elseif entry.Type == "Flourishment" and name then
			local flourishmentData = getFlourishmentDataByScriptName(name)
			if flourishmentData and flourishmentData.ToolPath then
				Givers.GiveToolStacked(player, flourishmentData.ToolPath, amount)
			end
		end
	end
end

return BackpackSaving