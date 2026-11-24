[CmdletBinding()]
param([string]$PyVersion="3.11.9",[string]$OutDir="")
$ErrorActionPreference="Stop"; $ProgressPreference="SilentlyContinue"
$Root=Split-Path -Parent $PSScriptRoot
if(!$OutDir){$OutDir=Join-Path $Root "dist_lite"}
$B=Join-Path $OutDir "ClipForgeLite"; $P=Join-Path $B "python"; $F=Join-Path $B "ffmpeg"; $M=Join-Path $B "models"
foreach($x in @((Join-Path $Root "app"),(Join-Path $Root "web\dist\index.html"),(Join-Path $Root "requirements.txt"))){if(!(Test-Path $x)){throw "Missing required project input: $x"}}
if(Test-Path $B){Remove-Item $B -Recurse -Force}
New-Item -ItemType Directory -Force -Path $P,$F,$M | Out-Null
function GetFile($u,$p){Invoke-WebRequest -UseBasicParsing -Uri $u -OutFile $p -TimeoutSec 900}
$z=Join-Path $env:TEMP "cf-python.zip"; GetFile "https://www.python.org/ftp/python/$PyVersion/python-$PyVersion-embed-amd64.zip" $z; Expand-Archive $z $P -Force
$pth=Get-ChildItem $P -Filter "python*._pth"|Select-Object -First 1
(Get-Content $pth.FullName) -replace '^#import site','import site' | Set-Content $pth.FullName -Encoding Ascii
if(!(Select-String $pth.FullName '^import site$' -Quiet)){Add-Content $pth.FullName 'import site'}
$py=Join-Path $P "python.exe"; $gp=Join-Path $env:TEMP "cf-get-pip.py"; GetFile "https://bootstrap.pypa.io/get-pip.py" $gp
& $py $gp --no-warn-script-location; if($LASTEXITCODE){throw "pip bootstrap failed"}
& $py -m pip install --no-warn-script-location -r (Join-Path $Root "requirements.txt"); if($LASTEXITCODE){throw "requirements install failed"}
& $py -m pip install --no-warn-script-location "faster-whisper==1.2.1" "ctranslate2==4.8.0"; if($LASTEXITCODE){throw "CPU runtime install failed"}
& $py -m pip check; if($LASTEXITCODE){throw "pip check failed"}
Copy-Item (Join-Path $Root "app") (Join-Path $B "app") -Recurse
New-Item -ItemType Directory -Force -Path (Join-Path $B "web") | Out-Null
Copy-Item (Join-Path $Root "web\dist") (Join-Path $B "web\dist") -Recurse
Copy-Item (Join-Path $Root "requirements.txt") $B
$assets=Join-Path $Root "assets"; if(Test-Path $assets){Get-ChildItem $assets | Where-Object Name -ne "music" | ForEach-Object {Copy-Item $_.FullName (Join-Path (Join-Path $B "assets") $_.Name) -Recurse -Force}}
foreach($d in @("assets\music","downloads","clips","transcripts","logs")){New-Item -ItemType Directory -Force -Path (Join-Path $B $d)|Out-Null}
$ff=Join-Path $env:TEMP "cf-ffmpeg.zip"; GetFile "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip" $ff
$fe=Join-Path $env:TEMP "cf-ffmpeg"; if(Test-Path $fe){Remove-Item $fe -Recurse -Force}; Expand-Archive $ff $fe -Force
Get-ChildItem $fe -Recurse -Filter ffmpeg.exe|Select-Object -First 1|Copy-Item -Destination (Join-Path $F "ffmpeg.exe")
Get-ChildItem $fe -Recurse -Filter ffprobe.exe|Select-Object -First 1|Copy-Item -Destination (Join-Path $F "ffprobe.exe")
$env:HF_HOME=$M; $env:HF_HUB_DISABLE_TELEMETRY="1"
@' 
from faster_whisper import WhisperModel
WhisperModel("base", device="cpu", compute_type="int8")
print("Whisper Base cache ready")
'@ | Set-Content (Join-Path $env:TEMP "cf-model.py") -Encoding Ascii
& $py (Join-Path $env:TEMP "cf-model.py"); if($LASTEXITCODE){throw "Whisper model download failed"}
$env:PATH="$F;$P;$env:PATH"; $env:HF_HUB_OFFLINE="1"; Push-Location $B
try {& $py -c "import app.main; print('app import OK')"; if($LASTEXITCODE){throw "App import failed"}; & (Join-Path $F "ffmpeg.exe") -version | Out-Null; if($LASTEXITCODE){throw "FFmpeg test failed"}} finally {Pop-Location}
Write-Host "ClipForge Lite bundle created: $B"
