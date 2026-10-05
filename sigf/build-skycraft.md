# SkyCraft SKSE plugin: SIGF's reproducible build

SkyCraft (chasmlol, MIT) ships its Skyrim side as `SkyCraft.dll`, an SKSE64 plugin statically linked with
alandtse/CommonLibSSE-NG (GPL-3.0-or-later WITH the Modding Exception) and with the packages upstream's
`skse/vcpkg.json` takes from vcpkg (fmt, spdlog, DirectXTK, DirectXMath, nlohmann-json, rapidcsv, simpleini, toml11,
xbyak; MIT / BSD-3-Clause). The binary is therefore distributed under the GPL, and whoever redistributes it owes its
Corresponding Source. Upstream pins CommonLibSSE-NG (submodule `d61bca4`) but not the vcpkg packages: its manifest has
no `builtin-baseline`, so the versions are whatever the builder's `git clone microsoft/vcpkg` had. The SIGF app
therefore ships **our own build** of the same sources, with vcpkg pinned too. `package-fusion.mjs` uses this DLL
(pinned sha256) instead of upstream's and writes every repository + commit into `SOURCE.txt` next to the plugin.

Files:

| Path | What |
|---|---|
| `orchestrator/scripts/build-skycraft.ps1` | The build: tools, clones at pinned commits (verified), the vcpkg pin, upstream's build steps, toolchain record |
| `orchestrator/fusions/skycraft/SkyCraft.dll` | The DLL we ship (reference build below) |
| `orchestrator/fusions/skycraft/build-info.json` | Its provenance: sources + commits, vcpkg packages (version, port-version, ABI hash), source archives (sha512), toolchain, commands, sha256 |
| `orchestrator/fusions/skycraft/vcpkg.json` | The vcpkg manifest used: upstream's dependency list, `builtin-baseline` + one `overrides` entry per port |
| `orchestrator/fusions/skycraft/vcpkg-status.txt` | vcpkg's install database from the build (every package, feature and ABI hash) |
| `orchestrator/fusions/skycraft/x64-windows-static-md.cmake` | The overlay triplet: vcpkg's own `x64-windows-static-md` plus `VCPKG_PLATFORM_TOOLSET_VERSION 14.50` |

## Pinned sources

| Repository | Commit | License | Why this commit |
|---|---|---|---|
| github.com/chasmlol/SkyCraft | `bfcaf178524b92c2cdeb88e4ce0f13ef9ded6f32` | MIT | tag v0.1.2 (the release we package) |
| github.com/alandtse/CommonLibSSE-NG (`.gitmodules`: its former name `CommonLibVR`) | `d61bca4de789428aa7d98a770b1323ddf1bb855c` | GPL-3.0-or-later WITH Modding Exception | SkyCraft's submodule pointer at v0.1.2 |
| github.com/ValveSoftware/openvr | `60eb187801956ad277f1cae6680e3a410ee0873b` | BSD-3-Clause | CommonLibSSE-NG's submodule pointer; include path only (`ENABLE_SKYRIM_VR` off), not linked |
| github.com/microsoft/vcpkg | `4a1c77189c64dae7afd478333a64d1e604d5dc91` | MIT | master at 2026-10-01 00:01 UTC, the last commit before upstream's DLL was linked (PE timestamp 2026-10-01 01:35:39 UTC) |

The vcpkg packages at that commit (`vcpkg.json` overrides = vcpkg's `versions/baseline.json` there; every one of them
had been unchanged for at least two weeks before the upstream release: rapidcsv and simpleini last moved on 09-14, the
others in May to July 2026). Source = the GitHub tag archive the portfile downloads (sha512 pinned in the portfile and
in `build-info.json`); commit = that tag.

| vcpkg port | Upstream tag | Commit | License | Port patches |
|---|---|---|---|---|
| fmt 12.2.0#1 | fmtlib/fmt `12.2.0` | `1be298e1bd68957e4cd352e1f676f00e07dcfb57` | MIT | backport of fmt#4813 |
| spdlog 1.17.0#1 | gabime/spdlog `v1.17.0` | `79524ddd08a4ec981b7fea76afd08ee05f83755d` | MIT | backports of spdlog#3541, #3543 |
| directxtk 2026-05-07#1 | microsoft/DirectXTK `may2026` | `5a8f5d01cc1328e6451b588617c9985fa5a2a8ab` | MIT | |
| directxmath 2026-06-12 | microsoft/DirectXMath `jun2026` | `93e6399d6d15e1e57f80b5cea04d5a8eb892d693` | MIT | |
| nlohmann-json 3.12.0#2 | nlohmann/json `v3.12.0` | `55f93686c01528224f448c19128836e7df245f72` | MIT | fix-4736_char8_t, fix-4742_std_optional |
| rapidcsv 9.07 | d99kris/rapidcsv `v9.07` | `cbd8a0a937b249cc07e2db3bfa9cd2cc1689708f` | BSD-3-Clause | |
| simpleini 4.27 | brofield/simpleini `v4.27` | `fd6db69efc40a687bf4ef81486b54066e34992dd` | MIT | disable-tests |
| toml11 4.4.0 | ToruNiina/toml11 `v4.4.0` | `be08ba2be2a964edcdb3d3e3ea8d100abc26f286` | MIT | |
| xbyak 7.28 | herumi/xbyak `v7.28` | `12557954c68a780563f9ab9fc24a3a156c96cba1` | BSD-3-Clause | |

