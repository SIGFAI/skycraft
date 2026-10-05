<#
SkyCraft's Skyrim SKSE plugin (SkyCraft.dll) built from pinned sources, so the binary the SIGF app redistributes has
exactly known GPL-3.0 Corresponding Source, vcpkg packages included. See build-skycraft.md for the why, the pins and
the result of the reference build.

  powershell -ExecutionPolicy Bypass -File build-skycraft.ps1 -InstallTools -VerifyRepro   (fresh Windows: tools + build)
  powershell -ExecutionPolicy Bypass -File build-skycraft.ps1                              (tools already installed)

Upstream's build (README "Building from source"): `git clone --recursive` SkyCraft, `git clone microsoft/vcpkg
.tools\vcpkg` + bootstrap, then in skse\ `cmake --preset default` and `cmake --build --preset release`
(Visual Studio 18 2026 generator, x64, triplet x64-windows-static-md, RelWithDebInfo). This script does exactly that,
with every repository at a pinned 40-character commit (verified), and:
  - vcpkg at a pinned commit, plus a manifest of upstream's dependencies with builtin-baseline = that commit and an
    `overrides` entry per port (its exact version), passed with VCPKG_MANIFEST_DIR (upstream's vcpkg.json has no
    baseline, so it takes whatever ports its vcpkg clone has);
  - MSVC toolset 14.50 (upstream's DLL was linked by 14.50) for the plugin and, through an overlay triplet, for the
    vcpkg ports; -MsvcVersion '' uses the newest installed toolset;
  - /Brepro (CXXFLAGS / LDFLAGS), so the same toolchain in the same folder gives the same bytes;
  - the tree at D:\skycraft, upstream's own path (a `subst` drive when D: is free), so __FILE__ strings and the PDB
    path match upstream's.
Writes <Out>\SkyCraft.dll, .pdb, build-info.json, vcpkg.json (the manifest used), vcpkg-status.txt,
vcpkg-sources.zip (every port's source archive as vcpkg downloaded it, plus the port scripts), build.log.
Never installs into a game: SKYCRAFT_DEPLOY_DIR is set empty.
#>
param(
  [string]$Work = 'C:\skybuild',
  [string]$Out = 'C:\skybuild\out',
  [string]$Root = 'D:\skycraft',                                           # upstream's path; D: is a subst of $Work\d
  [string]$SkyCraftSha = 'bfcaf178524b92c2cdeb88e4ce0f13ef9ded6f32',       # chasmlol/SkyCraft v0.1.2
  [string]$CommonLibSha = 'd61bca4de789428aa7d98a770b1323ddf1bb855c',      # alandtse/CommonLibSSE-NG (SkyCraft's submodule pointer)
  [string]$OpenVrSha = '60eb187801956ad277f1cae6680e3a410ee0873b',         # ValveSoftware/openvr (CommonLibSSE-NG's submodule pointer)
  [string]$VcpkgSha = '4a1c77189c64dae7afd478333a64d1e604d5dc91',          # microsoft/vcpkg master, 2026-10-01 00:01 UTC (last before upstream's build)
  [string]$MsvcVersion = '14.50',                                          # 'latest' (or '') = newest installed
  [switch]$InstallTools,
  [switch]$VerifyRepro                                                     # wipe the build folder, build again, compare the DLL bytes
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
if ($MsvcVersion -eq 'latest') { $MsvcVersion = '' }
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Tools, pinned (sha256 of the downloads). Visual Studio Build Tools has no pinned bootstrapper: the installed MSVC and
# Windows SDK versions are recorded in build-info.json instead. vcpkg's own tool (vcpkg.exe) and the helper tools it
# fetches are pinned by the vcpkg commit (scripts/vcpkg-tool-metadata.txt, scripts/vcpkg-tools.json).
$MinGit = @{ url = 'https://github.com/git-for-windows/git/releases/download/v2.56.0.windows.1/MinGit-2.56.0-64-bit.zip'; sha = '064b440ff870ed5198527e8f3a92cdf5bd2fd0fedf5e718af95e3fdaddeff718' }
$CMake = @{ url = 'https://github.com/Kitware/CMake/releases/download/v4.4.3/cmake-4.4.3-windows-x86_64.zip'; sha = '4d52ebab7193a698651639ed80d8d04fd903358843572cf44c7fd234cb7c26ab' }
$VsBootstrapper = 'https://aka.ms/vs/18/stable/vs_buildtools.exe'   # Visual Studio 2026 Build Tools
$VsMsvcComponent = @{ '14.50' = 'Microsoft.VisualStudio.Component.VC.14.50.18.0.x86.x64' }
# upstream's skse/vcpkg.json dependencies, unchanged
$Ports = @('directxmath', 'directxtk', 'fmt', 'nlohmann-json', 'rapidcsv', 'simpleini', 'spdlog', 'toml11', 'xbyak')
$Triplet = 'x64-windows-static-md'

New-Item -ItemType Directory -Force -Path $Work, $Out | Out-Null
$log = Join-Path $Out 'build.log'
function Say($m) { $l = "$(Get-Date -Format 'HH:mm:ss') $m"; Write-Host $l; Add-Content -Path $log -Value $l -Encoding utf8 }
function Run($exe, [string[]]$argv, $cwd = $Work) {
  Say "> $exe $($argv -join ' ')"
  Push-Location $cwd
  try {
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    & $exe @argv 2>&1 | ForEach-Object { $s = "$_"; Write-Host $s; Add-Content -Path $log -Value $s -Encoding utf8 }
    $code = $LASTEXITCODE; $ErrorActionPreference = $prev
  } finally { Pop-Location }
  if ($code -ne 0) { throw "$exe exited $code" }
}
function Fetch($spec, $file) {
  Invoke-WebRequest -UseBasicParsing $spec.url -OutFile $file
  $got = (Get-FileHash $file -Algorithm SHA256).Hash.ToLower()
  if ($got -ne $spec.sha) { throw "$file sha256 $got, pinned $($spec.sha)" }
}

$tools = Join-Path $Work 'tools'
if ($InstallTools) {
  New-Item -ItemType Directory -Force -Path $tools | Out-Null
  Say 'installing MinGit 2.56.0'
  Fetch $MinGit "$tools\mingit.zip"; Expand-Archive "$tools\mingit.zip" "$tools\git" -Force
  Say 'installing CMake 4.4.3'
  Fetch $CMake "$tools\cmake.zip"; Expand-Archive "$tools\cmake.zip" "$tools" -Force
  Say 'installing Visual Studio 2026 Build Tools (C++ workload)'
  Invoke-WebRequest -UseBasicParsing $VsBootstrapper -OutFile "$tools\vs_buildtools.exe"
  $vsArgs = @('--quiet', '--wait', '--norestart', '--nocache', '--add', 'Microsoft.VisualStudio.Workload.VCTools', '--includeRecommended')
  if ($MsvcVersion) { $vsArgs += @('--add', $VsMsvcComponent[$MsvcVersion]) }
  $p = Start-Process "$tools\vs_buildtools.exe" -Wait -PassThru -ArgumentList $vsArgs
  if ($p.ExitCode -notin 0, 3010) { throw "vs_buildtools exited $($p.ExitCode)" }
}
if (Test-Path "$tools\git\cmd") { $env:PATH = "$tools\git\cmd;$tools\cmake-4.4.3-windows-x86_64\bin;$env:PATH" }
$git = (Get-Command git).Source; $cmake = (Get-Command cmake).Source

# 0. Upstream's path. D:\skycraft through subst when D: is free (the mapping lives in this logon session only).
$drive = Split-Path -Qualifier $Root
if ($drive -ne 'C:') {
  $substBase = Join-Path $Work 'd'
  $mapped = (cmd /c subst) -match "^$drive\\: =>"
  if (-not $mapped) {
    if (Test-Path "$drive\") { throw "$drive exists and is not a subst: pass -Root $Work\skycraft" }
    New-Item -ItemType Directory -Force -Path $substBase | Out-Null
    cmd /c subst $drive $substBase | Out-Null
    if (-not (Test-Path "$drive\")) { throw "subst $drive $substBase failed" }
  }
  Say "$drive is $((cmd /c subst) -join '; ')"
}
$env:VCPKG_DISABLE_METRICS = '1'
$env:VCPKG_DEFAULT_BINARY_CACHE = Join-Path $Work 'vcpkg-cache'
New-Item -ItemType Directory -Force -Path $env:VCPKG_DEFAULT_BINARY_CACHE | Out-Null
Remove-Item Env:VCPKG_ROOT, Env:VCPKG_FEATURE_FLAGS, Env:VCPKG_BINARY_SOURCES, Env:GITHUB_ACTIONS, Env:CXXFLAGS, Env:LDFLAGS, Env:CFLAGS -ErrorAction SilentlyContinue

function Checkout($url, $dir, $sha) {
  if (-not (Test-Path "$dir\.git")) { Run $git @('-c', 'core.longpaths=true', 'clone', '-q', $url, $dir) }
  Run $git @('config', 'core.longpaths', 'true') $dir
  Run $git @('-c', 'advice.detachedHead=false', 'checkout', '-q', '--force', $sha) $dir
  $head = (& $git -C $dir rev-parse HEAD).Trim()
  if ($head -ne $sha) { throw "$dir is at $head, wanted $sha" }
}
function Pin($dir, $sha) {
  if ((& $git -C $dir rev-parse HEAD).Trim() -ne $sha) {
    Run $git @('fetch', '-q', 'origin') $dir
    Run $git @('-c', 'advice.detachedHead=false', 'checkout', '-q', '--force', $sha) $dir
  }
}

# 1. Sources, every repository at its pinned commit (upstream's `git clone --recursive`).
$sc = $Root
Checkout 'https://github.com/chasmlol/SkyCraft' $sc $SkyCraftSha
Run $git @('-c', 'core.longpaths=true', 'submodule', 'update', '--init', '--recursive', '--force') $sc
$clib = Join-Path $sc 'skse\extern\CommonLibSSE-NG'
Pin $clib $CommonLibSha
Run $git @('-c', 'core.longpaths=true', 'submodule', 'update', '--init', '--recursive', '--force') $clib
$openvr = Join-Path $clib 'extern\openvr'
Pin $openvr $OpenVrSha
$vcpkg = Join-Path $sc '.tools\vcpkg'
Checkout 'https://github.com/microsoft/vcpkg' $vcpkg $VcpkgSha
$pins = [ordered]@{}
foreach ($e in @(@('SkyCraft', $sc), @('CommonLibSSE-NG', $clib), @('openvr', $openvr), @('vcpkg', $vcpkg))) {
  $d = $e[1]
  $pins[$e[0]] = [ordered]@{ url = (& $git -C $d remote get-url origin).Trim(); commit = (& $git -C $d rev-parse HEAD).Trim();
    dirty = [bool](& $git -C $d status --porcelain --ignore-submodules=none --untracked-files=no) }
}
if ($pins['CommonLibSSE-NG'].commit -ne $CommonLibSha -or $pins['openvr'].commit -ne $OpenVrSha) { throw 'submodule pins not applied' }
Say "submodules:`n$((& $git -C $sc submodule status --recursive) -join "`n")"

