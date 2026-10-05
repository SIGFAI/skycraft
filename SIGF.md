# SkyCraft, mirrored for the SIGF app

**SkyCraft is made by [chasmlol](https://github.com/chasmlol).** All credit for the mod goes to them. The original
project, its issues and its updates live at **https://github.com/chasmlol/SkyCraft**. Go there to report bugs, follow
development or support the author.

This repository is a mirror kept by SIGFAI so the SIGF app can install SkyCraft in one click. It holds:

1. the upstream source tree, unchanged, at tag `v0.1.2`, commit
   [`bfcaf178524b92c2cdeb88e4ce0f13ef9ded6f32`](https://github.com/chasmlol/SkyCraft/tree/bfcaf178524b92c2cdeb88e4ce0f13ef9ded6f32),
   with its git submodules vendored as plain files at their pinned commits (below);
2. `mashup.json`, the SIGF app recipe (added by a later commit);
3. the release `v0.1.2`, whose assets are what the app downloads.

Nothing else was changed or added; this file (`SIGF.md`) is the only addition to the upstream tree in the first commit.
Upstream's `.gitmodules` is kept as it was, for reference: the submodule paths it lists are now ordinary folders.

## Licenses

| Part | License | Where |
|---|---|---|
| SkyCraft (SKSE plugin sources `skse/`, Fabric mod `fabric/`, `protocol/`, `tools/`, docs) | MIT, Copyright chasmlol | `LICENSE`, `THIRD-PARTY-NOTICES.md` |
| CommonLibSSE-NG, vendored at `skse/extern/CommonLibSSE-NG/` | GPL-3.0-or-later with the Modding Exception | `skse/extern/CommonLibSSE-NG/COPYING.txt`, `EXCEPTIONS.md`, `licenses/` |
| OpenVR, vendored at `skse/extern/CommonLibSSE-NG/extern/openvr/` (CommonLibSSE-NG's own submodule) | BSD-3-Clause, Copyright Valve Corporation | `skse/extern/CommonLibSSE-NG/extern/openvr/LICENSE` |

`SkyCraft.dll` statically links CommonLibSSE-NG, so the plugin binary is distributed under the GPL (with the Modding
Exception); SkyCraft's own code stays MIT. Every LICENSE, COPYING, EXCEPTIONS and NOTICE file is kept where upstream put it.

## Vendored submodules

| Path | Repository | Commit | License |
|---|---|---|---|
| `skse/extern/CommonLibSSE-NG` | https://github.com/alandtse/CommonLibSSE-NG (upstream's `.gitmodules` uses its former name, `alandtse/CommonLibVR`, branch `ng`) | `d61bca4de789428aa7d98a770b1323ddf1bb855c` | GPL-3.0-or-later WITH Modding Exception |
| `skse/extern/CommonLibSSE-NG/extern/openvr` | https://github.com/ValveSoftware/openvr | `60eb187801956ad277f1cae6680e3a410ee0873b` | BSD-3-Clause |

Each folder is byte-for-byte the tree of that commit (same git tree hash), so `git rev-parse HEAD:<path>` here equals
`git rev-parse <commit>^{tree}` in the original repository. SkyCraft builds with `ENABLE_SKYRIM_VR` off, so OpenVR is
only on the include path; it is vendored because it is part of the recursive checkout upstream's build expects.

## The release binaries

The release `v0.1.2` of this repository has two assets:

- `skycraft-skyrim.zip`: unpacked into Skyrim's `Data` folder. It holds upstream's `SkyCraft.dll`, `LICENSE.txt` and
  `THIRD-PARTY-NOTICES.md` **unchanged** from upstream's release
  [`SkyCraft-0.1.2.zip`](https://github.com/chasmlol/SkyCraft/releases/tag/v0.1.2) (sha256 `1133ecde...92c3`), a
  `SkyCraft.ini` with one line changed (`sArguments`, so the plugin starts the SIGF app's Prism instance), and a
  `SOURCE.txt` pointing here.
- `skycraft.mrpack`: a Modrinth pack for the Minecraft side: upstream's `skycraft-fabric-0.1.2.jar` unchanged
  (sha256 `ea429c73...92d9`), upstream's LICENSE, and download links (Modrinth, not rehosted) for Fabric API and e4mc.

The binaries were built by chasmlol from this tree: tag `v0.1.2` is commit `bfcaf17`, which pins CommonLibSSE-NG at
`d61bca4`. SIGF did not rebuild them. Upstream's SKSE build also takes permissively licensed packages from vcpkg
(`skse/vcpkg.json`: directxmath, directxtk, fmt, nlohmann-json, rapidcsv, simpleini, spdlog, toml11, xbyak; MIT /
BSD-style licenses, listed in `THIRD-PARTY-NOTICES.md`). Upstream's manifest has no vcpkg baseline, so the exact
package versions of the released DLL are not recorded upstream; vcpkg's registry at the release date (2026-10) gives them.

The sha256 of every asset, and of every file inside the zip, is in `mashup.json`.

## Rebuilding

Upstream's instructions are in `README.md` and `docs/`. In short, with Visual Studio 2026 (Desktop C++), CMake 3.25+,
vcpkg (`VCPKG_ROOT` set), JDK 25:

```
cd skse
cmake --preset default
cmake --build --preset release      # -> SkyCraft.dll
cd ../fabric
gradlew build                       # -> skycraft-fabric-0.1.2.jar
```

No `git submodule update` is needed here: the submodules are already in the tree.

## Why this mirror exists

The SIGF app (https://sigf.ai) installs mods with recipes (`mashup.json`) whose downloads come only from release assets
of SIGFAI repositories. This mirror makes SkyCraft available there, credited to chasmlol, and carries the GPL
Corresponding Source of the plugin binary next to it. If you are the author and want this changed or taken down, open
an issue here.
