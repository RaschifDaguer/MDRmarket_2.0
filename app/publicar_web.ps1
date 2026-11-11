# Publica la versión web de la app dentro del servidor de la API, en /app/
# (Railway: https://api-mdrmarket-production.up.railway.app/app/, y el
# servidor de la universidad: ver servidor/README.md).
#
# Uso (desde la carpeta app/, en PowerShell):
#   .\publicar_web.ps1
#   .\publicar_web.ps1 -ClaveMaps "AIza..."   # con mapa: SOLO una clave restringida a esos dominios
#
# Arma la app y la copia a api/public/app. Usa la API del mismo servidor desde
# donde se abre (API_URL=mismo-servidor, ver lib/core/config/env.dart): no hay
# que volver a armarla si cambia el dominio. Después hay que subir el cambio
# (git add, commit y push); Railway la publica sola y en la universidad se
# actualiza con servidor/actualizar.sh.
param(
    [string]$ClaveMaps = ''
)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$opciones = @(
    'build', 'web', '--release', '--no-wasm-dry-run',
    '--base-href', '/app/',
    '--dart-define=API_URL=mismo-servidor'
)
# La clave queda dentro del código que descarga cualquier visitante (así
# funciona Google Maps en la web): usa una restringida a "Sitios web" con los
# dominios donde se publica (ej. https://api-mdrmarket-production.up.railway.app/*)
# y solo "Maps JavaScript API".
if ($ClaveMaps) { $opciones += "--dart-define=GOOGLE_MAPS_KEY=$ClaveMaps" }

flutter @opciones
if ($LASTEXITCODE -ne 0) { throw 'No se pudo armar la app web.' }

# canvaskit (37 MB) no se copia: la app lo descarga de los servidores de Google.
$destino = Join-Path $PSScriptRoot '..\api\public\app'
robocopy (Join-Path $PSScriptRoot 'build\web') $destino /MIR /XD canvaskit /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw 'No se pudo copiar la app web a api/public/app.' }

Write-Host "Listo: app web copiada en api/public/app."
Write-Host 'Ahora: git add api/public/app ; git commit -m "App web: nueva versión" ; git push'
exit 0  # robocopy deja 1 cuando copió archivos: eso es éxito
