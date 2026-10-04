#!/bin/sh
# Arranque del contenedor de la API.
set -e

# Railway indica el puerto en $PORT; en local se usa 8080.
PORT="${PORT:-8080}"

# Por seguridad, deja un solo modo de Apache (prefork) también al arrancar.
rm -f /etc/apache2/mods-enabled/mpm_event.* /etc/apache2/mods-enabled/mpm_worker.*

sed -i "s/^Listen .*/Listen ${PORT}/" /etc/apache2/ports.conf
sed -i "s/<VirtualHost \*:[0-9]*>/<VirtualHost *:${PORT}>/" /etc/apache2/sites-available/000-default.conf

# Bases que exigen conexión cifrada (ej. Aiven): el certificado CA llega como
# texto en DB_SSL_CA, se guarda en un archivo y Laravel lo usa al conectarse.
if [ -n "${DB_SSL_CA:-}" ]; then
    printf '%s\n' "$DB_SSL_CA" > /tmp/db-ca.pem
    export MYSQL_ATTR_SSL_CA=/tmp/db-ca.pem
fi

# Cachea la configuración con las variables de entorno del servidor.
php artisan config:cache
php artisan route:cache

exec apache2-foreground
