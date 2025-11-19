# Instrucciones para levantar el proyecto (IA-deber / iaweb)

Este archivo describe los pasos mínimos y comandos listos para copiar/pegar en PowerShell para levantar la aplicación Django contenida en Docker y, opcionalmente, exponerla públicamente con ngrok.

IMPORTANTE: Ejecuta los comandos desde PowerShell en Windows. Ajusta rutas si tu carpeta de trabajo es distinta.

=====================================================================
1) Prerrequisitos
- Docker Desktop instalado y en ejecución
- PowerShell (Windows)
- Git (para clonar el repositorio)
- (Opcional) `ngrok.exe` si quieres exponer la app públicamente

=====================================================================
2) Clonar el repositorio (si aplica)
```powershell
cd $HOME\Desktop
git clone https://github.com/christopherpaucar/EntrenamientoModeloIA_GradosCaF.git
cd EntrenamientoModeloIA_GradosCaF\iaweb
```

=====================================================================
3) Preparar `.env` (archivo en `iaweb`)
- Crea o edita `iaweb/.env` con al menos estas variables para pruebas locales:
```dotenv
DEBUG=False
ALLOWED_HOSTS=localhost,127.0.0.1
CSRF_TRUSTED_ORIGINS=http://localhost:8000,http://127.0.0.1:8000
SECRET_KEY=pon_aca_una_clave_secreta
```
- Nota: Si vas a usar ngrok, el script `start_presentation.ps1` actualizará `.env` automáticamente con el `public_url`.

=====================================================================
4) Levantar los contenedores (sin ngrok)
```powershell
# Desde la carpeta iaweb
Set-Location "C:\Users\Usuario\OneDrive - UNIVERSIDAD TÉCNICA DE AMBATO\Escritorio\IA-deber\iaweb"

docker compose up -d

docker compose ps
docker compose logs --no-color --timestamps --tail 200 web
```

Comprobar la app localmente:
```powershell
cURL.exe -v http://127.0.0.1:8000/
# o abrir en navegador
Start-Process "http://localhost:8000"
```

Si sólo editaste plantillas o código (bind-mount activo), recarga plantillas reiniciando `web`:
```powershell
docker compose restart web
```

=====================================================================
5) Levantar la app y exponerla públicamente (ngrok)
- Coloca `ngrok.exe` en `iaweb` o en una ruta conocida.
- Ejecuta el script todo-en-uno (levanta Docker, arranca ngrok, actualiza `.env`, recrea `web` y abre la URL):
```powershell
# Desde la raíz del repo (EntrenamientoModeloIA_GradosCaF)
powershell -ExecutionPolicy Bypass -File .\iaweb\scripts\start_presentation.ps1 -NgrokPath ".\iaweb\ngrok.exe"
```

Qué hace: arranca los contenedores, espera que `localhost:8000` responda, inicia ngrok, obtiene `public_url`, actualiza `.env` (`ALLOWED_HOSTS` y `CSRF_TRUSTED_ORIGINS`), recrea `web` y abre la URL pública.

Nota: ngrok gratuito asigna subdominio aleatorio cada vez que lo inicias. Mantén ngrok en ejecución durante la presentación.

=====================================================================
6) Si cambias dependencias o Dockerfile
```powershell
# Rebuild y levantar web
docker compose build --no-cache web
docker compose up -d web
docker compose logs --no-color --timestamps --tail 200 web
```

=====================================================================
7) Migraciones y assets estáticos
```powershell
docker compose exec web python manage.py migrate --noinput
docker compose exec web python manage.py collectstatic --noinput
docker compose restart web
```

=====================================================================
8) Recrear `web` cuando cambies `.env` (para que lea las nuevas variables)
```powershell
# Recreate web para que lea el .env actualizado
docker compose up -d --no-deps --force-recreate web
```

=====================================================================
9) Comandos de diagnóstico (si algo falla)
- Estado de contenedores:
```powershell
docker compose ps
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
```
- Logs del servicio web:
```powershell
docker compose logs --no-color --timestamps --tail 300 web
```
- Ver si el host publica el puerto 8000:
```powershell
netstat -ano | findstr :8000
```
- Obtener variables de entorno dentro del contenedor (útil para ALLOWED_HOSTS/CSRF):
```powershell
docker compose exec web printenv ALLOWED_HOSTS
docker compose exec web printenv CSRF_TRUSTED_ORIGINS
```
- Probar desde dentro del contenedor si Django responde:
```powershell
docker compose exec web python - <<'PY'
import urllib.request, sys
try:
    r = urllib.request.urlopen('http://127.0.0.1:8000/', timeout=5)
    print('STATUS', r.status)
except Exception as e:
    print('ERROR', e)
    sys.exit(1)
PY
```

=====================================================================
10) Detener y limpiar
```powershell
# Parar servicios
docker compose down

# Si quieres eliminar imágenes/volúmenes (destructivo)
docker compose down --rmi all --volumes
```

=====================================================================
Consejos finales
- Ejecuta `docker compose build` con antelación si el equipo es lento (la instalación de TensorFlow puede tardar mucho).
- Mantén la terminal de ngrok abierta o usa el script `start_presentation.ps1` para arrancarlo en segundo plano.
- Para la presentación, prueba todo 10–15 minutos antes y deja Docker/ngrok corriendo.

=====================================================================
Si quieres, puedo añadir este archivo como `.txt` en la raíz o generar un acceso directo `.lnk` para ejecutar el script de presentación con doble clic.