Plus the host helper ports `vcpkg-cmake` 2025-08-07 and `vcpkg-cmake-config` 2026-07-21 (build scripts, not linked).
fmt, spdlog and DirectXTK are compiled into static libraries; the others are header-only.

## Toolchain (reference build)

- Visual Studio Build Tools 2026 18.10.3, workload `Microsoft.VisualStudio.Workload.VCTools --includeRecommended` plus
  `Microsoft.VisualStudio.Component.VC.14.50.18.0.x86.x64`: MSVC toolset 14.50.35717, `cl` 19.50.35739, Windows SDK
  10.0.26100.0. Upstream's DLL was linked by 14.50 too (cl / link build 35721, an earlier 14.50 servicing build that
  the installer no longer offers; the newest 14.51 would change more). The plugin is built with `-T version=14.50`,
  and the vcpkg ports with the same toolset through the overlay triplet.
- CMake 4.4.3 (`cmake-4.4.3-windows-x86_64.zip`, sha256 `4d52ebab...26ab`), MinGit 2.56.0 (sha256 `064b440f...f718`),
  vcpkg tool 2026-09-26 (the release `scripts/vcpkg-tool-metadata.txt` names at the vcpkg commit; `vcpkg.exe` sha256
  `2a4ae146...01f2`), and the helper tools vcpkg fetches itself, pinned by sha512 in its `scripts/vcpkg-tools.json`
  (PowerShell 7.6.6, 7-Zip 26.03, msys2 pkgconf: listed in `build-info.json`, not linked)
- Windows Server 2025 Datacenter (EC2 AMI `Windows_Server-2025-English-Full-Base-2026.09.17`), as SYSTEM over SSM

## Commands

On a clean Windows x64 machine (nothing else needed; the script downloads git, CMake and the VS Build Tools):

```powershell
powershell -ExecutionPolicy Bypass -File orchestrator\scripts\build-skycraft.ps1 -InstallTools -VerifyRepro
# -> C:\skybuild\out\SkyCraft.dll (.pdb, build-info.json, vcpkg.json, vcpkg-status.txt, vcpkg-sources.zip, build.log)
```

