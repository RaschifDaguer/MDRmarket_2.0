# API MDR Market (Laravel 12) — imagen para Railway o docker-compose.
# Versión exacta de PHP: la 8.3.36 corrige "PHP2Shell" (CVE-2026-109618 y
# CVE-2026-109619, ejecución remota de código, oct-2026). Al salir una versión
# de seguridad nueva de PHP 8.3, subir este número (https://www.php.net).
FROM php:8.3.36-apache

RUN apt-get update \
    && apt-get install -y --no-install-recommends git unzip libzip-dev libicu-dev \
    && docker-php-ext-install pdo_mysql zip intl opcache \
    && a2enmod rewrite \
    && rm -rf /var/lib/apt/lists/*

# Fotos de celular: el límite por defecto de PHP (2 MB) es muy chico.
RUN printf 'upload_max_filesize=10M\npost_max_size=12M\n' > /usr/local/etc/php/conf.d/subidas.ini

# No revelar versiones de PHP ni de Apache (ayudan a buscar fallas conocidas).
# session.upload_progress apagado: PHP lo recomendó el 23-oct-2026
# (CVE-2026-115560) y la app no lo usa.
RUN printf 'expose_php=Off\nsession.upload_progress.enabled=0\n' > /usr/local/etc/php/conf.d/seguridad.ini \
    && sed -ri -e 's/^ServerTokens .*/ServerTokens Prod/' -e 's/^ServerSignature .*/ServerSignature Off/' \
       /etc/apache2/conf-available/security.conf

# Los límites de solicitudes se cuentan en archivos del contenedor y no en la
# base (ver config/cache.php): más rápido y no la satura si hay una avalancha.
ENV CACHE_LIMITER=file

# Cada proceso de Apache reutiliza su conexión con la base (ver config/database.php).
ENV DB_PERSISTENT=true

# Máximo 10 procesos de Apache a la vez: alcanza para la memoria del plan de
# Railway y para las conexiones de Aiven. Si llegan más solicitudes, esperan
# su turno en vez de tumbar el servidor. Cada proceso se renueva cada 500.
RUN sed -ri -e 's/^(\s*MaxRequestWorkers\s+).*/\1 10/' -e 's/^(\s*MaxConnectionsPerChild\s+).*/\1 500/' \
       /etc/apache2/mods-available/mpm_prefork.conf

# Apache solo puede tener UN modo de procesos (MPM). PHP necesita "prefork";
# si queda también "event" o "worker" activo, Apache no arranca
# (error AH00534: More than one MPM loaded).
RUN rm -f /etc/apache2/mods-enabled/mpm_event.* /etc/apache2/mods-enabled/mpm_worker.* \
    && a2enmod mpm_prefork

# Apache sirve la carpeta public/ y respeta el .htaccess de Laravel.
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf \
    && sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf \
    && sed -ri -e 's!AllowOverride None!AllowOverride All!g' /etc/apache2/apache2.conf

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
WORKDIR /var/www/html

# Primero las dependencias (se reutilizan entre builds si composer.lock no cambia).
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist --no-interaction

COPY . .
RUN composer dump-autoload --optimize --no-dev \
    && chown -R www-data:www-data storage bootstrap/cache

COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

CMD ["entrypoint.sh"]