# 2. vcpkg: bootstrap (downloads the vcpkg.exe release named in scripts/vcpkg-tool-metadata.txt), then a manifest of
# upstream's dependencies pinned to this commit: builtin-baseline + overrides at each port's exact version.
if (-not (Test-Path "$vcpkg\vcpkg.exe")) { Run "$vcpkg\bootstrap-vcpkg.bat" @('-disableMetrics') $vcpkg }
$baseline = (Get-Content "$vcpkg\versions\baseline.json" -Raw | ConvertFrom-Json).default
$closure = @($Ports + @('vcpkg-cmake', 'vcpkg-cmake-config'))
$overrides = foreach ($p in $closure) {
  $b = $baseline.$p
  if (-not $b) { throw "port $p not in vcpkg $VcpkgSha" }
  [ordered]@{ name = $p; version = $b.baseline; 'port-version' = [int]$b.'port-version' }
}
$manifestDir = Join-Path $Work 'manifest'
New-Item -ItemType Directory -Force -Path $manifestDir | Out-Null
$manifest = [ordered]@{
  '$comment' = "SkyCraft v0.1.2 skse/vcpkg.json dependencies, pinned by SIGF to microsoft/vcpkg $VcpkgSha (build-skycraft.ps1)"
  name = 'skycraft-skse'; 'version-string' = '0.1.2'
  'builtin-baseline' = $VcpkgSha
  dependencies = $Ports
  overrides = @($overrides)
}
$manifestJson = $manifest | ConvertTo-Json -Depth 5
[IO.File]::WriteAllText((Join-Path $manifestDir 'vcpkg.json'), $manifestJson + "`n", (New-Object Text.UTF8Encoding $false))
$tripletDir = Join-Path $Work 'triplets'
New-Item -ItemType Directory -Force -Path $tripletDir | Out-Null
$srcTriplet = @("$vcpkg\triplets\$Triplet.cmake", "$vcpkg\triplets\community\$Triplet.cmake") | Where-Object { Test-Path $_ } | Select-Object -First 1
$tripletText = (Get-Content $srcTriplet -Raw).TrimEnd()
if ($MsvcVersion) { $tripletText += "`nset(VCPKG_PLATFORM_TOOLSET_VERSION $MsvcVersion)" }
[IO.File]::WriteAllText((Join-Path $tripletDir "$Triplet.cmake"), $tripletText + "`n", (New-Object Text.UTF8Encoding $false))

