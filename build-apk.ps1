param(
  [string]$Sdk = $(if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $env:LOCALAPPDATA "Android\Sdk" }),
  [string]$BuildToolsVersion = "36.0.0",
  [string]$Platform = "android-37.0",
  [string]$JdkHome = $env:JAVA_HOME
)

$ErrorActionPreference = "Stop"

$Root       = $PSScriptRoot
$Bt         = Join-Path $Sdk "build-tools\$BuildToolsVersion"
$AndroidJar = Join-Path $Sdk "platforms\$Platform\android.jar"

if (-not $JdkHome) {
  $jdks = Get-ChildItem (Join-Path $env:ProgramFiles "Java") -Directory -Filter "jdk-*" -ErrorAction SilentlyContinue |
          Sort-Object Name -Descending
  if ($jdks.Count -gt 0) {
    $JdkHome = $jdks[0].FullName
  } else {
    $JdkHome = Split-Path (Split-Path (Get-Command javac -ErrorAction Stop).Source -Parent) -Parent
  }
}
$JdkBin     = Join-Path $JdkHome "bin"

$env:JAVA_HOME = $JdkHome
$env:PATH = "$JdkBin;$Bt;" + $env:PATH

$Src      = Join-Path $Root "app\src\main"
$Res      = Join-Path $Src "res"
$Assets   = Join-Path $Src "assets"
$Manifest = Join-Path $Src "AndroidManifest.xml"
$JavaDir  = Join-Path $Src "java"
$Build    = Join-Path $Root "build"

if (Test-Path $Build) { Remove-Item $Build -Recurse -Force }
New-Item -ItemType Directory -Force -Path $Build | Out-Null

Write-Host "==> [0/9] Embedding poem database into HTML"
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "embed-poems.ps1")
if ($LASTEXITCODE -ne 0) { throw "embed-poems failed" }

Write-Host "==> [1/9] Compiling resources (aapt2 compile)"
& "$Bt\aapt2.exe" compile --dir $Res -o (Join-Path $Build "res.zip")
if ($LASTEXITCODE -ne 0) { throw "aapt2 compile failed" }

Write-Host "==> [2/9] Linking resources + assets (aapt2 link)"
& "$Bt\aapt2.exe" link -o (Join-Path $Build "app-unsigned.apk") `
    -I $AndroidJar `
    --manifest $Manifest `
    -R (Join-Path $Build "res.zip") `
    -A $Assets `
    --java (Join-Path $Build "gen") `
    --auto-add-overlay
if ($LASTEXITCODE -ne 0) { throw "aapt2 link failed" }

Write-Host "==> [3/9] Compiling Java (javac)"
$javacArgs = @(
  "-encoding", "UTF-8",
  "-source", "1.8",
  "-target", "1.8",
  "-bootclasspath", $AndroidJar,
  "-d", (Join-Path $Build "classes")
)
$javaFiles = @()
$javaFiles += (Join-Path $Build "gen\com\hafez\faal\R.java")
$javaFiles += (Get-ChildItem -Path $JavaDir -Recurse -Filter *.java | ForEach-Object { $_.FullName })
& "$JdkBin\javac.exe" @javacArgs @javaFiles
if ($LASTEXITCODE -ne 0) { throw "javac failed" }

Write-Host "==> [4/9] Packaging classes (jar)"
& "$JdkBin\jar.exe" cf (Join-Path $Build "classes.jar") -C (Join-Path $Build "classes") .
if ($LASTEXITCODE -ne 0) { throw "jar failed" }

Write-Host "==> [5/9] Dexing (d8)"
New-Item -ItemType Directory -Force -Path (Join-Path $Build "dex") | Out-Null
& "$Bt\d8.bat" --lib $AndroidJar --min-api 21 --output (Join-Path $Build "dex") (Join-Path $Build "classes.jar")
if ($LASTEXITCODE -ne 0) { throw "d8 failed" }

Write-Host "==> [6/9] Adding classes.dex into APK"
Add-Type -AssemblyName System.IO.Compression.FileSystem
$apkPath = (Resolve-Path (Join-Path $Build "app-unsigned.apk")).Path
$dexPath = (Resolve-Path (Join-Path $Build "dex\classes.dex")).Path
$zip = [System.IO.Compression.ZipFile]::Open($apkPath, 'Update')
try {
  $entry = $zip.GetEntry("classes.dex")
  if ($entry) { $entry.Delete() }
  [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $dexPath, "classes.dex", [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
} finally {
  $zip.Dispose()
}

Write-Host "==> [7/9] Zipalign"
& "$Bt\zipalign.exe" -f -p 4 (Join-Path $Build "app-unsigned.apk") (Join-Path $Build "app-aligned.apk")
if ($LASTEXITCODE -ne 0) { throw "zipalign failed" }

Write-Host "==> [8/9] Creating debug keystore (persistent)"
$ksDir = Join-Path $Root "keystore"
New-Item -ItemType Directory -Force -Path $ksDir | Out-Null
$ks = Join-Path $ksDir "hafez-debug.keystore"
if (-not (Test-Path $ks)) {
  & "$JdkBin\keytool.exe" -genkeypair -v -keystore $ks -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US"
  if ($LASTEXITCODE -ne 0) { throw "keytool failed" }
} else {
  Write-Host "    Reusing existing keystore: $ks"
}

Write-Host "==> [9/9] Signing (apksigner)"
$outApk = Join-Path $Build "HafezFaal.apk"
& "$Bt\apksigner.bat" sign --ks $ks --ks-pass pass:android --key-pass pass:android --out $outApk (Join-Path $Build "app-aligned.apk")
if ($LASTEXITCODE -ne 0) { throw "apksigner sign failed" }

Write-Host "==> Verifying signature"
& "$Bt\apksigner.bat" verify --verbose $outApk
if ($LASTEXITCODE -ne 0) { throw "apksigner verify failed" }

Write-Host "==> APK summary"
& "$Bt\aapt.exe" dump badging $outApk | Select-Object -First 10

Write-Host ""
Write-Host "BUILD SUCCESSFUL"
Write-Host "APK: $outApk"
Write-Host "Size: $([math]::Round((Get-Item $outApk).Length / 1MB, 2)) MB"
