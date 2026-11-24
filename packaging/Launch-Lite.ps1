$ErrorActionPreference="Stop"; $R=$PSScriptRoot
$env:PATH="$R\ffmpeg;$R\python;$env:PATH"; $env:HF_HOME="$R\models"; $env:HF_HUB_OFFLINE="1"; $env:HF_HUB_DISABLE_TELEMETRY="1"
New-Item -ItemType Directory -Force -Path "$R\logs"|Out-Null
try {$h=Invoke-WebRequest "http://127.0.0.1:8000/health" -UseBasicParsing -TimeoutSec 2; if($h.StatusCode -eq 200){Start-Process "http://127.0.0.1:8000"; exit}} catch {}
$p=Start-Process "$R\python\python.exe" -ArgumentList @("-m","uvicorn","app.main:app","--host","127.0.0.1","--port","8000") -WorkingDirectory $R -WindowStyle Hidden -PassThru -RedirectStandardOutput "$R\logs\server.log" -RedirectStandardError "$R\logs\error.log"
for($i=0;$i -lt 180;$i++){if($p.HasExited){break};try{$h=Invoke-WebRequest "http://127.0.0.1:8000/health" -UseBasicParsing -TimeoutSec 2;if($h.StatusCode -eq 200){Start-Process "http://127.0.0.1:8000";exit}}catch{};Start-Sleep 1}
Add-Type -AssemblyName PresentationFramework
[System.Windows.MessageBox]::Show("ClipForge could not start. Check logs\\error.log or reinstall.","ClipForge Lite")|Out-Null
