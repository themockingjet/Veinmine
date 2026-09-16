# StrVeinMine Compatibility

## Supported baseline

- Valheim: the current stable game/reference baseline represented by the
  assemblies under `VALHEIM_MANAGED_PATH` from the shared development
  environment.
- Loader: BepInEx 5.x, including the current BepInExPack for Valheim.
- Runtime: .NET Framework 4.8 (`net48`).
- Development SDK: .NET 8, selected by `global.json`.
- Build publicizer: `BepInEx.AssemblyPublicizer.MSBuild`.
- ServerSync: the build uses
  `$BEPINEX_PATH/core/ServerSync.dll`; Release ILRepack merges it into
  `Veinmine.dll`, so the package has no separate ServerSync runtime file.

The mod follows the shared reference cache and does not infer references from a
game-installation root. Rebuild when the local Valheim baseline changes and
verify the resulting client/server hash together.

## Multiplayer

- Side: both client and server. Install the same `Veinmine.dll` on every
  client and on the dedicated server.
- Authority: Valheim's native `ZNetView` and damage RPC flows remain
  authoritative. The mod only expands qualifying hits after validating the
  attacking player's ZDOID and a valid network view.
- Dedicated server: supported when the same plugin version is installed on the
  server and connecting clients. The plugin has no custom Unity asset bundle
  or client-only scene dependency.
- Local versus synchronized state: the Veinmine shortcut and `Remove Effects`
  are local; mining/tree/progressive/durability/XP/spread settings are
  ServerSync-authoritative.

## Configuration locking and version handshake

`ConfigSync` is always created with the preserved public identity:

- GUID: `com.wisehorror.Veinmine`
- Display name: `Veinmine`
- Current version: `0.2.2`
- Minimum required version: `0.2.2`

`1 - General / Lock Configuration` is enabled by default and is registered
with `AddLockingConfigEntry`. With locking enabled, server administrators are
the authority for synchronized settings; clients cannot replace those values.

The independent strict handshake in `VersionHandshake.cs` sends the exact
version plus a SHA-256 hash of the loaded merged plugin assembly. A server
disconnects a client if either value differs or if the client never completes
the version RPC before peer information is accepted. Clients and servers must
therefore install the same StrVeinMine release, not merely the same semantic
version.

## Installation expectations

1. Install BepInEx 5 on the server and every client.
2. Install the package's `Veinmine.dll` in `BepInEx/plugins` on both sides.
3. Do not install a separate `ServerSync.dll` from the package; it is merged
   into the Release plugin. Any build-time ServerSync file stays in the shared
   BepInEx core reference directory outside this repository.

## Dependencies

- Runtime: BepInEx 5.
- Embedded runtime code: ServerSync `ConfigSync`, merged into the Release
  `Veinmine.dll`.
- Build-time references: Valheim `assembly_valheim`, `assembly_utils`,
  `assembly_guiutils`, UnityEngine, UnityEngine.CoreModule,
  `UnityEngine.InputLegacyModule`, UnityEngine.PhysicsModule, BepInEx, and
  Harmony from the shared environment. These references are not packaged.

## Known conflicts

Mods that replace or substantially rewrite the following native methods can
conflict or change the order in which effects and damage are handled:
`TreeBase.Damage`, `TreeLog.Damage`, `TreeBase.RPC_Damage`,
`TreeLog.RPC_Damage`, `TreeLog.Awake`, `MineRock.Damage`, `MineRock.RPC_Hit`,
`MineRock5.Damage`, and `MineRock5.DamageArea`. Mods that bypass native
ownership, drop, durability, or destruction flows can also produce
incompatible results. No specific third-party conflict is asserted without a
reproducible test.

## Verification matrix

The repository's required release validation is:

```bash
source "$HOME/.config/valheim-dev/env.sh"
make preflight
make build
make package
make verify-release
```

Runtime verification should cover:

| Scenario | Expected result |
| --- | --- |
| Single-player mining with the key released | Native single-section behavior is unchanged. |
| Legacy `MineRock` and modern `MineRock5` with the key held | Connected sections use native hit/RPC, drop, destruction, durability, and skill flows. |
| Progressive and spread settings | Radius, damage scaling, XP, and durability follow the existing configuration values. |
| Trees disabled or non-axe hit | Normal tree/log behavior is unchanged. |
| Trees enabled with a qualifying held-key axe hit | Native tree/log handlers destroy the connected tree/log path and produce native drops. |
| Matching dedicated server and client | Join succeeds and synchronized settings come from the server. |
| Mismatched version or assembly hash | The strict handshake rejects the peer. |
| Release ZIP inspection | Exactly `manifest.json`, `README.md`, `CHANGELOG.md`, `icon.png`, and merged `Veinmine.dll`; no ServerSync, Valheim, Unity, BepInEx, or Harmony reference DLLs. |

The package retains the upstream WiseHorror/Azumatt license and attribution;
this is an unofficial community compatibility build, not an upstream release.
