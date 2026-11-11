#!/bin/bash
# Respaldo de la base de MDR Market (corre dentro del contenedor "respaldo").
#   - Sin argumentos: espera hasta las 08:00 UTC (04:00 en Bolivia), respalda
#     y repite cada día. Borra los respaldos de más de $DIAS_A_GUARDAR días.
#   - "ahora": hace un respaldo en el momento y termina:
#       docker compose exec respaldo bash /respaldo.sh ahora
set -uo pipefail

respaldar() {
  local archivo="/respaldos/mdrmarket_$(date -u +%F_%H%M).sql.gz"
  if mysqldump -h db -uroot --single-transaction --routines --triggers --events \
       --set-gtid-purged=OFF --no-tablespaces --default-character-set=utf8mb4 \
       mdrmarket_new | gzip > "$archivo.tmp"; then
    mv "$archivo.tmp" "$archivo"
    echo "$(date -u +%FT%TZ) respaldo listo: $archivo ($(du -h "$archivo" | cut -f1))"
  else
    rm -f "$archivo.tmp"
    echo "$(date -u +%FT%TZ) ERROR: no se pudo respaldar la base" >&2
    return 1
  fi
  find /respaldos -name 'mdrmarket_*.sql.gz' -mtime +"${DIAS_A_GUARDAR:-14}" -delete
}

if [ "${1:-}" = "ahora" ]; then
  respaldar
  exit $?
fi

while true; do
  ahora=$(date -u +%s)
  proxima=$(date -u -d 'today 08:00' +%s)
  [ "$ahora" -ge "$proxima" ] && proxima=$(date -u -d 'tomorrow 08:00' +%s)
  sleep $((proxima - ahora))
  respaldar
done
