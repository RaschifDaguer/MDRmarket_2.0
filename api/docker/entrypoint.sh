#!/bin/sh
# Arranque del contenedor de la API.
set -e

# Puerto de Apache: $PORT (docker-compose pone 8080; si falta, 8080).
PORT="${PORT:-8080}"

# Por seguridad, deja un solo modo de Apache (prefork) también al arrancar.
rm -f /etc/apache2/mods-enabled/mpm_event.* /etc/apache2/mods-enabled/mpm_worker.*

sed -i "s/^Listen .*/Listen ${PORT}/" /etc/apache2/ports.conf
sed -i "s/<VirtualHost \*:[0-9]*>/<VirtualHost *:${PORT}>/" /etc/apache2/sites-available/000-default.conf

# Fotos y documentos que suben los usuarios (storage/app). Ahí está montado
# el volumen `archivos` de docker-compose (no se borra al actualizar); la
# primera vez llega vacío y a nombre de root: se crean las carpetas y se le
# dan a Apache para que pueda guardar.
mkdir -p /var/www/html/storage/app/public /var/www/html/storage/app/private
chown www-data:www-data /var/www/html/storage/app /var/www/html/storage/app/public /var/www/html/storage/app/private

# Cachea la configuración con las variables de entorno del servidor.
php artisan config:cache
php artisan route:cache

# Tareas automáticas (ver routes/console.php): rechazar los pedidos que la
# tienda no respondió y cancelar los listos que ningún repartidor tomó.
# Corren en segundo plano en este mismo contenedor, así no hace falta
# configurar un cron aparte en el servidor.
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
