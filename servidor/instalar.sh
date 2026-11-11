#!/bin/bash
# Primera instalación de MDR Market en el servidor (ver README.md).
# Crea .env con claves al azar (si todavía no existe), arma la imagen de la
# API y levanta todo. Se puede volver a correr: no toca un .env que ya existe.
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -f .env ]; then
  umask 077
  {
    echo "# Claves de MDR Market en este servidor. NUNCA subir este archivo a git."
    echo "DB_ROOT_PASSWORD=$(openssl rand -hex 24)"
    echo "DB_PASSWORD=$(openssl rand -hex 24)"
    echo "# Para seguir usando la verificación en dos pasos del panel, la misma APP_KEY de Railway."
    echo "APP_KEY=base64:$(openssl rand -base64 32)"
    echo "APP_URL=http://localhost:8090"
  } > .env
  echo "Creado .env con claves nuevas."
fi

mkdir -p respaldos
docker compose up -d --build
echo
echo "Listo. Estado de la API:  curl -s http://127.0.0.1:8090/api"
echo "Base vacía: cargarla con  ./importar_base.sh respaldo.sql"
