# StrVeinMine Community Compatibility Build Changelog

## 0.2.2

- Remove the source-build instructions from the published README.
- Bump the package version so package managers refresh the corrected README
  instead of retaining a cached 0.2.1 package.
- Merge ServerSync into `Veinmine.dll` for Release packages; no separate
  `ServerSync.dll` is distributed.

## 0.2.1

- Powered tree felling now carries through the native tree-log spawn flow.
  A single qualifying Veinmine-key axe strike destroys the spawned log
  segments after Valheim's brief spawn-protection delay, producing native wood
  drops without additional player hits.

## 0.2.0

- Modernize the development build to SDK-style MSBuild and a current .NET SDK.
- Replace `packages.config`, the old ILRepack task, and machine-specific
  legacy project settings with maintained SDK package references and explicit
  Valheim/BepInEx build paths.
- Publicize the locally installed Valheim assemblies at build time with
  `BepInEx.AssemblyPublicizer.MSBuild`.
- Retain native `MineRock` and `MineRock5` handling for broad deposit support
  on current Valheim.
- Add a server-synchronized `Enable Trees` setting, disabled by default.
  Holding the configured Veinmine key with an axe now destroys a supported
  standing tree or log in one native hit.
- Package `ServerSync.dll` explicitly alongside `Veinmine.dll`.

## 0.1.1

- Bump the immutable public package version after the 0.1.0 upload so servers and clients can identify this refreshed build correctly.
- Replace the inherited package art with the finalized original, plain, symmetric StrVeinMine thumbnail.
- No intended mining-behavior change from 0.1.0; this release retains the Valheim 1.0.12 compatibility and `Remove Effects` freeze fix.

## 0.1.0

This is an unofficial private-server compatibility build, reset to an independent community build version. The confirmed validator-safe package name is `StrVeinMine`. It is not endorsed, supported, or published by WiseHorror, Azumatt, Odin Plus, Thunderstore, or Nexus Mods.

### Compatibility

- Targets Valheim 1.0.12 through its native `MineRock5` and legacy `MineRock` handlers.
- Applies the local `Remove Effects` setting to native hit and destruction effects in both mining paths, preventing the large effect burst that can freeze clients during legacy stone-deposit vein mining.
- Preserves Valheim-native drops, destruction, health/network behavior, durability, XP, and damage handling.
- Stops dispatching additional vein-mining RPCs after the deposit's network object is destroyed.
- Bundles ServerSync without the obsolete `FejdStartup.ShowConnectError` UI patch while retaining configuration synchronization RPCs.
- Replaces the inherited package thumbnail with original StrVeinMine community artwork.

### Distribution and attribution

- Packaged for the operator's private server and statically validated against staged Valheim 1.0.12 assemblies. No live game-server runtime test is represented by this release.
- The intended community-maintainer attribution is `$tr` on Hexium. It is not a Thunderstore publisher namespace, team, or upload account; any Thunderstore publishing identity remains pending operator confirmation. Do not present this build as an upstream or officially endorsed release.
- Retains the upstream MIT license and WiseHorror/Azumatt (2023) copyright notice.
