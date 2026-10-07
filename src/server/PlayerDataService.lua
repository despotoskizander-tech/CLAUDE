-- PlayerDataService
-- Loads, caches and saves each player's data with DataStoreService.
--
-- Stored value per player (key "Player_<UserId>"):
--   { Data = <the player's data>, SessionLock = { JobId = string, Time = number } | nil }
--
-- The session lock stops two servers from editing the same player's data at
-- once (for example during a teleport, when the old server may still be saving).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local PlayerDataService = {}

local STORE_NAME = "PlayerData"
local KEY_PREFIX = "Player_"
local AUTOSAVE_INTERVAL = 60 -- seconds between autosaves
local LOCK_TIMEOUT = AUTOSAVE_INTERVAL * 5 -- a lock not refreshed for this long is treated as abandoned
local LOCK_WAIT_ATTEMPTS = 6 -- how many times to wait for another server to release a lock
local LOCK_WAIT_TIME = 5 -- seconds between those attempts
local MAX_RETRIES = 5 -- attempts per DataStore call before giving up
local RETRY_BASE_DELAY = 1 -- seconds; doubles after each failed attempt

-- Default data for new players. New fields added here are filled in for
-- existing players when they next join.
local TEMPLATE = {
	Coins = 0,
	Level = 1,
	Inventory = {},
}

-- GetDataStore errors when the place is unpublished or Studio API access is
-- off. Keep running so the game is still playable, just without saving.
local storeOk, store = pcall(DataStoreService.GetDataStore, DataStoreService, STORE_NAME)
if not storeOk then
	warn("[PlayerDataService] DataStores unavailable, data will not be saved:", store)
	store = nil
end

local profiles = {} -- [Player] = { Key, UserId, Data, Saving }
local pendingReleases = 0

local loadedEvent = Instance.new("BindableEvent")
local changedEvent = Instance.new("BindableEvent")

-- Fires (player, data) once a player's data is ready.
PlayerDataService.PlayerLoaded = loadedEvent.Event
-- Fires (player, key, value) whenever Set or Increment changes a value.
PlayerDataService.DataChanged = changedEvent.Event

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- Adds any fields from the template that the saved data is missing.
local function reconcile(data, template)
	for k, v in template do
		if data[k] == nil then
			data[k] = deepCopy(v)
		elseif type(data[k]) == "table" and type(v) == "table" then
			reconcile(data[k], v)
		end
	end
	return data
end

local function waitForBudget(requestType)
	while DataStoreService:GetRequestBudgetForRequestType(requestType) < 1 do
		task.wait(1)
	end
end

-- Calls fn in a pcall, retrying with exponential backoff.
local function withRetries(requestType, fn)
	local lastError
	for attempt = 1, MAX_RETRIES do
		waitForBudget(requestType)
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastError = result
		if attempt < MAX_RETRIES then
			task.wait(RETRY_BASE_DELAY * 2 ^ (attempt - 1))
		end
	end
	return false, lastError
end

-- Tries once to claim the session lock. Returns:
--   "ok", data       lock acquired
--   "locked"         another live server holds the lock
--   "error", message DataStore request failed
local function tryAcquire(key)
	local locked = false
	local ok, result = withRetries(Enum.DataStoreRequestType.UpdateAsync, function()
		locked = false
		return store:UpdateAsync(key, function(stored)
			stored = stored or { Data = deepCopy(TEMPLATE) }
			local lock = stored.SessionLock
			if lock and lock.JobId ~= game.JobId and os.time() - lock.Time < LOCK_TIMEOUT then
				locked = true
				return nil -- cancel the write and leave the stored value untouched
			end
			stored.SessionLock = { JobId = game.JobId, Time = os.time() }
			return stored
		end)
	end)

	if not ok then
		return "error", result
	elseif locked then
		return "locked"
	end
	return "ok", result.Data
end

local function loadData(key)
	for _ = 1, LOCK_WAIT_ATTEMPTS do
		local status, value = tryAcquire(key)
		if status ~= "locked" then
			return status, value
		end
		task.wait(LOCK_WAIT_TIME)
	end
	return "locked"
end

-- Writes the profile's data. With release = true the session lock is cleared
-- so another server can load this player straight away.
local function saveProfile(player, profile, release)
	if not store then
		return true
	end

	profile.Saving = true
	local lostLock = false
	local ok, err = withRetries(Enum.DataStoreRequestType.UpdateAsync, function()
		lostLock = false
		return store:UpdateAsync(profile.Key, function(stored)
			stored = stored or {}
			local lock = stored.SessionLock
			if lock and lock.JobId ~= game.JobId then
				-- Another server took over this session; never overwrite its data.
				lostLock = true
				return nil
			end
			stored.Data = profile.Data
			stored.SessionLock = if release then nil else { JobId = game.JobId, Time = os.time() }
			-- Tagging the key with the UserId lets Roblox handle data-deletion requests.
			return stored, { profile.UserId }
		end)
	end)
	profile.Saving = false

	if not ok then
		warn(`[PlayerDataService] Failed to save {profile.Key}:`, err)
	elseif lostLock then
		warn(`[PlayerDataService] Lost session lock for {profile.Key}`)
		if not release and player.Parent then
			player:Kick("Your data was loaded on another server. Please rejoin.")
		end
	end
	return ok and not lostLock
end

local function releaseProfile(player)
	local profile = profiles[player]
	if not profile then
		return
	end
	profiles[player] = nil -- stops autosave and any further edits

	pendingReleases += 1
	while profile.Saving do
		task.wait()
	end
	saveProfile(player, profile, true)
	pendingReleases -= 1
end

local function onPlayerAdded(player)
	local key = KEY_PREFIX .. player.UserId
	local data

	if store then
		local status, value = loadData(key)
		if status == "locked" then
			player:Kick("Your data is still in use on another server. Please rejoin in a minute.")
			return
		elseif status == "error" then
			warn(`[PlayerDataService] Failed to load {key}:`, value)
			player:Kick("Could not load your data. Please rejoin.")
			return
		end
		data = value
	end

	local profile = {
		Key = key,
		UserId = player.UserId,
		Data = reconcile(data or {}, TEMPLATE),
		Saving = false,
	}

	-- The player may have left while their data was loading.
	if not player.Parent then
		if store then
			saveProfile(player, profile, true)
		end
		return
	end

	profiles[player] = profile
	loadedEvent:Fire(player, profile.Data)
end

-- Public API ---------------------------------------------------------------

-- Returns the player's data table, or nil if it hasn't loaded yet.
-- Edits made directly to this table are saved, but don't fire DataChanged.
function PlayerDataService:Get(player)
	local profile = profiles[player]
	return profile and profile.Data
end

-- Yields until the player's data has loaded. Returns nil if they leave first.
function PlayerDataService:WaitForData(player)
	while player.Parent and not profiles[player] do
		task.wait()
	end
	return self:Get(player)
end

function PlayerDataService:Set(player, key, value)
	local data = self:Get(player)
	if not data then
		return false
	end
	data[key] = value
	changedEvent:Fire(player, key, value)
	return true
end

function PlayerDataService:Increment(player, key, amount)
	local data = self:Get(player)
	if not data then
		return nil
	end
	data[key] = (data[key] or 0) + (amount or 1)
	changedEvent:Fire(player, key, data[key])
	return data[key]
end

-- Saves immediately, e.g. after a purchase. Normal changes rely on autosave.
function PlayerDataService:Save(player)
	local profile = profiles[player]
	if not profile or profile.Saving then
		return false
	end
	return saveProfile(player, profile, false)
end

-- Startup --------------------------------------------------------------------

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(releaseProfile)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_INTERVAL)
		for player, profile in profiles do
			if not profile.Saving then
				task.spawn(saveProfile, player, profile, false)
			end
		end
	end
end)

-- The server gets up to 30 seconds after shutdown starts; save everyone in parallel.
game:BindToClose(function()
	for player in profiles do
		task.spawn(releaseProfile, player)
	end
	while pendingReleases > 0 or next(profiles) do
		task.wait()
	end
end)

return PlayerDataService
