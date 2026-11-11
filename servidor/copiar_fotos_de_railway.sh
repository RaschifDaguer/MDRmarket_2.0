#!/bin/bash
# Copia a este servidor las fotos públicas que están en Railway (fotos de
# perfil, logos y portadas de negocios, productos, evidencias de reportes).
# Se corre DESPUÉS de importar la base de Aiven: toma las rutas de la base.
# Las que ya están aquí no se vuelven a bajar.
#   ./copiar_fotos_de_railway.sh [https://api-mdrmarket-production.up.railway.app]
set -uo pipefail
cd "$(dirname "$0")"
ORIGEN="${1:-https://api-mdrmarket-production.up.railway.app}"

rutas=$(docker compose exec -T db sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mysql -uroot -N mdrmarket_new' <<'SQL'
SELECT foto_perfil_url FROM usuario WHERE foto_perfil_url IS NOT NULL
UNION SELECT logo_url FROM negocio WHERE logo_url IS NOT NULL
UNION SELECT banner_url FROM negocio WHERE banner_url IS NOT NULL
UNION SELECT url FROM producto_imagen
UNION SELECT url FROM reporte_evidencia;
SQL
)

copiadas=0; ya=0; faltan=0
# "docker compose exec" lee la entrada estándar: con </dev/null no se come
# la lista de rutas que está leyendo el ciclo.
while IFS= read -r ruta; do
  # Vacías, URLs externas (ya están en otro lado) o rutas raras: se saltan.
  case "$ruta" in ''|http://*|https://*|*..*|/*) continue ;; esac
  # Como www-data (el usuario de Apache), para que la API pueda seguir guardando en esas carpetas.
  if docker compose exec -T -u www-data api test -f "storage/app/public/$ruta" </dev/null; then
    ya=$((ya + 1))
  elif docker compose exec -T -u www-data api sh -c \
      'mkdir -p "$(dirname "storage/app/public/$1")" && curl -fsS --max-time 60 -o "storage/app/public/$1" "$2/api/archivos/$1"' \
      sh "$ruta" "$ORIGEN" </dev/null; then
    copiadas=$((copiadas + 1))
  else
    docker compose exec -T -u www-data api rm -f "storage/app/public/$ruta" </dev/null
    faltan=$((faltan + 1))
    echo "  no está en Railway: $ruta"
  fi
done <<< "$rutas"

echo "Fotos copiadas: $copiadas · ya estaban: $ya · no estaban en Railway: $faltan"
