#!/bin/bash
# Trae lo último de GitHub y vuelve a armar la API. La base de datos, los
# archivos subidos y el .env no se tocan.
#   ./actualizar.sh
set -euo pipefail
cd "$(dirname "$0")"

git -C .. pull --ff-only
docker compose up -d --build
# Borra solo las imágenes viejas de ESTE proyecto (el disco es compartido).
docker image prune -f --filter label=proyecto=mdrmarket >/dev/null
echo "Actualizado. Estado: curl -s http://127.0.0.1:8090/api"
