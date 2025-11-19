# Abre automáticamente la URL pública de ngrok (si existe) o localhost:8000.
# Uso: desde PowerShell en la raíz del proyecto ejecutar:
#   .\scripts\open_ngrok_site.ps1
# Opcional (arrancar ngrok antes):
#   Start-Process -FilePath "C:\ruta\a\ngrok.exe" -ArgumentList "http 8000" -WindowStyle Hidden

$ngrokApi = 'http://127.0.0.1:4040/api/tunnels'
$maxAttempts = 30
$delaySeconds = 1

Write-Host "Buscando túnel ngrok en $ngrokApi (timeout $($maxAttempts * $delaySeconds) s)..."
for ($i = 0; $i -lt $maxAttempts; $i++) {
    try {
        $resp = Invoke-RestMethod -Uri $ngrokApi -UseBasicParsing -ErrorAction Stop
        if ($resp.tunnels -and $resp.tunnels.Count -gt 0) {
            # Preferir https
            $tunnel = $resp.tunnels | Where-Object { $_.proto -eq 'https' } | Select-Object -First 1
            if (-not $tunnel) { $tunnel = $resp.tunnels[0] }
            $publicUrl = $tunnel.public_url
            if ($publicUrl) {
                Write-Host "Abriendo: $publicUrl"
                Start-Process $publicUrl
                exit 0
            }
        }
    } catch {
        # No hay ngrok API aún
    }
    Start-Sleep -Seconds $delaySeconds
}

# Si no se encuentra ngrok, abrir localhost
$localUrl = 'http://localhost:8000'
Write-Host "No se detectó túnel ngrok. Abriendo $localUrl en el navegador..."
Start-Process $localUrl
exit 0
