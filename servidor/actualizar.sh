#!/bin/bash
# Trae lo último de GitHub y vuelve a armar la API. La base de datos, los
# archivos subidos y el .env no se tocan.
#   sudo ./actualizar.sh     (o sin sudo, si el usuario está en el grupo docker)
set -euo pipefail
cd "$(dirname "$0")"

# git corre como el dueño de la carpeta (remoto1): si corre como root, git
# se niega a tocar un repositorio ajeno ("dubious ownership").
dueno=$(stat -c %U ..)
if [ "$(id -u)" = 0 ] && [ "$dueno" != root ]; then
  sudo -u "$dueno" git -C .. pull --ff-only
else
  git -C .. pull --ff-only
fi

docker compose up -d --build
# Borra solo las imágenes viejas de ESTE proyecto (el disco es compartido).
docker image prune -f --filter label=proyecto=mdrmarket >/dev/null
echo "Actualizado. Estado: curl -s http://127.0.0.1:8090/api"
