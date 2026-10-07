# DataStore Demo

Saves player data (Coins, Level, Inventory) with Roblox DataStores, including
retries, session locking, autosave and saving on shutdown.

## Use it in Roblox Studio

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install`
   in this folder to get Rojo. Install the Rojo plugin in Studio too.
2. Run `rojo serve`, open your place in Studio and click **Connect** in the
   Rojo plugin.
3. Publish the place, then turn on Game Settings → Security →
   **Enable Studio Access to API Services**.
4. Press Play. Coins go up by 1 every 10 seconds and are still there when you
   rejoin.

## Files

- `src/server/PlayerDataService.lua`: loads and saves player data.
- `src/server/Main.server.lua`: example that shows the data on the leaderboard.