What it runs (`D:` is a `subst` of `C:\skybuild\d`, so the tree sits at upstream's own `D:\skycraft`):

```bat
git clone --recursive https://github.com/chasmlol/SkyCraft D:\skycraft   & rem checked out at bfcaf17; submodules verified: d61bca4 / 60eb187
git clone https://github.com/microsoft/vcpkg D:\skycraft\.tools\vcpkg     & rem checked out at 4a1c771
D:\skycraft\.tools\vcpkg\bootstrap-vcpkg.bat -disableMetrics
rem C:\skybuild\manifest\vcpkg.json   = orchestrator/fusions/skycraft/vcpkg.json (written by the script from the vcpkg checkout)
rem C:\skybuild\triplets\x64-windows-static-md.cmake = orchestrator/fusions/skycraft/x64-windows-static-md.cmake
cd D:\skycraft\skse
set CXXFLAGS=/Brepro
set LDFLAGS=/Brepro
cmake --preset default -T version=14.50 -DVCPKG_MANIFEST_DIR=C:\skybuild\manifest -DVCPKG_OVERLAY_TRIPLETS=C:\skybuild\triplets -DCOMMONLIB_PREBUILT=OFF -DSKYCRAFT_DEPLOY_DIR=
cmake --build --preset release
rem -> build\RelWithDebInfo\SkyCraft.dll
```

Upstream's presets unchanged (Visual Studio 18 2026 generator, x64, triplet `x64-windows-static-md`, the `release`
build preset = RelWithDebInfo, as upstream's DLL: its PDB path is `D:\skycraft\skse\build\RelWithDebInfo\SkyCraft.pdb`).
Additions: the vcpkg manifest dir and overlay triplet (the pins), `-T version=14.50`, `/Brepro` (the PE timestamp
becomes a content hash; with it the anonymous-namespace hashes no longer depend on the compile time),
`COMMONLIB_PREBUILT=OFF` (CommonLibSSE-NG can fetch a prebuilt library on a release tag in CI; never here: the log is
checked) and an empty `SKYCRAFT_DEPLOY_DIR` (the build never copies into a Mod Organizer folder). `-VerifyRepro` deletes
`build\` and builds again (vcpkg restores its packages from the binary cache) and compares the DLL bytes.

## Result

| | Ours | Upstream v0.1.2 (`SkyCraft-0.1.2.zip`, `SKSE/Plugins/SkyCraft.dll`) |
|---|---|---|
| sha256 | `05dab4e9860a4bfd9d7ceac06e8d940c943ebc62200c62a783c649412f7f8e33` | `72b0d231f4632cf2268514eece90e9b7adaa2b59c648fcf14aaf55a6513eefa3` |
| size | 4,037,120 B | 4,036,608 B |
| rebuild (`-VerifyRepro`, `build\` wiped) | identical sha256 | n/a |
| exports | `SKSEPlugin_Load` (1), `SKSEPlugin_Query` (2), `SKSEPlugin_Version` (3) | same (Query and Version at the same RVAs, Load at `0xf489` vs `0xf493`) |
| `SKSEPlugin_Version` | dataVersion 1, version 0.1.2.0, name `SkyCraft`, author `chasmlol`, versionIndependence 1 (Address Library, post-AE), versionIndependenceEx 3 (no struct use + Address Library v5), compatibleVersions unused (CommonLibSSE-NG default `1.0.0.0` x16), minimum SKSE 0 | identical (same bytes, same RVA `0x39ab60`) |
| supported runtimes | any Skyrim SE runtime with the post-AE Address Library: 1.6.x / 1.7.x (AE), not 1.5.97, not VR | same |
| imports | 26 DLLs, 462 functions (D3DCOMPILER_47, d3d11, dxgi, dbghelp, bcrypt, VERSION, MSVCP140, VCRUNTIME140(_1), UCRT, ...) | identical set |
| PDB path | `D:\skycraft\skse\build\RelWithDebInfo\SkyCraft.pdb` | identical |
| linker | 14.50 | 14.50 |
| Rich header | the same tool list, build 35739 (cl / link) where upstream has 35721; 35403 / 33145 / 30729 identical | |
| `.text` / `.rdata` virtual size | 3,100,191 / 671,730 | 3,100,063 / 671,554 |
| `.data`, `.pdata`, `.idata`, `.tls`, `.00cfg`, `.rsrc`, `.reloc` sizes | identical | |

Differences, all explained: the timestamp (`/Brepro` hash vs 2026-10-01 01:35:39 UTC); the compiler servicing build
(19.50.35739 vs 35721: `.text` +128 B, `.rdata` +176 B, and code addresses shift from there, so the section bytes
differ); the anonymous-namespace hashes in 18 RTTI type names (`?A0x...`: without `/Brepro` they include the compile
time). No `__DATE__` / `__TIME__` string is in either DLL; every other printable string is identical, including every
source path (`D:\skycraft\...`) and the CommonLibSSE-NG URL. That upstream's DLL has the same section layout, imports
and data sizes as ours, within 0.01 %, is consistent with upstream's vcpkg clone having had the same ports (it does not
prove it: upstream recorded nothing).

Not verified in game: nobody launched Skyrim. Loading the plugin with SKSE64 on an AE runtime (check
`Documents\My Games\Skyrim Special Edition\SKSE\SkyCraft.log`) and a SkyCraft session with Minecraft is a human step.

Cost of the reference build: one c6i.2xlarge Windows on-demand instance (`i-0a2c81b95e6ab3d41`, eu-west-1) for 68 min,
terminated by the driver; about 1 USD.

## Updating

New upstream release or new pins: change the parameters (or defaults) of `build-skycraft.ps1`, build on a temporary
Windows VM (never mod-gpu, never a team PC), copy the outputs into `orchestrator/fusions/skycraft/`, set
`FUSIONS.skycraft.linked` (commits, versions, ports) and `rebuild.dll.sha256` / `toolchain` / `packages` in
`package-fusion.mjs`, bump `FUSIONS.skycraft.version` (X.Y.Z only: upstream 0.1.2 + SIGF revision n = `0.1.2nn`),
then `node orchestrator/scripts/package-fusion.mjs skycraft --fixture` and the tests. `--upstream-dll` packages
upstream's binary instead (then the vcpkg package versions are not known exactly).
