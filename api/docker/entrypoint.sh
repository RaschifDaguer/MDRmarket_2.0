#!/bin/sh
# Arranque del contenedor de la API.
set -e

# Railway indica el puerto en $PORT; en local se usa 8080.
PORT="${PORT:-8080}"
sed -i "s/^Listen .*/Listen ${PORT}/" /etc/apache2/ports.conf
sed -i "s/<VirtualHost \*:[0-9]*>/<VirtualHost *:${PORT}>/" /etc/apache2/sites-available/000-default.conf

# Cachea la configuración con las variables de entorno del servidor.
php artisan config:cache
php artisan route:cache

exec apache2-foreground
