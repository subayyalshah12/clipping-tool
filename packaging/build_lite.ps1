[CmdletBinding()]
param(
    [string]$PyVersion = "3.11.9",
    [string]$OutDir = ""
)
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$Root = Split-Path -Parent $PSScriptRoot
if (-not $OutDir) { $OutDir = Join-Path $Root "dist_lite" }
$Bundle = Join-Path $OutDir "ClipForgeLite"
$PythonDir = Join-Path $Bundle "python"
$FfmpegDir = Join-Path $Bundle "ffmpeg"
$ModelsDir = Join-Path $Bundle "models"

$required = @(
    (Join-Path $Root "app"),
    (Join-Path $Root "web\dist\index.html"),
    (Join-Path $Root "requirements.txt")
)
foreach ($item in $required) {
    if (-not (Test-Path $item)) { throw "Missing required project input: $item" }
}
if (Test-Path $Bundle) { Remove-Item $Bundle -Recurse -Force }
New-Item -ItemType Directory -Force -Path $PythonDir, $FfmpegDir, $ModelsDir | Out-Null

function Get-RemoteFile([string]$Url, [string]$Destination) {
    Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $Destination -TimeoutSec 900
}

# Embedded Python keeps the recipient independent of a system Python installation.
$pythonZip = Join-Path $env:TEMP "clipforge-python-embed.zip"
Get-RemoteFile "https://www.python.org/ftp/python/$PyVersion/python-$PyVersion-embed-amd64.zip" $pythonZip
Expand-Archive -Path $pythonZip -DestinationPath $PythonDir -Force

$pth = Get-ChildItem -Path $PythonDir -Filter "python*._pth" | Select-Object -First 1
if (-not $pth) { throw "Embedded Python path configuration file was not found." }
$sitePackages = Join-Path $PythonDir "Lib\site-packages"
New-Item -ItemType Directory -Force -Path $sitePackages | Out-Null
$pthLines = @(
    "python311.zip",
    ".",
    "..",
    "Lib\site-packages",
    "import site"
)
[System.IO.File]::WriteAllLines($pth.FullName, $pthLines, [System.Text.Encoding]::ASCII)

$python = Join-Path $PythonDir "python.exe"
if (-not (Test-Path $python)) { throw "Embedded python.exe is missing." }
$pythonVersion = & $python --version 2>&1
if ($LASTEXITCODE -ne 0) { throw "Embedded Python failed to start: $pythonVersion" }

# The embeddable distribution omits pip; bootstrap it into the bundled interpreter.
$getPip = Join-Path $env:TEMP "clipforge-get-pip.py"
Get-RemoteFile "https://bootstrap.pypa.io/get-pip.py" $getPip
& $python $getPip --no-warn-script-location
if ($LASTEXITCODE -ne 0) { throw "pip bootstrap failed." }

# Install only CPU-capable dependencies. faster-whisper brings CTranslate2 without CUDA.
& $python -m pip install --no-warn-script-location --disable-pip-version-check -r (Join-Path $Root "requirements.txt")
if ($LASTEXITCODE -ne 0) { throw "Python requirements installation failed." }
& $python -m pip check
if ($LASTEXITCODE -ne 0) { throw "Python dependency check failed." }

Copy-Item -Path (Join-Path $Root "app") -Destination (Join-Path $Bundle "app") -Recurse
New-Item -ItemType Directory -Force -Path (Join-Path $Bundle "web") | Out-Null
Copy-Item -Path (Join-Path $Root "web\dist") -Destination (Join-Path $Bundle "web\dist") -Recurse
Copy-Item -Path (Join-Path $Root "requirements.txt") -Destination $Bundle

# Preserve bundled fonts/masks, but do not redistribute the repository music library.
$assetsSource = Join-Path $Root "assets"
if (Test-Path $assetsSource) {
    New-Item -ItemType Directory -Force -Path (Join-Path $Bundle "assets") | Out-Null
    Get-ChildItem -Path $assetsSource | Where-Object { $_.Name -ne "music" } | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination (Join-Path (Join-Path $Bundle "assets") $_.Name) -Recurse -Force
    }
}
foreach ($folder in @("assets\music", "downloads", "clips", "transcripts", "logs")) {
    New-Item -ItemType Directory -Force -Path (Join-Path $Bundle $folder) | Out-Null
}

# Bundle FFmpeg binaries for Windows; no separate install is required.
$ffmpegZip = Join-Path $env:TEMP "clipforge-ffmpeg.zip"
Get-RemoteFile "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip" $ffmpegZip
$ffmpegExtract = Join-Path $env:TEMP "clipforge-ffmpeg"
if (Test-Path $ffmpegExtract) { Remove-Item $ffmpegExtract -Recurse -Force }
Expand-Archive -Path $ffmpegZip -DestinationPath $ffmpegExtract -Force
$ffmpegExe = Get-ChildItem -Path $ffmpegExtract -Recurse -Filter "ffmpeg.exe" | Select-Object -First 1
$ffprobeExe = Get-ChildItem -Path $ffmpegExtract -Recurse -Filter "ffprobe.exe" | Select-Object -First 1
if (-not $ffmpegExe -or -not $ffprobeExe) { throw "FFmpeg archive did not contain ffmpeg.exe and ffprobe.exe." }
Copy-Item $ffmpegExe.FullName (Join-Path $FfmpegDir "ffmpeg.exe")
Copy-Item $ffprobeExe.FullName (Join-Path $FfmpegDir "ffprobe.exe")

# Pre-cache the Base model in the exact cache directory used by the installed app.
$env:HF_HOME = $ModelsDir
$env:HF_HUB_DISABLE_TELEMETRY = "1"
$modelCheck = @'
from faster_whisper import WhisperModel
model = WhisperModel("base", device="cpu", compute_type="int8")
print("Whisper Base CPU INT8 model cache ready")
del model
'@
$modelScript = Join-Path $env:TEMP "clipforge-cache-model.py"
[System.IO.File]::WriteAllText($modelScript, $modelCheck, [System.Text.Encoding]::UTF8)
& $python $modelScript
if ($LASTEXITCODE -ne 0) { throw "Whisper Base model download/cache failed." }

# Import smoke test with the same environment/layout that the launcher will use.
$env:PATH = "$FfmpegDir;$PythonDir;$env:PATH"
$env:HF_HUB_OFFLINE = "1"
Push-Location $Bundle
try {
    & $python -c "import app.main; from faster_whisper import WhisperModel; print('ClipForge backend import OK')"
    if ($LASTEXITCODE -ne 0) { throw "ClipForge backend import smoke test failed." }
    & (Join-Path $FfmpegDir "ffmpeg.exe") -version | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Bundled FFmpeg smoke test failed." }
} finally {
    Pop-Location
}
Write-Host "ClipForge Lite bundle created and smoke-tested: $Bundle"
