# Project notes

Roblox game synced into Studio with [Rojo](https://rojo.space). Code is Luau.

- `default.project.json` maps `src/server` → `ServerScriptService.Server`.
- `*.server.lua` = Script, `*.client.lua` = LocalScript, other `*.lua` = ModuleScript.
- Player saving lives in `src/server/PlayerDataService.lua`. Use its API
  (`Get`, `WaitForData`, `Set`, `Increment`, `Save`, `PlayerLoaded`, `DataChanged`)
  instead of calling DataStoreService elsewhere. Add new saved fields to `TEMPLATE`.

## Roblox DataStore rules to follow

- DataStores only work on the server, in a published place. Testing in Studio
  needs Game Settings → Security → "Enable Studio Access to API Services".
- Every DataStore call can fail or throttle: wrap it in `pcall`, retry with
  backoff, and check `DataStoreService:GetRequestBudgetForRequestType` first.
- Use `UpdateAsync` (not `GetAsync` + `SetAsync`) to change existing data so the
  change is atomic. Return `nil` from the transform to cancel the write. The
  transform can run more than once, so it must not have side effects.
  It can return `value, userIds, metadata`; pass the player's UserId so
  data-deletion (GDPR) requests can find the key.
- Use a session lock to stop two servers editing one player's data at once
  (for example during teleports).
- Save on `PlayerRemoving`, autosave every so often, and save in
  `game:BindToClose` (the server gets about 30 seconds after shutdown starts).
  Save players in parallel there.
- Limits: a key can be up to 50 characters, a store name up to 50, and a value
  up to 4 MB after JSON encoding. Values must be JSON-compatible: no
  Instances, Vector3, Color3 or other Roblox types, and no mixed tables or
  arrays with gaps.
- Same key written too often (more than about once every 6 seconds) is throttled.
- `IncrementAsync` works on integer values; `RemoveAsync` deletes a key.
  Standard data stores keep versions (`ListVersionsAsync`, `GetVersionAsync`)
  and can list keys (`ListKeysAsync`).
- For leaderboards use `GetOrderedDataStore` and `GetSortedAsync`; it only
  stores positive whole numbers.
- `MemoryStoreService` is for short-lived shared data such as matchmaking
  queues, not for saving player progress.

## Game design: retention

Read `docs/retention.md` before designing or changing onboarding,
progression, rewards, events or social features. In short: D1 depends on the
core loop, a first-time experience under 5 minutes and performance; D7 on
progression; D30 on regular updates and social systems. Log FTUE and
progression steps so drop-offs show up in Analytics.
