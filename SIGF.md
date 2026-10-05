# SkyCraft, mirrored for the SIGF app

**SkyCraft is made by [chasmlol](https://github.com/chasmlol).** All credit for the mod goes to them. The original
project, its issues and its updates live at **https://github.com/chasmlol/SkyCraft**. Go there to report bugs, follow
development or support the author.

This repository is a mirror kept by SIGFAI so the SIGF app can install SkyCraft in one click. It holds:

1. the upstream source tree, unchanged, at tag `v0.1.2`, commit
   [`bfcaf178524b92c2cdeb88e4ce0f13ef9ded6f32`](https://github.com/chasmlol/SkyCraft/tree/bfcaf178524b92c2cdeb88e4ce0f13ef9ded6f32),
   with its git submodules vendored as plain files at their pinned commits (below);
2. the vcpkg packages the Skyrim plugin is compiled with, vendored as plain files under `vendor/` at pinned versions,
   with the vcpkg port scripts and patches that built them under `vendor/vcpkg/`;
3. SIGF's build script and build record for the plugin, under `sigf/`;
4. `mashup.json`, the SIGF app recipe, and the releases, whose assets are what the app downloads.

The upstream files are not modified. Upstream's `.gitmodules` is kept as it was, for reference: the submodule paths it
lists are now ordinary folders.

## Licenses

| Part | License | Where |
|---|---|---|
| SkyCraft (SKSE plugin sources `skse/`, Fabric mod `fabric/`, `protocol/`, `tools/`, docs) | MIT, Copyright chasmlol | `LICENSE`, `THIRD-PARTY-NOTICES.md` |
| CommonLibSSE-NG, vendored at `skse/extern/CommonLibSSE-NG/` | GPL-3.0-or-later with the Modding Exception | `skse/extern/CommonLibSSE-NG/COPYING.txt`, `EXCEPTIONS.md`, `licenses/` |
| OpenVR, vendored at `skse/extern/CommonLibSSE-NG/extern/openvr/` (CommonLibSSE-NG's own submodule) | BSD-3-Clause, Copyright Valve Corporation | `skse/extern/CommonLibSSE-NG/extern/openvr/LICENSE` |
| fmt, spdlog, DirectXTK, DirectXMath, nlohmann-json, simpleini, toml11 (`vendor/<name>/`) | MIT | each folder's `LICENSE` / `LICENSE.txt` / `LICENSE.MIT` |
| rapidcsv, xbyak (`vendor/<name>/`) | BSD-3-Clause | each folder's `LICENSE` / `COPYRIGHT` |
| vcpkg port scripts and patches (`vendor/vcpkg/`) | MIT, Copyright Microsoft Corporation (the backport patches: their projects' licenses) | `vendor/vcpkg/LICENSE.txt` |
| `sigf/` (build script and records) | MIT | this file |

`SkyCraft.dll` statically links CommonLibSSE-NG and the vcpkg packages, so the plugin binary is distributed under the
GPL (with the Modding Exception); SkyCraft's own code stays MIT. Every LICENSE, COPYING, EXCEPTIONS and NOTICE file is
kept where its project put it.

## Vendored sources

| Path | Repository | Commit | License |
|---|---|---|---|
| `skse/extern/CommonLibSSE-NG` | https://github.com/alandtse/CommonLibSSE-NG (upstream's `.gitmodules` uses its former name, `alandtse/CommonLibVR`, branch `ng`) | `d61bca4de789428aa7d98a770b1323ddf1bb855c` | GPL-3.0-or-later WITH Modding Exception |
| `skse/extern/CommonLibSSE-NG/extern/openvr` | https://github.com/ValveSoftware/openvr | `60eb187801956ad277f1cae6680e3a410ee0873b` | BSD-3-Clause |
| `vendor/fmt` (tag `12.2.0`, vcpkg port fmt 12.2.0#1) | https://github.com/fmtlib/fmt | `1be298e1bd68957e4cd352e1f676f00e07dcfb57` | MIT |
| `vendor/spdlog` (tag `v1.17.0`, port spdlog 1.17.0#1) | https://github.com/gabime/spdlog | `79524ddd08a4ec981b7fea76afd08ee05f83755d` | MIT |
| `vendor/DirectXTK` (tag `may2026`, port directxtk 2026-05-07#1) | https://github.com/microsoft/DirectXTK | `5a8f5d01cc1328e6451b588617c9985fa5a2a8ab` | MIT |
| `vendor/DirectXMath` (tag `jun2026`, port directxmath 2026-06-12) | https://github.com/microsoft/DirectXMath | `93e6399d6d15e1e57f80b5cea04d5a8eb892d693` | MIT |
| `vendor/nlohmann-json` (tag `v3.12.0`, port nlohmann-json 3.12.0#2) | https://github.com/nlohmann/json | `55f93686c01528224f448c19128836e7df245f72` | MIT |
| `vendor/rapidcsv` (tag `v9.07`, port rapidcsv 9.07) | https://github.com/d99kris/rapidcsv | `cbd8a0a937b249cc07e2db3bfa9cd2cc1689708f` | BSD-3-Clause |
| `vendor/simpleini` (tag `v4.27`, port simpleini 4.27) | https://github.com/brofield/simpleini | `fd6db69efc40a687bf4ef81486b54066e34992dd` | MIT |
| `vendor/toml11` (tag `v4.4.0`, port toml11 4.4.0) | https://github.com/ToruNiina/toml11 | `be08ba2be2a964edcdb3d3e3ea8d100abc26f286` | MIT |
| `vendor/xbyak` (tag `v7.28`, port xbyak 7.28) | https://github.com/herumi/xbyak | `12557954c68a780563f9ab9fc24a3a156c96cba1` | BSD-3-Clause |
| `vendor/vcpkg/ports/<port>` (the 9 ports above + `vcpkg-cmake`, `vcpkg-cmake-config`), `vendor/vcpkg/LICENSE.txt` | https://github.com/microsoft/vcpkg | `4a1c77189c64dae7afd478333a64d1e604d5dc91` | MIT |

Each folder is byte-for-byte the tree of that commit (same git tree hash), so `git rev-parse HEAD:vendor/fmt` here
equals `git rev-parse 1be298e^{tree}` in fmt's repository (one exception: `vendor/toml11` leaves out toml11's three
git submodules, a docs theme and two test libraries, which are not in the tag archive vcpkg builds from), and `HEAD:vendor/vcpkg/ports/fmt` equals
`4a1c771:ports/fmt` in vcpkg's. vcpkg builds each library from GitHub's archive of its tag (sha512 pinned in the
portfile); every file of each archive is in the vendored tree with the same bytes (DirectXTK and DirectXMath: same
bytes once checked out, their `.gitattributes` declare `eol=crlf`, which GitHub's archive applies and a checkout of
this repository applies too). vcpkg then applies the port's
patches: those in the port folder, and three upstream backports it downloads, vendored as
`vendor/vcpkg/downloads/fmt-backport-4813.patch`, `spdlog-backport-3541.patch` and `spdlog-backport-3543.patch`
(sha512 as pinned in the portfiles). SkyCraft builds with `ENABLE_SKYRIM_VR` off, so OpenVR is only on the include
path; it is vendored because it is part of the recursive checkout upstream's build expects.

## The release binaries

The release `v0.1.201` of this repository (SIGF's revision 1 of SkyCraft 0.1.2) has two assets:

- `skycraft-skyrim.zip`: unpacked into Skyrim's `Data` folder. It holds `SKSE/Plugins/SkyCraft.dll`, **built by SIGF
  from exactly the sources in this repository** (SkyCraft at `bfcaf17`, CommonLibSSE-NG at `d61bca4`, the vcpkg
  packages above from vcpkg `4a1c771`), sha256 `05dab4e9860a4bfd9d7ceac06e8d940c943ebc62200c62a783c649412f7f8e33`,
  4,037,120 bytes; upstream's `LICENSE.txt` and `THIRD-PARTY-NOTICES.md`, unchanged from upstream's release
  [`SkyCraft-0.1.2.zip`](https://github.com/chasmlol/SkyCraft/releases/tag/v0.1.2) (sha256 `1133ecde...92c3`); a
  `SkyCraft.ini` with one line changed (`sArguments`, so the plugin starts the SIGF app's Prism instance); and a
  `SOURCE.txt` pointing here.
- `skycraft.mrpack`: a Modrinth pack for the Minecraft side: upstream's `skycraft-fabric-0.1.2.jar` unchanged
  (sha256 `ea429c73...92d9`, built by upstream from `fabric/` in this tree), upstream's LICENSE, and download links
  (Modrinth, not rehosted) for Fabric API and e4mc.

SIGF ships its own build of the plugin because upstream's `skse/vcpkg.json` has no vcpkg baseline: the versions of the
vcpkg packages inside upstream's DLL are whatever its builder's vcpkg clone had, and are recorded nowhere. Our build
pins them (and matches upstream's DLL in exports, plugin version data, imports, section layout and strings; see
`sigf/build-skycraft.md`). The earlier release `v0.1.2` of this repository holds upstream's own DLL, for reference.

The sha256 of every asset, and of every file inside the zip, is in `mashup.json`.

## Rebuilding the plugin

`sigf/` has what produced the shipped DLL:

| File | What |
|---|---|
| `sigf/build-skycraft.ps1` | The build: installs the tools, clones each repository above and checks out its pinned commit (verified), pins vcpkg, runs upstream's build steps, records the toolchain |
| `sigf/build-skycraft.md` | Why these commits, the toolchain, the exact commands, and how our DLL compares to upstream's |
| `sigf/build-info.json` | The reference build's record: sources and commits, every vcpkg package (version, port-version, ABI hash), every source archive (sha512), toolchain versions, commands, sha256 of the DLL and of a second clean rebuild (identical) |
| `sigf/vcpkg.json` | The vcpkg manifest used: upstream's dependency list, `builtin-baseline` = the vcpkg commit, an `overrides` entry per port |
| `sigf/x64-windows-static-md.cmake` | The overlay triplet: vcpkg's own, plus the MSVC toolset version (14.50) |
| `sigf/vcpkg-status.txt` | vcpkg's install database from that build |

(`build-skycraft.md` names them by their paths in SIGF's own repository, `orchestrator/scripts/` and
`orchestrator/fusions/skycraft/`.)

On a clean Windows x64 machine:

```powershell
powershell -ExecutionPolicy Bypass -File sigf\build-skycraft.ps1 -InstallTools -VerifyRepro
# -> C:\skybuild\out\SkyCraft.dll
```

The script clones the original repositories at the commits above, which are the trees vendored here, with Visual
Studio Build Tools 2026 (MSVC toolset 14.50, Windows SDK 10.0.26100.0), CMake 4.4.3 and vcpkg at `4a1c771`. Upstream's
own steps (README, "Building from source") are, from this tree: `git clone https://github.com/microsoft/vcpkg
.tools\vcpkg` (then `git checkout 4a1c77189c64dae7afd478333a64d1e604d5dc91` and `.tools\vcpkg\bootstrap-vcpkg.bat`),
then in `skse\` `cmake --preset default` and `cmake --build --preset release`; `sigf/build-skycraft.md` lists the pins
and flags SIGF adds. The same toolchain in the same folder (`D:\skycraft`) gives the same bytes. The Fabric jar builds
with JDK 25: `gradlew build` (see upstream's README).

## Why this mirror exists

The SIGF app (https://sigf.ai) installs mods with recipes (`mashup.json`) whose downloads come only from release assets
of SIGFAI repositories. This mirror makes SkyCraft available there, credited to chasmlol, and carries the GPL
Corresponding Source of the plugin binary next to it. If you are the author and want this changed or taken down, open
an issue here.
