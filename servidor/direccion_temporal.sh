#!/bin/bash
# Muestra la dirección pública temporal (túnel rápido de Cloudflare).
# Cambia cada vez que el túnel o el servidor se reinician.
cd "$(dirname "$0")"

url=$(docker compose --profile temporal logs tunel 2>&1 | grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' | tail -1)
if [ -z "$url" ]; then
  echo "El túnel temporal no está activo. Para iniciarlo:"
  echo "  docker compose --profile temporal up -d tunel"
  exit 1
fi
echo "Dirección temporal: $url"
echo "  App web: $url/app/"
echo "  Panel:   $url/admin"
echo "  API:     $url/api"
