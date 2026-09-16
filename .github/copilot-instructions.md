# StrVeinMine Agent Instructions

## Purpose

StrVeinMine is a multiplayer Valheim resource-gathering mod. It expands
qualifying native ore, stone, tree, and log damage across connected sections
while preserving Valheim ownership, RPC, drop, destruction, durability, and
skill systems.

## Compatibility

- Target Valheim version: current stable version used by the local reference cache.
- Loader: BepInEx 5.
- Runtime target: .NET Framework 4.8.
- Development SDK: .NET 8 or later.
- Build-time publicizer: `BepInEx.AssemblyPublicizer.MSBuild`.
- Config synchronization: ServerSync `ConfigSync` is authoritative for the
  existing synchronized gameplay settings and locking entry.
- Multiplayer: both client and server load the same merged plugin; native
  Valheim ownership and RPC flows remain authoritative.

## Critical game rules

- Only mutate networked objects through their valid ownership and RPC flows.
- Prefer native Valheim APIs over direct ZDO or serialized-state edits.
- Do not add hard-coded game data when the native API can discover it.
- Do not claim remote ownership without an explicit, approved ownership flow.

## Build and release

- Source the shared environment:
  `source "$HOME/.config/valheim-dev/env.sh"`.
- Run `make preflight` before building or releasing.
- Run `make build`.
- Run `make package`.
- Run `make verify-release`.
- Keep the build-time `ServerSync.dll` outside the repository at
  `$BEPINEX_PATH/core/ServerSync.dll`; Release builds merge it into the
  plugin with ILRepack.
- The release ZIP must contain exactly `manifest.json`, `README.md`,
  `CHANGELOG.md`, `icon.png`, and the merged `Veinmine.dll`. Do not package a
  separate ServerSync, Valheim, Unity, BepInEx, or Harmony reference DLL.

## Icon generation

- Fill in `docs/ICON_BRIEF.md` with this mod's subject/palette before
  requesting an icon.
- Use the `icon-generator` agent (`.github/agents/icon-generator.md`)
  to assemble a brand-consistent prompt and generate `Thunderstore/icon.png`.
- The shared brand system lives in the `valheim-mod-brand` repo/folder;
  do not invent a different frame, palette set, or lighting scheme.
- The generated subject must pass the anti-sameness checklist in
  `valheim-mod-brand/ICON_SYSTEM.md` — no plain recolored placeholder
  shapes as final art.

## Scope discipline

- Do not modify other repositories.
- Do not commit Valheim game assemblies or Steam content.
- Do not publish a ZIP containing a placeholder or unverified DLL.
- Update this file when compatibility or multiplayer rules change.