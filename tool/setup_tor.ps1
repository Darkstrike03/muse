# Downloads the official Tor Project Windows expert bundle and installs it to
# ./tor/windows/ at the repo root. The app finds it there when launched from
# the repo (dev builds), or from $MUSE_TOR_DIR.
#
#   powershell -ExecutionPolicy Bypass -File tool/setup_tor.ps1
#
# The version is discovered from dist.torproject.org (newest stable release),
# so the script keeps working as Tor pushes new versions.

$ErrorActionPreference = 'Stop'

$indexUrl = 'https://dist.torproject.org/torbrowser/'

Write-Host "Listing releases at $indexUrl ..."
$index = (Invoke-WebRequest -Uri $indexUrl -UseBasicParsing).Content
$versions = [regex]::Matches($index, 'href="(\d+\.\d+\.\d+)/"') |
  ForEach-Object { $_.Groups[1].Value } |
  Sort-Object { [version]$_ }

if (-not $versions) { throw 'Could not parse the release list from dist.torproject.org' }
$version = $versions | Select-Object -Last 1

$url = "https://dist.torproject.org/torbrowser/$version/tor-expert-bundle-windows-x86_64-$version.tar.gz"
$root   = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$dest   = Join-Path $root 'tor\windows'
$tmp    = Join-Path $env:TEMP 'muse-tor.tar.gz'
$tmpDir = Join-Path $env:TEMP 'muse-tor-extract'

New-Item -ItemType Directory -Force -Path $dest | Out-Null

Write-Host "Downloading $url ..."
Invoke-WebRequest -Uri $url -UseBasicParsing -OutFile $tmp

if (-not (Get-Command tar -ErrorAction SilentlyContinue)) {
  throw "The 'tar' tool (bundled with Windows 10/11) is required to extract the bundle."
}

Write-Host 'Extracting...'
if (Test-Path $tmpDir) { Remove-Item $tmpDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null
tar -xzf $tmp -C $tmpDir
if ($LASTEXITCODE -ne 0) { throw 'tar extraction failed' }

Write-Host 'Installing...'
$torExe = Get-ChildItem -Path $tmpDir -Recurse -Filter 'tor.exe' -File |
  Select-Object -First 1
if (-not $torExe) {
  throw 'Could not find tor.exe inside the downloaded bundle.'
}
Copy-Item -Path (Join-Path $torExe.DirectoryName '*') -Destination $dest -Recurse -Force

Remove-Item $tmp, $tmpDir -Recurse -Force

Write-Host "Tor installed to $dest"
try {
  $versionOutput = & (Join-Path $dest 'tor.exe') --version
  Write-Host $versionOutput | Select-Object -First 1
} catch {
  Write-Host 'tor.exe installed, but --version check failed.'
}
Write-Host 'The app looks for tor.exe in <repo>/tor/windows, the app support'
Write-Host "directory, and the 'MUSE_TOR_DIR' environment variable."

# Android: place the matching architecture's Tor binary at
#   android/app/src/main/assets/tor/<abi>/tor        (copied to app files on
#                                                     first run)
# The official Android expert bundle ships per-ABI from dist.torproject.org,
# e.g. tor-expert-bundle-android-aarch64-$version.tar.gz (also armv7, x86,
# x86_64). Each extracts a 'tor' executable plus libevent/libssl/libcrypto
# shared objects that must live beside it.