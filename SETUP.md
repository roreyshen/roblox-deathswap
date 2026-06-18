# Roblox Deathswap — Studio Setup Guide

## 1. Create the RemoteEvents

In **ReplicatedStorage**, create a Folder named `RemoteEvents` and add these **RemoteEvent** objects:

| Name | Direction | Purpose |
|---|---|---|
| SwapPlayers | Server → All | Triggers swap flash on clients |
| PlaceBlock | Client → Server | Place a trap block |
| RemoveBlock | Client → Server | Remove a trap block |
| RoundStateChanged | Server → All | Broadcasts state changes (LOBBY / COUNTDOWN / SETUP / PLAYING / RESULTS) |
| UpdateTimers | Server → All | Sends swap timer, round timer, and setup countdown |
| UpdateInventory | Server → Client | Sends updated inventory to one player |
| PlaceAnchor | Client → Server | Place the player's Soul Crystal |
| MineAnchor | Client → Server | Hit an opponent's Soul Crystal |
| AnchorDestroyed | Server → All | Notifies all clients a crystal was destroyed |
| AnchorHealthUpdate | Server → All | Sends current HP of a crystal after each hit |
| PlayerRespawning | Server → Client | Tells client how many seconds until anchor respawn |
| PlayerEliminated | Server → All | Notifies all clients a player was permanently eliminated |

## 2. Add the Shared Modules

In **ReplicatedStorage**, create a Folder named `Modules` and add two **ModuleScript** objects:

- `GameConfig` — paste `ReplicatedStorage/Modules/GameConfig.lua`
- `MapManager` — paste `ReplicatedStorage/Modules/MapManager.lua`

## 3. Add the Server Modules

In **ServerScriptService**, add four **ModuleScript** objects:

- `GameState` — paste `ServerScriptService/GameState.lua`
- `InventoryManager` — paste `ServerScriptService/InventoryManager.lua`
- `DataManager` — paste `ServerScriptService/DataManager.lua`
- `AnchorManager` — paste `ServerScriptService/AnchorManager.lua`

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
  SpawnPoints/       ← Folder with 4 Part objects (Anchored, CanCollide=false, Transparency=1)
                       Place them ~200 studs apart so each player has their own platform area
  PlayerBuilds/      ← Empty Folder (blocks and Soul Crystals placed during gameplay go here)
```

**Recommended map layout for pillars/platforms:**
- Four separate platforms 200+ studs apart and elevated ~80 studs above a void baseplate
- Each platform ~30×30 studs — big enough to build a small fort
- Void below kills on contact (or use a kill brick with `Touched → TakeDamage(9999)`)

## 7. Enable DataStore Access

In **Game Settings → Security**, toggle **"Enable Studio Access to API Services"**.

## 8. Test

1. Open Studio → **Test → Start** (local server)
2. Add a second client with **Test → Clients and Servers**
3. Wait through Lobby → Countdown
4. **SETUP phase (60s):** Both players spawn. Left-click to place your Soul Crystal (cyan block).
   Build walls/traps around it with keys 1–5. Watch the 60s timer in the banner.
5. **PLAYING:** Swap countdown appears top-center. At 10s the big red number starts.
   Both players get teleported to wherever each other **currently is** when the timer hits 0.
6. Stand on a platform, jump off right before swap — opponent gets your mid-air position.
7. Die → respawn at your crystal after 4s (25% inventory gone).
8. Walk up to opponent's crystal and press **E** repeatedly (1s cooldown per hit, 5 hits = destroyed).
9. Once crystal is destroyed, next death = permanent elimination.

## Controls

| Input | Action |
|---|---|
| 1 – 5 | Switch hotbar slot (trap blocks) |
| Left-click | Place selected block (SETUP + PLAYING) / Place Soul Crystal during SETUP |
| Right-click / E | Remove block (50% refund) or mine opponent's Soul Crystal |

## Game Flow

```
LOBBY  →  COUNTDOWN (15s)  →  SETUP (60s)  →  PLAYING  →  RESULTS
                                  ↑                ↓
                             build base       swap every 90s
                             place Crystal    (countdown speeds up)
                                              die w/ Crystal → respawn (-25% items)
                                              Crystal destroyed → mortal
                                              die mortal → eliminated
```

## Adjusting Values

All timings are in `GameConfig.lua`:

| Key | Default | What it does |
|---|---|---|
| `SETUP_DURATION` | 60 | Seconds for the build/anchor phase |
| `ANCHOR_MAX_HP` | 5 | Hits to destroy a Soul Crystal |
| `ANCHOR_MINE_COOLDOWN` | 1 | Seconds between hits on the same crystal |
| `RESPAWN_DELAY` | 4 | Seconds before anchor respawn |
| `DEATH_LOSS_RATE` | 0.25 | Fraction of items lost on anchor respawn |
| `SWAP_INTERVAL` | 90 | Seconds between swaps at round start |
| `SWAP_COUNTDOWN` | 10 | Seconds of big countdown warning before each swap |
| `SWAP_REDUCTION` | 10 | How much faster swaps get each time |
| `MIN_SWAP_INTERVAL` | 25 | Fastest possible swap interval |
