local ItemData = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("ItemData"))
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Givers = {}

-- Helper
local function updateToolName(tool)
	local baseName = tool:GetAttribute("EggName") or tool:GetAttribute("ScriptName") or tool.Name
	local amount = tool:GetAttribute("Amount") or 1
	local type = tool:GetAttribute("Type")

	-- Strip any existing " xN" suffix
	baseName = string.gsub(baseName, " x%d+$", "")

	if type == "Egg" then
		tool.Name = baseName .. " Egg x" .. amount
	else
		tool.Name = baseName .. " x" .. amount
	end
end

-- Give Egg Tool
function Givers.GiveEgg(player: Player, eggName: string)
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return end

	-- Only look for matching egg tools
	local existingTool = nil
	for _, tool in ipairs(backpack:GetChildren()) do
		if tool:IsA("Tool") and tool:GetAttribute("EggName") == eggName and tool:GetAttribute("Type") == "Egg" then
			existingTool = tool
			break
		end
	end

	if existingTool then
		local amount = existingTool:GetAttribute("Amount") or 1
		existingTool:SetAttribute("Amount", amount + 1)
		updateToolName(existingTool)
		return
	end

	local toolTemplate = ReplicatedStorage:WaitForChild("Tools"):FindFirstChild("PlacementTool")
	if not toolTemplate then return end

	local eggModel = ReplicatedStorage:WaitForChild("Models"):WaitForChild("Eggs"):FindFirstChild(eggName.."Egg")
	if not eggModel then return end

	local eggHandle = eggModel:FindFirstChild("Handle")
	if not eggHandle then return end

	local toolClone = toolTemplate:Clone()
	toolClone:SetAttribute("Amount", 1)
	toolClone:SetAttribute("EggName", eggName)
	toolClone:SetAttribute("Type", "Egg")
	updateToolName(toolClone)

	local handleClone = eggHandle:Clone()
	handleClone.Name = "Handle"
	handleClone.Parent = toolClone

	local scriptsFolder = toolClone:FindFirstChild("Scripts")
	if scriptsFolder then
		for _, script in pairs(scriptsFolder:GetChildren()) do
			if script:IsA("Script") then
				script.Enabled = true
			end
		end
	end

	toolClone.Parent = backpack
end

-- Remove Egg Tool
function Givers.RemoveEgg(player: Player, eggName: string)
	for _, container in { player.Character, player:FindFirstChild("Backpack") } do
		if container then
			for _, tool in ipairs(container:GetChildren()) do
				if tool:IsA("Tool")
					and tool:GetAttribute("EggName"):match("^(.-) x?%d*$") == eggName
					and tool:GetAttribute("Type") == "Egg" then

					local amount = tool:GetAttribute("Amount") or 1
					if amount > 1 then
						tool:SetAttribute("Amount", amount - 1)
						updateToolName(tool)
					else
						tool:Destroy()
					end
					return
				end
			end
		end
	end
end

-- Add Bunny Tool
function Givers.GiveBunny(player: Player, bunnyName: string, isEnchanted: boolean?)
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return end

	local enchanted = isEnchanted == true

	-- Look for matching bunny tool
	local existingTool = nil
	for _, tool in ipairs(backpack:GetChildren()) do
		if tool:IsA("Tool") and
			tool:GetAttribute("EggName") == bunnyName and
			tool:GetAttribute("Type") == "Bunny" and
			(tool:GetAttribute("Enchanted") or false) == enchanted then
			existingTool = tool
			break
		end
	end

	if existingTool then
		local amount = existingTool:GetAttribute("Amount") or 1
		existingTool:SetAttribute("Amount", amount + 1)
		updateToolName(existingTool)
		return
	end

	-- Create new bunny tool
	local toolTemplate = ReplicatedStorage:WaitForChild("Tools"):FindFirstChild("BunnyTool")
	if not toolTemplate then
		warn("BunnyTool not found!")
		return
	end

	local toolClone = toolTemplate:Clone()
	toolClone:SetAttribute("Amount", 1)
	toolClone:SetAttribute("EggName", bunnyName)
	toolClone:SetAttribute("Enchanted", enchanted)
	toolClone:SetAttribute("Type", "Bunny")
	updateToolName(toolClone)

	toolClone.Parent = backpack
