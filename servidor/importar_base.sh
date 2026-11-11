#!/bin/bash
# Reemplaza la base de MDR Market del servidor con un archivo .sql o .sql.gz
# (por ejemplo, el respaldo que se baja de Aiven, o el script maestro).
# ¡BORRA lo que haya ahora en la base del servidor! Antes guarda un respaldo
# en ./respaldos por si acaso.
#
#   ./importar_base.sh respaldo.sql        (o .sql.gz)
set -euo pipefail
cd "$(dirname "$0")"

archivo="${1:?Uso: ./importar_base.sh archivo.sql[.gz]}"
[ -f "$archivo" ] || { echo "No existe: $archivo" >&2; exit 1; }

# mysql dentro del contenedor, con la clave de root que ya tiene adentro
# (así la clave no aparece en la lista de procesos del servidor).
sql() {
  docker compose exec -T db sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mysql -uroot --default-character-set=utf8mb4 "$@"' sh "$@"
}
leer() {
  case "$archivo" in
    *.gz) gzip -dc "$archivo" ;;
    *) cat "$archivo" ;;
  esac
}

# (Los comandos que no necesitan entrada llevan </dev/null: "docker compose
# exec" lee la entrada estándar y se comería lo que venga después.)
echo "1/3 Respaldo de la base actual (en ./respaldos)..."
docker compose exec -T respaldo bash /respaldo.sh ahora </dev/null || echo "   (no se pudo; la base quizás estaba vacía)"

echo "2/3 Borrando y creando la base mdrmarket_new..."
sql -e "DROP DATABASE IF EXISTS mdrmarket_new;
        CREATE DATABASE mdrmarket_new CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
        GRANT ALL PRIVILEGES ON mdrmarket_new.* TO 'mdr'@'%';" </dev/null

echo "3/3 Importando $archivo..."
# Sin DEFINER: en Aiven los triggers, vistas y procedimientos están a nombre
# de su usuario (avnadmin), que aquí no existe; así quedan a nombre de root.
leer | sed -E 's/DEFINER=`[^`]+`@`[^`]+`//g' | sql mdrmarket_new

sql -N mdrmarket_new -e "
  SELECT CONCAT('Tablas y vistas: ', COUNT(*)) FROM information_schema.tables WHERE table_schema = 'mdrmarket_new';
  SELECT CONCAT('Triggers: ', COUNT(*)) FROM information_schema.triggers WHERE trigger_schema = 'mdrmarket_new';
  SELECT CONCAT('Procedimientos y funciones: ', COUNT(*)) FROM information_schema.routines WHERE routine_schema = 'mdrmarket_new';
  SELECT CONCAT('Usuarios: ', COUNT(*)) FROM usuario;" </dev/null
echo "Listo."
