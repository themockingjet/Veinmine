# StrVeinMine

## Unofficial community compatibility build for Valheim

> **Version 0.1.1** - prepared for a private Valheim server and maintained in the community by `$tr` on Hexium.

This is an unofficial compatibility build of the upstream VeinMine mod. It is not an official release and is not endorsed, supported, or published by WiseHorror, Azumatt, Odin Plus, Thunderstore, or Nexus Mods.

The public package name is `StrVeinMine`, which is valid for package validators that permit only letters, digits, and underscores. It does not establish a Hexium or Thunderstore publisher namespace, team, or upload account. Publishing identity remains pending operator confirmation.

## Features

- Mine connected rock and ore deposits while holding the configured vein-mine key (`Left Alt` by default).
- Supports current `MineRock5` deposits and legacy `MineRock` deposits.
- Uses Valheim's native damage handlers so native drops, destruction, health/network state, durability, and XP behavior remain intact.
- Includes progressive mining, configurable radius, durability, XP, and spread-damage controls.
- Includes rebuilt ServerSync support for synchronized server configuration without the obsolete Valheim connection-error UI patch.
- Allows each client to suppress only native hit and destruction effects during vein mining to reduce large legacy-deposit effect bursts.

## Compatibility and exact-build requirement

This build was compiled and statically validated against staged Valheim **1.0.12** assemblies for the operator's private server. It is not a general public compatibility claim, and this package does not represent a live game-server runtime test.

> **Client and server warning:** install the exact same `StrVeinMine` **0.1.1** DLL on the server and every connecting client. Do not rely on version text alone; verify this SHA-256 hash:
>
> `7f187a2a2b1acb8331d7b32642504c7b21450ffa9235c1f6a35cfc88474220e0`

VeinMine's bundled configuration synchronization performs version checks. Mixing DLLs can prevent clients from connecting or leave players with incompatible behavior.

## Installation

### Hexium package installation

Use this method only after an operator has published `StrVeinMine` to a confirmed Hexium publisher namespace:

1. Install the exact `StrVeinMine` version `0.1.1` on the server and every client through Hexium.
2. Confirm the displayed archive or DLL hash matches the value above.
3. Restart the server and clients before connecting.

No Hexium or Thunderstore upload account is assigned by this repository or release package.

### Manual installation

1. Stop the Valheim server and all clients.
2. Back up the existing `Veinmine.dll` from each `BepInEx/plugins` directory.
3. Extract the release ZIP and copy its `Veinmine.dll` into `BepInEx/plugins` on the server and every client.
4. Verify the copied DLL SHA-256 matches the value above.
5. Start the server, then start the clients.

The package contains a PDB for diagnostics, a checksum file, the changelog, and the original MIT license. Only `Veinmine.dll` is required at runtime.

## Configuration

The configuration file is `BepInEx/config/com.wisehorror.Veinmine.cfg`. Server-synced settings are controlled by the server when configuration locking is enabled. Local settings remain per-client.

| Section | Setting | Default | Scope | Details |
|---|---|---:|---|---|
| 1 - General | Lock Configuration | On | Server-synced | Limits synchronized configuration changes to server administrators. |
| 2 - General | Veinmine | Left Alt | Local | Hold this key while mining to activate vein mining. |
| 2 - General | Durability | On | Server-synced | Charges durability as though each mined section were mined manually. |
| 3 - Visual | Remove Effects | Off | Local | Suppresses only native hit and destruction effects during Alt vein mining. |
| 4 - Progressive | Enable Progressive | Off | Server-synced | Limits the mined area according to Pickaxes skill. |
| 4 - Progressive | Radius Multiplier | 0.1 | Server-synced | Multiplied by Pickaxes skill to calculate progressive radius. |
| 4 - Progressive | Durability Multiplier | 1.0 | Server-synced | Adjusts progressive-mode durability loss. |
| 4 - Progressive | XP Multiplier | 0.2 | Server-synced | Adjusts XP awarded per progressive mined section. |
| 4 - Progressive | Enable Spread Damage | Off | Server-synced | Distributes hit damage instead of applying full damage to each section. |
| 4 - Progressive | Spread Damage Type | Distance | Server-synced | Uses distance or Pickaxes level to scale spread damage. |

<details>
<summary><strong>Progressive mining details</strong></summary>

With progressive mode enabled, the mining radius is `Pickaxes skill × Radius Multiplier`. For example, Pickaxes level 30 with the default `0.1` multiplier gives a radius of 3.

`Spread Damage Type` is used only when spread damage is enabled:

- **Distance:** farther sections receive less pickaxe damage.
- **Level:** damage scales with Pickaxes skill.

</details>

<details>
<summary><strong>Remove Effects details</strong></summary>

`Remove Effects` is intentionally local and is not synchronized by the server. Enable it separately on each client that needs it. While the vein-mine key is held, it suppresses the native hit and destruction effect lists for both modern `MineRock5` and legacy `MineRock` sections.

It does not suppress or replace damage, item drops, deposit destruction, health/ZDO updates, network RPCs, durability, XP, noise, or player statistics.

</details>

## Known behavior and troubleshooting

| Symptom | What to check |
|---|---|
| Vein mining does not activate | Hold the configured key while using a valid pickaxe on a valid deposit. Tool tier and normal Valheim damage checks still apply. |
| Client cannot connect after updating | Stop the server and all clients, then replace every copy with the exact 0.1.1 DLL and verify the SHA-256 hash. |
| Large legacy stone deposit causes visual lag | Enable `3 - Visual / Remove Effects` on the affected client, then reconnect or reload the configuration. |
| A local visual setting does not match another player | This is expected for `Veinmine` key binding and `Remove Effects`; both are intentionally local. |
| Server configuration does not update | Confirm the server configuration is unlocked for an administrator. Use a BepInEx configuration manager where available, then restart if the file watcher does not apply the change. |
| Unexpected gameplay issue | Treat this as a private-server compatibility build, collect BepInEx logs and the DLL hash, and test with all participants on the same package. |

## Credits and license

VeinMine is upstream work copyrighted by **WiseHorror/Azumatt (2023)**. This community compatibility build retains the original MIT license and copyright notice without changing ownership or implying upstream endorsement.

- Original source: <https://github.com/WiseHorror/Veinmine>
- Included license: [LICENSE.md](./VeinMine/LICENSE.md)
- Community-maintainer attribution for this build: `$tr` on Hexium
- Package thumbnail: original artwork created for this community compatibility build

No Thunderstore publisher namespace, team, or upload account is claimed by this project.
