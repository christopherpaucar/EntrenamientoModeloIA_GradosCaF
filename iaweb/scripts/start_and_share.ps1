<#
Start-and-share script
Usage (from any folder):
  powershell -ExecutionPolicy Bypass -File .\iaweb\scripts\start_and_share.ps1 [-NgrokPath 'C:\path\to\ngrok.exe']

What it does:
  - Moves to the `iaweb` project directory where `docker-compose.yml` is expected
  - Runs `docker compose up -d`
  - Waits until `http://localhost:8000/` responds with HTTP 200 (with timeout)
  - Starts ngrok (if available) and polls the ngrok API for a public URL
  - Opens the public URL (or `http://localhost:8000` if no tunnel)

Notes:
  - Requires Docker and optionally ngrok installed.
  - If ngrok is not on PATH, pass `-NgrokPath` with the executable full path.
#>
param(
  [string]$NgrokPath = "ngrok",
  [int]$WaitSecondsForLocal=60,
  [int]$WaitSecondsForNgrok=30
)

function Write-Info($m) { Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Write-Warn($m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Write-Err($m) { Write-Host "[ERROR] $m" -ForegroundColor Red }

# Determine project dir (assume script is in iaweb\scripts)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = Resolve-Path (Join-Path $scriptDir "..")
Set-Location $projectDir
Write-Info "Directorio del proyecto: $projectDir"

# 1) Levantar contenedores
Write-Info "Ejecutando: docker compose up -d"
docker compose up -d

# 2) Esperar a que localhost:8000 responda HTTP 200
$localUrl = 'http://127.0.0.1:8000/'
$deadline = (Get-Date).AddSeconds($WaitSecondsForLocal)
Write-Info "Esperando a que $localUrl responda (timeout $WaitSecondsForLocal s)..."
$ok = $false
while ((Get-Date) -lt $deadline) {
  try {
    $resp = Invoke-RestMethod -Uri $localUrl -Method Get -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
    Write-Info "Servicio local respondió OK"
    $ok = $true
    break
  } catch {
    Start-Sleep -Seconds 1
  }
}
if (-not $ok) { Write-Warn "No se obtuvo respuesta en $localUrl. Revisa 'docker compose ps' y 'docker compose logs web'." }

# 3) Intentar iniciar ngrok (si está disponible)
$startedNgrok = $false
try {
  # Try to check if ngrok is already running by querying API
  $apiResp = Invoke-RestMethod -Uri 'http://127.0.0.1:4040/api/tunnels' -UseBasicParsing -ErrorAction Stop
  if ($apiResp.tunnels.Count -gt 0) { Write-Info "ngrok ya estaba en ejecución."; $startedNgrok = $true }
} catch {
  # not running yet
}

if (-not $startedNgrok) {
  Write-Info "Intentando arrancar ngrok ($NgrokPath)"
  try {
    Start-Process -FilePath $NgrokPath -ArgumentList 'http 8000' -WindowStyle Hidden
    Start-Sleep -Seconds 2
    Write-Info "ngrok arrancado (si el ejecutable existe)."
    $startedNgrok = $true
  } catch {
    Write-Warn "No se pudo arrancar ngrok automáticamente. Asegúrate de que 'ngrok' esté en PATH o pasa -NgrokPath." 
  }
}

# 4) Poll ngrok API for public URL
$publicUrl = $null
if ($startedNgrok) {
  Write-Info "Buscando túnel ngrok (esperando hasta $WaitSecondsForNgrok s)..."
  $deadline = (Get-Date).AddSeconds($WaitSecondsForNgrok)
  while ((Get-Date) -lt $deadline) {
    try {
      $api = Invoke-RestMethod -Uri 'http://127.0.0.1:4040/api/tunnels' -UseBasicParsing -ErrorAction Stop
      if ($api.tunnels -and $api.tunnels.Count -gt 0) {
        $t = $api.tunnels | Where-Object { $_.proto -eq 'https' } | Select-Object -First 1
        if (-not $t) { $t = $api.tunnels[0] }
        $publicUrl = $t.public_url
        break
      }
    } catch {
      Start-Sleep -Seconds 1
    }
  }
  if ($publicUrl) { Write-Info "Túnel ngrok detectado: $publicUrl" } else { Write-Warn "No se detectó túnel ngrok." }
}

# 5) Abrir la URL adecuada
if ($publicUrl) {
  Write-Info "Abriendo $publicUrl en el navegador..."
  Start-Process $publicUrl
} elseif ($ok) {
  Write-Info "Abriendo $localUrl en el navegador..."
  Start-Process $localUrl
} else {
  Write-Err "No hay URL para abrir. Revisa 'docker compose ps' y 'docker compose logs web'."
  exit 1
}

Write-Info "Hecho. Si la página sigue sin cargar, ejecutar los siguientes comandos y pegar su salida aquí:\n  docker compose ps\n  docker compose logs --no-color --timestamps --tail 200 web\n  curl.exe -v http://localhost:8000/\n  Invoke-RestMethod -Uri 'http://127.0.0.1:4040/api/tunnels' -UseBasicParsing\n  Get-Content .\.env"
exit 0
