<#
start_presentation.ps1

Uso:
  powershell -ExecutionPolicy Bypass -File .\iaweb\scripts\start_presentation.ps1 -NgrokPath ".\iaweb\ngrok.exe"

Qué hace:
  - Cambia al directorio `iaweb`
  - Levanta los contenedores con `docker compose up -d`
  - Espera a que `http://localhost:8000/` responda
  - Arranca `ngrok` (si se indica su ruta)
  - Pulsea la API de ngrok en :4040 hasta obtener `public_url`
  - Actualiza `.env` con `ALLOWED_HOSTS` y `CSRF_TRUSTED_ORIGINS` para el host público
  - Recréea/reinicia el servicio `web` para que lea las nuevas variables
  - Abre la URL pública en el navegador

Notas:
  - Mantén la ventana/ejecución de ngrok abierta durante la presentación.
  - Si ngrok vuelve a arrancar y genera otro subdominio, vuelve a ejecutar este script.
#>

param(
    [string]$NgrokPath = ".\ngrok.exe",
    [int]$LocalWaitSeconds = 60,
    [int]$NgrokWaitSeconds = 30
)

function Write-Info($m){ Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Write-Warn($m){ Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Write-Err($m){ Write-Host "[ERROR] $m" -ForegroundColor Red }

# Cambiar al directorio del proyecto (asume que el script está en iaweb\scripts)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = Resolve-Path (Join-Path $scriptDir "..")
Set-Location $projectDir
Write-Info "Directorio del proyecto: $projectDir"

# 1) Levantar contenedores
Write-Info "Ejecutando: docker compose up -d"
docker compose up -d

# 2) Esperar a que localhost responda
$localUrl = 'http://127.0.0.1:8000/'
$deadline = (Get-Date).AddSeconds($LocalWaitSeconds)
Write-Info "Esperando a que $localUrl responda (timeout $LocalWaitSeconds s)..."
$localOk = $false
while ((Get-Date) -lt $deadline) {
    try {
        $r = Invoke-RestMethod -Uri $localUrl -Method Get -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
        Write-Info "Servicio local respondió OK"
        $localOk = $true
        break
    } catch {
        Start-Sleep -Seconds 1
    }
}
if (-not $localOk) { Write-Warn "No hubo respuesta en $localUrl; continúa de todas formas (ngrok puede fallar si web no está listo)." }

# 3) Arrancar ngrok si es posible
$startedNgrok = $false
try {
    $apiResp = Invoke-RestMethod -Uri 'http://127.0.0.1:4040/api/tunnels' -UseBasicParsing -ErrorAction Stop
    if ($apiResp.tunnels.Count -gt 0) { Write-Info "ngrok ya estaba en ejecución."; $startedNgrok = $true }
} catch {}

if (-not $startedNgrok) {
    if (Test-Path $NgrokPath) {
        Write-Info "Iniciando ngrok desde: $NgrokPath"
        Start-Process -FilePath $NgrokPath -ArgumentList 'http 8000' -WindowStyle Hidden
        Start-Sleep -Seconds 2
        $startedNgrok = $true
    } else {
        Write-Warn "ngrok no encontrado en $NgrokPath. Pasa -NgrokPath con la ruta correcta o inicia ngrok manualmente." 
    }
}

# 4) Esperar a la API de ngrok y obtener public_url
$publicUrl = $null
if ($startedNgrok) {
    Write-Info "Buscando túnel ngrok (esperando hasta $NgrokWaitSeconds s)..."
    $deadline = (Get-Date).AddSeconds($NgrokWaitSeconds)
    while ((Get-Date) -lt $deadline) {
        try {
            $api = Invoke-RestMethod -Uri 'http://127.0.0.1:4040/api/tunnels' -UseBasicParsing -ErrorAction Stop
            if ($api.tunnels -and $api.tunnels.Count -gt 0) {
                $t = $api.tunnels | Where-Object { $_.proto -eq 'https' } | Select-Object -First 1
                if (-not $t) { $t = $api.tunnels[0] }
                $publicUrl = $t.public_url
                break
            }
        } catch { Start-Sleep -Seconds 1 }
    }
    if ($publicUrl) { Write-Info "Túnel ngrok detectado: $publicUrl" } else { Write-Warn "No se detectó túnel ngrok." }
}

# 5) Si hay public_url, actualizar .env y recrear web
if ($publicUrl) {
    try {
        $host = ([uri]$publicUrl).Host
        $origin = "https://$host"
        $envFile = '.env'
        function Set-OrAdd-Env($path,$key,$value) {
            $lines = @()
            if (Test-Path $path) { $lines = Get-Content $path -Raw -ErrorAction SilentlyContinue -Encoding UTF8 -EA SilentlyContinue -split "`r?`n" }
            $pattern = "^$([regex]::Escape($key))="
            $found = $false
            for ($i=0; $i -lt $lines.Count; $i++) {
                if ($lines[$i] -match $pattern) { $lines[$i] = "$key=$value"; $found = $true; break }
            }
            if (-not $found) { $lines += "$key=$value" }
            $lines -join "`r`n" | Set-Content $path -Encoding UTF8
        }

        Set-OrAdd-Env $envFile 'ALLOWED_HOSTS' $host
        Set-OrAdd-Env $envFile 'CSRF_TRUSTED_ORIGINS' $origin
        Write-Info "Actualizado $envFile -> ALLOWED_HOSTS=$host , CSRF_TRUSTED_ORIGINS=$origin"

        Write-Info "Recreando el servicio web para leer las nuevas variables..."
        docker compose up -d --no-deps --force-recreate web
    } catch {
        Write-Warn "No se pudo actualizar .env o recrear web: $_"
    }
}

# 6) Abrir la URL pública o local
if ($publicUrl) {
    Write-Info "Abriendo $publicUrl en el navegador..."
    Start-Process $publicUrl
} elseif ($localOk) {
    Write-Info "Abriendo http://localhost:8000 en el navegador..."
    Start-Process 'http://localhost:8000'
} else {
    Write-Err "No se encontró URL para abrir. Revisa los logs con: docker compose logs --tail 200 web"
    exit 1
}

Write-Info "Listo. Mantén ngrok en ejecución durante la presentación para que la URL pública permanezca accesible. Si ngrok se reinicia, vuelve a ejecutar este script." 
