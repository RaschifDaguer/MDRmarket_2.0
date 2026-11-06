# Publica la versión web de la app en el servidor de Railway, en /app/:
#   https://api-mdrmarket-production.up.railway.app/app/
#
# Uso (desde la carpeta app/, en PowerShell):
#   .\publicar_web.ps1
#   .\publicar_web.ps1 -ClaveMaps "AIza..."   # con mapa: SOLO una clave restringida a ese dominio
#
# Arma la app con la API del servidor y la copia a api/public/app. Después hay
# que subir el cambio (git add, commit y push a main): Railway la publica sola.
param(
    [string]$ClaveMaps = ''
)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$opciones = @(
    'build', 'web', '--release', '--no-wasm-dry-run',
    '--base-href', '/app/',
    '--dart-define=API_URL=https://api-mdrmarket-production.up.railway.app/api'
)
# La clave queda dentro del código que descarga cualquier visitante (así
# funciona Google Maps en la web): usa una restringida a "Sitios web" con
# https://api-mdrmarket-production.up.railway.app/* y solo "Maps JavaScript API".
if ($ClaveMaps) { $opciones += "--dart-define=GOOGLE_MAPS_KEY=$ClaveMaps" }

flutter @opciones
if ($LASTEXITCODE -ne 0) { throw 'No se pudo armar la app web.' }

# canvaskit (37 MB) no se copia: la app lo descarga de los servidores de Google.
$destino = Join-Path $PSScriptRoot '..\api\public\app'
robocopy (Join-Path $PSScriptRoot 'build\web') $destino /MIR /XD canvaskit /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw 'No se pudo copiar la app web a api/public/app.' }

Write-Host "Listo: app web copiada en api/public/app."
Write-Host 'Ahora: git add api/public/app ; git commit -m "App web: nueva versión" ; git push'