end

function Givers.RemoveBunny(player: Player, bunnyName: string, isEnchanted: boolean?)
	for _, container in { player.Character, player:FindFirstChild("Backpack") } do
		if container then
			for _, tool in ipairs(container:GetChildren()) do
				if tool:IsA("Tool")
					and tool:GetAttribute("EggName"):match("^(.-) x?%d*$") == bunnyName
					and tool:GetAttribute("Type") == "Bunny"
					and (tool:GetAttribute("Enchanted") or false) == (isEnchanted == true) then

					local amount = tool:GetAttribute("Amount") or 1
					if amount > 1 then
						tool:SetAttribute("Amount", amount - 1)
						updateToolName(tool)
					else
						tool:Destroy()
					end
					return
				end
			end
		end
	end
end

function Givers.ClearBackpack(player: Player)
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return end

	for _, item in ipairs(backpack:GetChildren()) do
		item:Destroy()
	end
end

-- Give Flourishment Tool
function Givers.GiveTool(player: Player, toolPath: Instance)
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return end
	if not toolPath or not toolPath:IsA("Tool") then
		warn("Invalid tool path provided for GiveTool.")
		return
	end

	local scriptName = toolPath.Name
	local existingTool = nil

	for _, tool in ipairs(backpack:GetChildren()) do
		if tool:IsA("Tool") and tool.Name == scriptName and tool:GetAttribute("Type") == "Flourishment" then
			existingTool = tool
			break
		end
	end

	if existingTool then
		local amount = existingTool:GetAttribute("Amount") or 1
		existingTool:SetAttribute("Amount", amount + 1)
		updateToolName(existingTool)
		return
	end

	local toolClone = toolPath:Clone()
	toolClone:SetAttribute("Amount", 1)
	toolClone:SetAttribute("ScriptName", toolPath.Name)
	toolClone:SetAttribute("Type", "Flourishment")

	updateToolName(toolClone)

	-- Enable scripts if any
	local scriptsFolder = toolClone:FindFirstChild("Scripts")
	if scriptsFolder then
		for _, script in ipairs(scriptsFolder:GetChildren()) do
			if script:IsA("Script") then
				script.Enabled = true
			end
		end
	end

	toolClone.Parent = backpack
end

function Givers.GiveToolStacked(player, toolPath, amount)
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return end
	if not toolPath or not toolPath:IsA("Tool") then return end

	local scriptName = toolPath.Name
	local existingTool = nil

	for _, tool in ipairs(backpack:GetChildren()) do
		if tool:IsA("Tool")
			and tool:GetAttribute("ScriptName") == scriptName
			and tool:GetAttribute("Type") == "Flourishment" then
			existingTool = tool
			break
		end
	end

	if existingTool then
		local current = existingTool:GetAttribute("Amount") or 1
		existingTool:SetAttribute("Amount", current + amount)
		updateToolName(existingTool)
		return
	end

	local toolClone = toolPath:Clone()
	toolClone:SetAttribute("Amount", amount)
	toolClone:SetAttribute("ScriptName", scriptName)
	toolClone:SetAttribute("Type", "Flourishment")
	updateToolName(toolClone)

	local scriptsFolder = toolClone:FindFirstChild("Scripts")
	if scriptsFolder then
		for _, script in ipairs(scriptsFolder:GetChildren()) do
			if script:IsA("Script") then
				script.Enabled = true
			end
		end
	end

	toolClone.Parent = backpack
end

function Givers.RemoveTool(player: Player, scriptName: string)
	for _, container in { player.Character, player:FindFirstChild("Backpack") } do
		if container then
			for _, tool in ipairs(container:GetChildren()) do
				if tool:IsA("Tool")
					and tool.Name:match("^(.-) x?%d*$") == scriptName
					and tool:GetAttribute("Type") == "Flourishment" then

					local amount = tool:GetAttribute("Amount") or 1
					if amount > 1 then
						tool:SetAttribute("Amount", amount - 1)
						updateToolName(tool)
					else
						tool:Destroy()
					end
					return -- done
				end
			end
		end
	end
end

return Givers