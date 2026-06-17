# Roblox Deathswap — Studio Setup Guide

## 1. Create the RemoteEvents

In **ReplicatedStorage**, create a Folder named `RemoteEvents` and add these 6 **RemoteEvent** objects:

| Name | Type |
|---|---|
| SwapPlayers | RemoteEvent |
| PlaceBlock | RemoteEvent |
| RemoveBlock | RemoteEvent |
| RoundStateChanged | RemoteEvent |
| UpdateTimers | RemoteEvent |
| UpdateInventory | RemoteEvent |

## 2. Add the Shared Modules

In **ReplicatedStorage**, create a Folder named `Modules` and add two **ModuleScript** objects:

- `GameConfig` — paste contents of `ReplicatedStorage/Modules/GameConfig.lua`
- `MapManager` — paste contents of `ReplicatedStorage/Modules/MapManager.lua`

## 3. Add the Server Modules

In **ServerScriptService**, add three **ModuleScript** objects:

- `GameState` — paste `ServerScriptService/GameState.lua`
- `InventoryManager` — paste `ServerScriptService/InventoryManager.lua`
- `DataManager` — paste `ServerScriptService/DataManager.lua`

## 4. Add the Server Scripts

In **ServerScriptService**, add two **Script** objects (not ModuleScript):

- `GameServer` — paste `ServerScriptService/GameServer.server.lua`
- `PlacementHandler` — paste `ServerScriptService/PlacementHandler.server.lua`

## 5. Add the Client Scripts

In **StarterPlayer > StarterPlayerScripts**, add two **LocalScript** objects:

- `PlacementClient` — paste `StarterPlayerScripts/PlacementClient.client.lua`
- `UIController` — paste `StarterPlayerScripts/UIController.client.lua`

## 6. Build the Map

In **Workspace**, create a Folder named `Map` with:

```
Map/
  SpawnPoints/       ← Folder with 4 Part objects (anchored, CanCollide = false, Transparency = 1)
                       Place them ~200 studs apart in a square pattern
  PlayerBuilds/      ← Empty Folder (blocks placed during gameplay go here)
```

Position the spawn Parts where you want players to start each round.

Add your baseplate / terrain however you like. Leave enough open space for players to build traps.

## 7. Enable DataStore Access (for wins/losses)

In **Game Settings → Security**, toggle **"Enable Studio Access to API Services"**.

## 8. Test

1. Open Studio → click **Play** (the server icon) to run a local server
2. Add a second playtest client with **Test → Clients and Servers**
3. Wait for lobby countdown → confirm both players spawn at the spawn points
4. Place a Lava block → trigger a swap → confirm the other player takes damage
5. One player dies → confirm "RESULTS" screen shows the winner
6. Map resets and lobby restarts automatically

## Controls

| Input | Action |
|---|---|
| 1 – 5 | Switch hotbar slot |
| Left click | Place selected block |
| Right click / E | Remove targeted block (50% refund) |

## Adjusting Difficulty

All timings and block counts are in `GameConfig.lua`:

- `SWAP_INTERVAL` — seconds between swaps (default 90)
- `SWAP_REDUCTION` — how much faster each swap comes (default 10s)
- `MIN_SWAP_INTERVAL` — fastest possible swap (default 20s)
- `STARTING_INVENTORY` — how many of each block type players start with