# 3. Build: upstream's presets, plus the pins above, /Brepro and no prebuilt CommonLib / no deploy.
$skse = Join-Path $sc 'skse'
$build = Join-Path $skse 'build'
$cfgArgs = @('--preset', 'default', "-DVCPKG_MANIFEST_DIR=$manifestDir", "-DVCPKG_OVERLAY_TRIPLETS=$tripletDir",
  '-DCOMMONLIB_PREBUILT=OFF', '-DSKYCRAFT_DEPLOY_DIR=')
if ($MsvcVersion) { $cfgArgs += @('-T', "version=$MsvcVersion") }
$env:CXXFLAGS = '/Brepro'; $env:LDFLAGS = '/Brepro'
function Build {
  if (Test-Path $build) { Remove-Item -Recurse -Force $build }
  Run $cmake $cfgArgs $skse
  Run $cmake @('--build', '--preset', 'release') $skse
  if (Select-String -Path $log -Pattern 'CommonLibSSE: linking prebuilt' -Quiet) { throw 'CommonLibSSE-NG prebuilt was used' }
}
Build
$bin = Join-Path $build 'RelWithDebInfo'
$dll = Join-Path $bin 'SkyCraft.dll'
if (-not (Test-Path $dll)) { throw "no $dll" }
$sha = (Get-FileHash $dll -Algorithm SHA256).Hash.ToLower()
Say "built $dll sha256 $sha"
Copy-Item $dll, (Join-Path $bin 'SkyCraft.pdb') $Out -Force
$installed = Join-Path $build 'vcpkg_installed'
Copy-Item (Join-Path $installed 'vcpkg\status') (Join-Path $Out 'vcpkg-status.txt') -Force
$repro2 = $null
if ($VerifyRepro) {
  Build
  $repro2 = (Get-FileHash $dll -Algorithm SHA256).Hash.ToLower()
  Say "rebuild sha256 $repro2 ($(if ($repro2 -eq $sha) { 'identical' } else { 'DIFFERENT' }))"
  if ($repro2 -ne $sha) { Copy-Item $dll (Join-Path $Out 'SkyCraft.rebuild.dll') -Force }
}

