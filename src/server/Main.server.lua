-- Example usage of PlayerDataService: shows Coins and Level on the leaderboard
-- and gives every player 1 coin every 10 seconds.

local Players = game:GetService("Players")

local PlayerDataService = require(script.Parent.PlayerDataService)

local LEADERSTATS = { "Coins", "Level" }
local COIN_INTERVAL = 10

PlayerDataService.PlayerLoaded:Connect(function(player, data)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	for _, stat in LEADERSTATS do
		local value = Instance.new("IntValue")
		value.Name = stat
		value.Value = data[stat]
		value.Parent = leaderstats
	end

	leaderstats.Parent = player
end)

PlayerDataService.DataChanged:Connect(function(player, key, value)
	local leaderstats = player:FindFirstChild("leaderstats")
	local stat = leaderstats and leaderstats:FindFirstChild(key)
	if stat then
		stat.Value = value
	end
end)

while true do
	task.wait(COIN_INTERVAL)
	for _, player in Players:GetPlayers() do
		PlayerDataService:Increment(player, "Coins", 1)
	end
end
