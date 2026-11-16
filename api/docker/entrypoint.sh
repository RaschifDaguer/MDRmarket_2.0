#!/bin/sh
# Arranque del contenedor de la API.
set -e

# Railway indica el puerto en $PORT; en local se usa 8080.
PORT="${PORT:-8080}"

# Por seguridad, deja un solo modo de Apache (prefork) también al arrancar.
rm -f /etc/apache2/mods-enabled/mpm_event.* /etc/apache2/mods-enabled/mpm_worker.*

sed -i "s/^Listen .*/Listen ${PORT}/" /etc/apache2/ports.conf
sed -i "s/<VirtualHost \*:[0-9]*>/<VirtualHost *:${PORT}>/" /etc/apache2/sites-available/000-default.conf

# Bases que exigen conexión cifrada (ej. Aiven): el certificado CA llega en
# DB_SSL_CA_BASE64 (una sola línea, más fácil de pegar) o en DB_SSL_CA (texto
# PEM). Se guarda en un archivo y Laravel lo usa al conectarse.
if [ -n "${DB_SSL_CA_BASE64:-}" ]; then
    printf '%s' "$DB_SSL_CA_BASE64" | base64 -d > /tmp/db-ca.pem
    export MYSQL_ATTR_SSL_CA=/tmp/db-ca.pem
elif [ -n "${DB_SSL_CA:-}" ]; then
    printf '%s\n' "$DB_SSL_CA" > /tmp/db-ca.pem
    export MYSQL_ATTR_SSL_CA=/tmp/db-ca.pem
fi

# Fotos y documentos que suben los usuarios (storage/app). Si en Railway se
# montó ahí un disco permanente (Volume), llega vacío y a nombre de root: se
# crean las carpetas y se le dan a Apache para que pueda guardar.
mkdir -p /var/www/html/storage/app/public /var/www/html/storage/app/private
chown www-data:www-data /var/www/html/storage/app /var/www/html/storage/app/public /var/www/html/storage/app/private

# Cachea la configuración con las variables de entorno del servidor.
php artisan config:cache
php artisan route:cache

# Tareas automáticas (ver routes/console.php): rechazar los pedidos que la
# tienda no respondió y cancelar los listos que ningún repartidor tomó.
# Corren en segundo plano en este mismo contenedor, así funcionan igual en
# Railway y en el servidor de la universidad sin configurar un cron aparte.
# Con TAREAS_AUTOMATICAS=0 no se arrancan (ej. si hubiera dos copias de la
# API, para que corran en una sola; aunque corran dos, no hacen nada doble).
# Corren como www-data (igual que Apache) y, si se caen, vuelven a arrancar.
if [ "${TAREAS_AUTOMATICAS:-1}" != "0" ]; then
    su -s /bin/sh www-data -c '
        while true; do
            /usr/local/bin/php /var/www/html/artisan schedule:work --no-interaction > /dev/null
            echo "Las tareas automáticas se detuvieron; se vuelven a arrancar en 10 s." >&2
            sleep 10
        done
    ' &
fi

exec apache2-foreground
