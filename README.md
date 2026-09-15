# StrVeinMine

StrVeinMine mines an entire connected deposit or destroys a tree/log with a
single qualifying hit while the configured Veinmine key is held.

## Features

- Mine connected modern and legacy Valheim deposits with the normal native
  damage, drop, destruction, network, durability, and skill systems.
- Optionally fell standing trees and destroy logs with one Veinmine-key axe
  strike.
- Progressive mining, spread damage, durability, Pickaxes XP, and local
  effects-suppression controls.
- Server-synchronized gameplay configuration.

## Supported resources

- Copper, tin, silver, iron scrap, and muddy scrap piles.
- Flametal, chitin, and leviathans. Chitin nodes are handled through their
  native mineable component, so the normal leviathan behavior remains intact.
- Beech, birch, oak, fir, pine, ancient, and other trees and logs.
- Yggdrasil and scorched trees.
- Stone deposits.

Support is selected by Valheim's native component rather than a fragile prefab
allowlist:

| Native component | Covered resources |
|---|---|
| `MineRock` and `MineRock5` | Ore, scrap piles, flametal, chitin on leviathans, stone, and other mineable deposits. |
| `TreeBase` | Standing standard, ancient, Yggdrasil, scorched, and other tree variants. |
| `TreeLog` | Fallen logs from the supported tree variants. |

## Installation

1. Install the current BepInExPack for Valheim on the server and every client.
2. Copy **both** `Veinmine.dll` and `ServerSync.dll` from the release package
   into each `BepInEx/plugins` directory.
3. Keep the same StrVeinMine version installed on the server and every client.

The included version handshake rejects mismatched client/server plugin builds.

## Configuration

The configuration file is `BepInEx/config/com.wisehorror.Veinmine.cfg`.
Server-synchronized values are controlled by the server while configuration
locking is enabled.

| Section | Setting | Default | Scope | Description |
|---|---|---:|---|---|
| 1 - General | Lock Configuration | On | Server | Allows only server administrators to change synchronized settings. |
| 2 - General | Veinmine | Left Alt | Local | Key to hold while vein mining or tree felling. |
| 2 - General | Durability | On | Server | Charges mining durability as though each section were mined manually. |
| 2 - General | Enable Trees | Off | Server | Allows a held Veinmine key and qualifying axe hit to destroy one standing tree or log. |
| 3 - Visual | Remove Effects | Off | Local | Suppresses native hit and destruction effects during Veinmine actions. |
| 4 - Progressive | Enable Progressive | Off | Server | Limits deposit mining radius by Pickaxes skill. |
| 4 - Progressive | Radius Multiplier | 0.1 | Server | Multiplier applied to Pickaxes skill for progressive mining radius. |
| 4 - Progressive | Durability Multiplier | 1.0 | Server | Adjusts progressive-mode durability loss. |
| 4 - Progressive | XP Multiplier | 0.2 | Server | Adjusts progressive-mode Pickaxes XP per section. |
| 4 - Progressive | Enable Spread Damage | Off | Server | Distributes damage across progressive-mining targets. |
| 4 - Progressive | Spread Damage Type | Distance | Server | Scales spread damage by distance or Pickaxes level. |

`Enable Trees` is disabled by default. When enabled, it only applies while the
Veinmine key is held and the hit originates from the attacking player using an
item with chop damage. The resulting log segments are destroyed through
Valheim's native handlers after their brief spawn-protection delay, so their
wood drops do not require additional hits. Normal attacks, non-axe tools, and
unrelated destructibles are unchanged.

## License and credits

VeinMine is upstream work copyrighted by WiseHorror/Azumatt (2023), retained
under the included [MIT license](./VeinMine/LICENSE.md). This repository's
StrVeinMine packaging is an unofficial community compatibility build and is
not an official upstream release.