# 4. Package versions (vcpkg's install status) and their sources: the archives vcpkg downloaded + the port scripts.
$packages = [ordered]@{}
foreach ($block in ((Get-Content (Join-Path $Out 'vcpkg-status.txt') -Raw) -split "(?:\r?\n){2,}")) {
  $kv = @{}; foreach ($line in ($block -split "\r?\n")) { if ($line -match '^([A-Za-z-]+): (.*)$') { $kv[$Matches[1]] = $Matches[2] } }
  if (-not $kv['Package'] -or $kv['Feature'] -or $kv['Status'] -notmatch 'installed$') { continue }
  $key = "$($kv['Package']):$($kv['Architecture'])"
  $packages[$key] = [ordered]@{ version = $kv['Version']; port_version = $(if ($kv['Port-Version']) { [int]$kv['Port-Version'] } else { 0 }); abi = $kv['Abi'] }
}
$srcZip = Join-Path $Out 'vcpkg-sources.zip'
$stage = Join-Path $Work 'vcpkg-sources'
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Force -Path "$stage\downloads", "$stage\ports", "$stage\triplets" | Out-Null
Get-ChildItem "$vcpkg\downloads" -File | Where-Object { $_.Name -notmatch '\.(part|tmp)$' } | Copy-Item -Destination "$stage\downloads"
foreach ($k in $packages.Keys) { $p = $k.Split(':')[0]; Copy-Item -Recurse "$vcpkg\ports\$p" "$stage\ports\$p" }
Copy-Item "$tripletDir\$Triplet.cmake" "$stage\triplets\"
Copy-Item "$manifestDir\vcpkg.json" "$stage\" ; Copy-Item "$manifestDir\vcpkg.json" $Out -Force
if (Test-Path $srcZip) { Remove-Item $srcZip }
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::Open($srcZip, 'Create')
try {   # entry names with '/', which Windows PowerShell's Compress-Archive / CreateFromDirectory do not write
  foreach ($f in Get-ChildItem $stage -Recurse -File) {
    $name = $f.FullName.Substring($stage.Length + 1).Replace('\', '/')
    [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $f.FullName, $name)
  }
} finally { $zip.Dispose() }
$downloads = Get-ChildItem "$stage\downloads" -File | ForEach-Object { [ordered]@{ file = $_.Name; sha512 = (Get-FileHash $_.FullName -Algorithm SHA512).Hash.ToLower() } }

# 5. Toolchain record.
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vs = & $vswhere -products * -latest -format json | ConvertFrom-Json
$msvcAll = (Get-ChildItem "$($vs[0].installationPath)\VC\Tools\MSVC" | Sort-Object Name).Name
$msvc = if ($MsvcVersion) { $msvcAll | Where-Object { $_ -like "$MsvcVersion.*" } | Select-Object -Last 1 } else { $msvcAll | Select-Object -Last 1 }
$cl = "$($vs[0].installationPath)\VC\Tools\MSVC\$msvc\bin\Hostx64\x64\cl.exe"
$clBanner = ((cmd /c "`"$cl`" 2>&1") | Select-Object -First 1)
$sdk = (Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\Include" -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -Last 1).Name
$info = [ordered]@{
  dll = [ordered]@{ file = 'SkyCraft.dll'; sha256 = $sha; size = (Get-Item (Join-Path $Out 'SkyCraft.dll')).Length; rebuild_sha256 = $repro2 }
  sources = $pins
  vcpkg = [ordered]@{ commit = $VcpkgSha; triplet = $Triplet; tool = ((& "$vcpkg\vcpkg.exe" version) | Select-Object -First 1).Trim();
    tool_sha256 = (Get-FileHash "$vcpkg\vcpkg.exe" -Algorithm SHA256).Hash.ToLower(); manifest = 'vcpkg.json'; packages = $packages; downloads = @($downloads) }
  toolchain = [ordered]@{ visual_studio = "$($vs[0].displayName) $($vs[0].catalog.productDisplayVersion)"; msvc = $msvc; msvc_installed = @($msvcAll); cl = "$clBanner".Trim();
    windows_sdk = $sdk; cmake = ((& $cmake --version) | Select-Object -First 1).Trim(); git = (& $git --version).Trim();
    os = (Get-CimInstance Win32_OperatingSystem).Caption + ' ' + [Environment]::OSVersion.Version }
  commands = @("cmake --preset default -DVCPKG_MANIFEST_DIR=<manifest> -DVCPKG_OVERLAY_TRIPLETS=<triplets> -DCOMMONLIB_PREBUILT=OFF -DSKYCRAFT_DEPLOY_DIR=$(if ($MsvcVersion) { " -T version=$MsvcVersion" })",
    'cmake --build --preset release', 'environment: CXXFLAGS=/Brepro LDFLAGS=/Brepro')
  root = $Root
  built_at = (Get-Date).ToUniversalTime().ToString('o')
}
$info | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $Out 'build-info.json') -Encoding utf8
Say 'done'
