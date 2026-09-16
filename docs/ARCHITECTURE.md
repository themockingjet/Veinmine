# StrVeinMine Architecture

## Purpose

StrVeinMine extends Valheim's native mining and tree damage flows so a
qualifying hit can reach connected resource sections while preserving the
game's own damage, drops, destruction, network, durability, and skill systems.
It discovers supported content through native components rather than a prefab
allowlist.

## Runtime flow

1. BepInEx loads `VeinMinePlugin` from `Veinmine.dll`.
2. `Awake` creates the static plugin instance, binds the existing configuration
   entries, registers the ServerSync locking entry, applies Harmony patches,
   and starts the existing configuration file watcher.
3. A player action reaches a native `TreeBase`, `TreeLog`, `MineRock`, or
   `MineRock5` damage method. The patches validate the held key, attacker,
   weapon, tool tier, and network view before expanding the hit.
4. Expanded hits are sent through Valheim's existing local and RPC damage
   handlers. Those handlers remain responsible for authority checks, health,
   drops, destruction, network replication, effects, durability, and skill
   behavior.
5. `OnDestroy` clears the static plugin instance and saves the current
   configuration. No custom network object or persistent gameplay state is
   created by the plugin.

## Components

| Component | Responsibility | Native API boundary |
| --- | --- | --- |
| `VeinMinePlugin` | Plugin lifecycle, logging, configuration binding, and Harmony setup | BepInEx `BaseUnityPlugin`, `ConfigFile`, `Harmony` |
| `Functions` | Reads Pickaxes skill values, validates tree-felling hits, and applies configured spread-damage scaling | Valheim `Player`, `Skills`, `ItemDrop.ItemData`, and Unity input/vector APIs |
| `MineRockDamagePatch` | Expands legacy `MineRock` hits across its native hit areas | `MineRock.m_hitAreas`, `ZNetView`, native `"Hit"` RPC |
| `MineRockHitEffectsPatch` | Temporarily suppresses legacy mining effects when the local setting is enabled | `MineRock.RPC_Hit`, native `EffectList` fields |
| `MineRock5DamagePatch` | Collects connected modern mine sections, applies progressive radius and spread damage, and invokes each native damage RPC | `MineRock5.SetupColliders`, `LoadHealth`, `Damage`, `DamageArea`, `ZNetView` |
| `MineRock5DamageAreaPatch` | Restores effects and applies the existing Pickaxes XP and durability adjustments after native section damage | `MineRock5.DamageArea`, `Player.RaiseSkill`, weapon durability |
| `TreeBaseDamagePatch` / `TreeLogDamagePatch` | Converts a qualifying held-key axe hit to the existing powered tree damage value | `TreeBase.Damage` and `TreeLog.Damage` |
| `TreeBaseRpcDamagePatch` / `TreeLogRpcDamagePatch` | Carries powered-hit context through native tree RPC calls | `TreeBase.RPC_Damage`, `TreeLog.RPC_Damage` |
| `TreeLogAwakePatch` | Replays the captured native hit after Valheim's log spawn-protection delay | `TreeLog.Awake`, `TreeLog.Damage` |
| `RegisterAndCheckVersion` / `VerifyClient` / `RemoveDisconnectedPeerFromVerified` | Enforces the strict plugin version and assembly-hash handshake for peers | `ZNet.OnNewConnection`, `ZNet.RPC_PeerInfo`, `ZNet.Disconnect`, `ZRpc` |

## Configuration and authority

`VeinMinePlugin` keeps the existing `ConfigSync` identity and policy:

- Display name: `Veinmine`
- ConfigSync identifier: `com.wisehorror.Veinmine`
- Current and minimum required version: `0.2.2`
- Locking entry: `1 - General / Lock Configuration`, enabled by default
- Synchronized gameplay entries: durability, tree support, progressive mode,
  radius, progressive durability, progressive XP, spread damage, and spread
  damage type
- Local entries: the Veinmine keyboard shortcut and `Remove Effects`

ServerSync is authoritative for synchronized entries. When locking is enabled,
only the server or an authorized server administrator can change those values;
clients receive the server's settings. The local key and local effects setting
remain per-client by design. The `config()` helper preserves the existing
`[Synced with Server]` and `[Not Synced with Server]` descriptions.

## Strict version handshake

`VersionHandshake.cs` registers a `Veinmine_VersionCheck` RPC when a peer
connects. Each side sends the exact plugin version and a SHA-256 hash of the
loaded `Veinmine.dll`. The server only allows `RPC_PeerInfo` to continue for a
peer that has passed both checks, disconnects mismatched peers with Valheim's
native error RPC, and removes disconnected peers from the validated set.
Because ServerSync is merged into the Release assembly, matching clients and
servers must use the same merged binary; the hash check remains strict.

## Native API boundaries and ownership

- `MineRock` and `MineRock5` are selected by their native components. The mod
  does not maintain a fragile prefab list.
- The patches clone `HitData`, set the native hit collider/point, and invoke
  the object's existing `"Hit"` or `"RPC_Damage"` RPC. They do not write
  networked health, ownership, ZDO state, drop tables, or destruction flags.
- Tree expansion uses the native `TreeBase`/`TreeLog` damage and RPC methods.
  Spawned logs are damaged through `TreeLog.Damage` after their normal
  spawn-protection delay.
- Attacker ZDOIDs are checked against the nearby player before expansion, and
  valid `ZNetView` instances are required. No peer claims ownership or
  bypasses Valheim's owner/server routing.
- Valheim remains responsible for native drop spawning, destruction,
  replication, network durability behavior, and ordinary non-Veinmine hits.

## Cleanup and out-of-scope behavior

The existing config watcher reloads the same config file and `OnDestroy` saves
configuration while clearing `VeinMinePlugin.Instance`. The plugin does not
create a custom network object or persist additional state. Harmony patch
lifetime follows the loaded plugin and Unity scene lifecycle.

The following are intentionally out of scope: hard-coded prefab allowlists,
direct ZDO or serialized-state edits, ownership claims, replacement drop
systems, replacement durability or skill systems, client-only authority for
networked destruction, and changing the public GUID, config keys, handshake
policy, license, or attribution.
