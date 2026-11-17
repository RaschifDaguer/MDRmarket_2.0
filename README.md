# MDR Market 2.0

App de delivery para **Santa Cruz de la Sierra** (del centro al 10mo anillo).
Una sola cuenta tiene tres vistas: **cliente** (compra), **comercio** (vende)
y **repartidor** (lleva los pedidos).

| Parte | Dónde está | Con qué está hecha |
|---|---|---|
| API y panel de administrador (`/admin`) | `api/` de este repo | Laravel 12 + Filament 5 (PHP 8.3) |
| App (web, Android) | `app/` de este repo | Flutter 3.44 (Dart 3.12) |
| Base de datos | repo [MDRmarket_2.0_docker](https://github.com/RaschifDaguer/MDRmarket_2.0_docker) | MySQL 8.4 |
| Servidor de la universidad | `servidor/` de este repo | Docker Compose |

Esta guía es para alguien que recién empieza: síguela en orden.

## Contenido

- [Novedades](#novedades)
- [1. Requisitos: qué instalar](#1-requisitos-qué-instalar)
- [2. Bajar el proyecto](#2-bajar-el-proyecto)
- [3. Opción 1: en tu PC con Laragon](#3-opción-1-en-tu-pc-con-laragon)
- [4. Opción 2: en tu PC con Docker](#4-opción-2-en-tu-pc-con-docker)
- [5. Actualizar tu copia después de un git pull](#5-actualizar-tu-copia-después-de-un-git-pull)
- [6. Servidor de la universidad](#6-servidor-de-la-universidad)
- [7. Correr las pruebas](#7-correr-las-pruebas)
- [8. Reglas para trabajar en equipo](#8-reglas-para-trabajar-en-equipo)
- [9. Más documentación](#9-más-documentación)

---

## Novedades

**Pedidos**
- **Regla de pedidos:** la tienda solo puede **aceptar o rechazar** un pedido
  nuevo (con un motivo rápido como "Sin stock"). Una vez aceptado, ya no lo
  puede cancelar.
- **Plazos automáticos** (se cambian en el panel → Configuración):
  - si la tienda no responde en 1 minuto, el pedido se **rechaza solo**;
  - si el cliente no paga el QR en 10 minutos, se **cancela solo**;
  - si un pedido listo no lo toma ningún repartidor en 30 minutos, se **cancela solo**.

  Lo hace la tarea automática (`schedule:work`, ver el paso 3.4).
- **Comisión de la plataforma:** 8 % sobre los productos. El envío es todo del repartidor.
- **"¿Con cuánto pagas?"** en efectivo: el comercio y el repartidor ven cuánto cambio dar.
- **Ahorro:** el cliente ve cuánto ahorró con las ofertas.

**Calificaciones, reportes y avisos**
- **Calificar al repartidor** con estrellas y etiquetas ("Puntual", "Amable"…),
  además de la tienda y los productos.
- **Reportar un problema** con un pedido; el administrador lo ve y lo responde
  en el panel (Operación → Reportes).
- **Notificaciones** en la app (pedido aceptado, en camino, entregado…).

**Productos y mapas**
- **Varias fotos por producto** (hasta 4, con portada).
- **Mapa con OpenStreetMap:** si no hay clave de Google Maps, el mapa igual se
  ve (gratis y sin clave). Con clave, se usa Google Maps. Sirve para el
  seguimiento del pedido, el mapa del repartidor y el selector de dirección.

**Pantallas**
- **Modo oscuro / claro / automático** en los tres roles: es una sola
  preferencia para toda la app.
- **Cliente:** Inicio con tiendas cerca, Buscar, Cuenta, direcciones,
  seguimiento en el mapa, calificar y volver a pedir.
- **Comercio:**
  - Resumen con ventas contra ayer y gráfico de la semana;
  - pedido nuevo con cuenta regresiva, lista para alistar los productos y
    "Buscando repartidor";
  - productos con fotos y la ganancia calculada;
  - Ganancias por Hoy, Semana y Mes, y Más (horario, documentos, calificaciones).
- **Repartidor:**
  - registro en pasos y estado de cada documento;
  - Pedidos cerca, con En línea, lo ganado hoy y la meta del día;
  - pedido en curso con mapa y "Cómo llegar";
  - entrega con el PIN y cuánto cambio dar;
  - Mis entregas con un gráfico por día.

---

## 1. Requisitos: qué instalar

| Programa | Versión | Para qué | Dónde se baja |
|---|---|---|---|
| **Git** | 2.40 o más nueva | Bajar y subir el código | https://git-scm.com (en Windows trae **Git Bash**) |
| **Laragon** (Full) | 6 o más nueva | Trae PHP, MySQL, Composer y una terminal en un solo instalador | https://laragon.org |
| **PHP** | **8.3** | La API | Viene con Laragon (ver abajo) |
| **Composer** | 2.x | Las librerías de la API | Viene con Laragon |
| **MySQL** | **8.4** | La base de datos | Viene con Laragon (ver abajo) |
| **Flutter** | **3.44** (trae **Dart 3.12**) | La app | https://docs.flutter.dev/get-started/install |
| **Google Chrome** | La última | Correr la app web | https://www.google.com/chrome |
| **Docker Desktop** | 4.x | Solo para la [Opción 2](#4-opción-2-en-tu-pc-con-docker) | https://www.docker.com/products/docker-desktop |
| Android Studio | La última | Solo si vas a probar en Android | https://developer.android.com/studio |

**PHP 8.3 y MySQL 8.4 en Laragon:** si tu Laragon trae otras versiones, baja
las correctas y elígelas:

1. **PHP:** baja PHP 8.3 (*Thread Safe*, x64) de https://windows.php.net/download.
2. **MySQL:** baja MySQL 8.4 (*ZIP Archive*) de https://dev.mysql.com/downloads/mysql/.
3. Descomprímelos en `C:\laragon\bin\php\` y `C:\laragon\bin\mysql\`.
4. En Laragon: clic derecho → **PHP → Versión** y **MySQL → Versión** para elegirlas.

Para revisar que todo quedó bien, abre la **terminal de Laragon** (botón
*Terminal*) y escribe:

```
git --version
php -v              (debe decir 8.3)
composer --version
mysql --version     (debe decir 8.4)
flutter --version   (debe decir Flutter 3.44 y Dart 3.12)
```

`flutter doctor` te dice si falta algo más de Flutter.

---

## 2. Bajar el proyecto

Los dos repos van uno al lado del otro, dentro de `C:\proyecto`:

```
C:\proyecto\
├── MDRmarket_2.0\          ← API, app y servidor (este repo)
└── MDRmarket_2.0_docker\   ← base de datos (script y cambios)
```

En la terminal de Laragon (o en Git Bash):

```
mkdir C:\proyecto
cd C:\proyecto
git clone https://github.com/RaschifDaguer/MDRmarket_2.0.git
git clone https://github.com/RaschifDaguer/MDRmarket_2.0_docker.git
cd MDRmarket_2.0
git checkout servidor-universidad
```

`servidor-universidad` es la rama que corre en el servidor: trabaja siempre a
partir de ella (ver [8. Reglas](#8-reglas-para-trabajar-en-equipo)).

---

## 3. Opción 1: en tu PC con Laragon

Es la forma recomendada para programar. Al final tendrás la API en
`http://localhost:8001` y la app en Chrome.

### 3.1 Crear la base de datos

1. Abre Laragon y toca **Start All** (enciende MySQL).
2. En la terminal de Laragon:

   ```
   cd C:\proyecto\MDRmarket_2.0_docker
   mysql -u root --default-character-set=utf8mb4 -e "source mdrmarketnewdatabase.sql"
   ```

   Crea la base **`mdrmarket_new`** con todas sus tablas, vistas, triggers,
   procedimientos y datos de ejemplo. También se puede importar desde
   HeidiSQL o phpMyAdmin (**Importar** → `mdrmarketnewdatabase.sql`).

> ⚠️ Ese script **empieza borrando la base**: úsalo solo en tu PC, nunca en el servidor.

### 3.2 Configurar la API

```
cd C:\proyecto\MDRmarket_2.0\api
copy .env.example .env
composer install
php artisan key:generate
```

El `.env.example` ya apunta a la base `mdrmarket_new` de Laragon. Si tu MySQL
tiene otro usuario o contraseña, cámbialos en `.env` (`DB_USERNAME`,
`DB_PASSWORD`). **El `.env` no se sube nunca a GitHub.**

### 3.3 Encender la API

```
php artisan serve --port=8001
```

Abre http://localhost:8001/api: debe decir `"estado": "en línea"` y
`"base_de_datos": "conectada"`. Deja esta terminal abierta.

### 3.4 Encender las tareas automáticas (otra terminal)

Abre **otra** terminal de Laragon:

```
cd C:\proyecto\MDRmarket_2.0\api
php artisan schedule:work
```

**Por qué hace falta:** los plazos de los pedidos los aplica una tarea que
corre cada 15 segundos (`pedidos:vencer`). Se encarga de:

- rechazar los pedidos que la tienda no aceptó a tiempo;
- cancelar los QR que no se pagaron;
- cancelar los pedidos listos que ningún repartidor tomó.

Sin `schedule:work`, esos pedidos se quedan esperando para siempre. En el
servidor y en Docker ya corre sola.

### 3.5 Correr la app en Chrome

1. En `C:\proyecto\MDRmarket_2.0\app`, crea el archivo
   **`dart_defines.pruebas.local.json`** con esto:

   ```json
   {
     "API_URL": "http://localhost:8001/api"
   }
   ```

   Sin `GOOGLE_MAPS_KEY`, la app usa **OpenStreetMap** para el mapa, así que no
   hace falta ninguna clave. Este archivo **no se sube a GitHub** (está en el
   `.gitignore`). Si algún día usas una clave de Google Maps, va solo aquí,
   nunca en el código.

2. En la terminal:

   ```
   cd C:\proyecto\MDRmarket_2.0\app
   flutter pub get
   flutter run -d chrome --dart-define-from-file=dart_defines.pruebas.local.json
   ```

3. **En el emulador de Android**, usa `"API_URL": "http://10.0.2.2:8001/api"`:
   así ve el emulador a tu PC.

### 3.6 Tu cuenta y el panel de administrador

1. En la app, toca **Crear cuenta** y regístrate con tus datos.
2. Para entrar al panel, date el permiso de administrador. En la carpeta `api`:

   ```
   php artisan mdr:admin TU_CORREO
   ```

3. Entra a http://localhost:8001/admin. La primera vez pide configurar la
   **verificación en dos pasos** con una app como Google Authenticator. Guarda
   los códigos de recuperación.

Para probar los tres roles, desde **Cuenta** de la app puedes registrar un
negocio o pedir ser repartidor. Después apruébalos en el panel (**Aprobaciones**).

---

## 4. Opción 2: en tu PC con Docker

Levanta todo junto (base, API, panel, app web y tareas automáticas) con la
misma configuración del servidor. No necesitas Laragon, PHP ni MySQL.

**Requisito:** Docker Desktop abierto. Los comandos van en **Git Bash**.

### 4.1 Levantar todo

```bash
cd /c/proyecto/MDRmarket_2.0/servidor
./instalar.sh
```

`instalar.sh` crea `servidor/.env` con claves al azar (solo la primera vez),
arma la imagen de la API y enciende todo. **Ese `.env` no se sube a GitHub.**

### 4.2 Cargar la base

La primera vez la base está vacía. Cárgala con el script maestro:

```bash
./importar_base.sh ../../MDRmarket_2.0_docker/mdrmarketnewdatabase.sql
```

Listo:

| Qué | Dirección |
|---|---|
| API | http://localhost:8090/api |
| Panel de administrador | http://localhost:8090/admin |
| App web | http://localhost:8090/app/ |

Para correr la app con Flutter contra este Docker, pon
`"API_URL": "http://localhost:8090/api"` en tu `dart_defines.pruebas.local.json`.
Para darte el permiso de administrador:
`docker compose exec api php artisan mdr:admin TU_CORREO`.

### 4.3 Ver los logs, apagar y encender

| Qué quieres hacer | Comando (desde `servidor/`) |
|---|---|
| Ver qué está encendido | `docker compose ps` |
| Ver los logs de la API (Ctrl+C para salir) | `docker compose logs -f api` |
| Ver los logs de la base | `docker compose logs -f db` |
| Apagar (los datos se guardan) | `docker compose down` |
| Volver a encender | `docker compose up -d` |
| Reconstruir después de cambiar código de la API | `docker compose up -d --build` |
| Borrar todo, también la base (cuidado) | `docker compose down -v` |

> Si solo quieres la **base** en Docker, el repo `MDRmarket_2.0_docker` tiene
> su propio `docker-compose.yml` (ver su README).

---

## 5. Actualizar tu copia después de un git pull

Cuando alguien sube cambios, haz esto:

### 5.1 Traer el código

```
cd C:\proyecto\MDRmarket_2.0
git pull
cd api
composer install
php artisan optimize:clear
cd ..\app
flutter pub get

cd C:\proyecto\MDRmarket_2.0_docker
git pull
```

### 5.2 Aplicar los cambios de la base

Los cambios de estructura de la base llegan como archivos nuevos en
`MDRmarket_2.0_docker/cambios/`, con la fecha en el nombre. Hay que aplicarlos
**a tu base** en orden, del más viejo al más nuevo. **No vuelvas a importar
`mdrmarketnewdatabase.sql`**: borra tus datos.

**1. Mira cuáles te faltan.** Muestra cada archivo con `1` (ya lo tienes) o `0` (falta):

- **Terminal de Laragon:**

  ```
  cd C:\proyecto\MDRmarket_2.0_docker
  mysql -u root --default-character-set=utf8mb4 mdrmarket_new -e "source ver_cambios_aplicados.sql"
  ```

- **PowerShell** (en PowerShell no hay `mysql` en el PATH: va con la ruta
  completa; cambia la carpeta `mysql-8.4.3-winx64` si tu versión es otra):

  ```powershell
  cd C:\proyecto\MDRmarket_2.0_docker
  & "C:\laragon\bin\mysql\mysql-8.4.3-winx64\bin\mysql.exe" --user=root --host=127.0.0.1 --default-character-set=utf8mb4 mdrmarket_new -e "source ver_cambios_aplicados.sql"
  ```

**2. Aplica cada archivo que salga en `0`, en orden.** Ejemplo con uno:

- **Terminal de Laragon:**

  ```
  mysql -u root --default-character-set=utf8mb4 mdrmarket_new -e "source cambios/2026-11-16_plazos_de_pedidos.sql"
  ```

- **PowerShell:**

  ```powershell
  & "C:\laragon\bin\mysql\mysql-8.4.3-winx64\bin\mysql.exe" --user=root --host=127.0.0.1 --default-character-set=utf8mb4 mdrmarket_new -e "source cambios/2026-11-16_plazos_de_pedidos.sql"
  ```

Usa siempre `-e "source ..."` y no el símbolo `<`: el `<` no funciona en
PowerShell. Pon siempre `--default-character-set=utf8mb4`, porque sin eso los
acentos quedan mal.

Los archivos de `cambios/` se pueden aplicar dos veces sin problema: si no
estás seguro, aplícalos todos en orden.

**Con la Opción 2 (Docker)**, desde `MDRmarket_2.0/servidor` en Git Bash:

```bash
docker compose exec -T db sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mysql -uroot --default-character-set=utf8mb4 mdrmarket_new' < ../../MDRmarket_2.0_docker/cambios/ARCHIVO.sql
```

Después vuelve a correr la consulta del paso 1: todo debe salir en `1`.

> Si tienes la base de pruebas `mdrmarket_prueba` (ver [7. Pruebas](#7-correr-las-pruebas)),
> aplícale lo mismo cambiando `mdrmarket_new` por `mdrmarket_prueba`, o vuelve a crearla.

---

## 6. Servidor de la universidad

El servidor de la universidad es el **único servidor** del proyecto: ahí
corren la base, la API, el panel y la app web (en `/app/`), con Docker
Compose. Usa la rama **`servidor-universidad`**.

**Acceso:** pide el acceso SSH al responsable del servidor. Él te dice también
en qué carpeta está el proyecto.

### Publicar una versión nueva

Una vez que los cambios ya están en la rama `servidor-universidad`, entra al
servidor por SSH y ve a la carpeta `servidor/` del proyecto.

1. **Respaldo de la base** (siempre primero):

   ```bash
   sudo docker compose exec -T respaldo bash /respaldo.sh ahora </dev/null
   ```

   Queda en `servidor/respaldos/`. Si algo sale mal, se vuelve atrás con
   `./importar_base.sh respaldos/ARCHIVO.sql.gz`.

2. **Aplica los archivos nuevos de `cambios/`, en orden** (del más viejo al más
   nuevo). Cópialos al servidor (por ejemplo a `/tmp/`) y aplica cada uno:

   ```bash
   sudo docker compose exec -T db sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mysql -uroot --default-character-set=utf8mb4 mdrmarket_new' < /tmp/ARCHIVO.sql
   ```

   Para ver cuáles ya tiene el servidor, aplica de la misma forma
   `ver_cambios_aplicados.sql`: solo lee, no cambia nada.

3. **Actualiza el código y la API:**

   ```bash
   sudo ./actualizar.sh
   ```

   Trae lo último de GitHub (`git pull`) y vuelve a armar la API. La base, las
   fotos subidas y el `.env` no se tocan.

4. **Revisa que quedó en línea:**

   ```bash
   curl -s http://127.0.0.1:8090/api
   ```

> 🚨 **Nunca** importes `mdrmarketnewdatabase.sql` en el servidor: empieza
> borrando la base y se pierden los datos reales. En el servidor solo se aplican
> los archivos de `cambios/`.

Más detalle de cómo se maneja el servidor: [servidor/README.md](servidor/README.md).

### La app web

La app web se publica dentro de la API, en `api/public/app`. Para armarla de
nuevo (en PowerShell, desde `app/`):

```powershell
.\publicar_web.ps1
```

Sin clave usa OpenStreetMap. Después se hace commit de `api/public/app` y,
cuando esté en `servidor-universidad`, `./actualizar.sh` en el servidor.

---

## 7. Correr las pruebas

### API

Las pruebas usan una **base aparte, `mdrmarket_prueba`**, creada con el mismo
script maestro. Así se prueban los triggers y procedimientos reales. Cada
prueba deshace lo que hizo al terminar, así que tu base `mdrmarket_new` no se toca.

**Crear la base de pruebas (una vez)**, en Git Bash:

```bash
cd /c/proyecto/MDRmarket_2.0_docker
sed 's/mdrmarket_new/mdrmarket_prueba/g' mdrmarketnewdatabase.sql > /tmp/prueba.sql
mysql -u root --default-character-set=utf8mb4 < /tmp/prueba.sql
```

Si `mysql` no está en el PATH de Git Bash, usa la ruta completa:
`/c/laragon/bin/mysql/mysql-8.4.3-winx64/bin/mysql.exe`.

**Correr las pruebas:**

```
cd C:\proyecto\MDRmarket_2.0\api
php artisan test
```

### App

```
cd C:\proyecto\MDRmarket_2.0\app
flutter analyze
flutter test
```

Las pruebas de la app no usan internet ni la API: trabajan con datos falsos.

Antes de subir algo, **las dos suites tienen que pasar completas** y
`flutter analyze` no debe dar avisos.

---

## 8. Reglas para trabajar en equipo

1. **Una rama por tarea**, creada desde `servidor-universidad`:
   `git checkout servidor-universidad`, `git pull`, `git checkout -b mi-tarea`.
2. Al terminar, sube tu rama (`git push -u origin mi-tarea`) y abre un **Pull
   Request hacia `servidor-universidad`**. No subas directo a esa rama.
3. **Cambios en la base:** un archivo nuevo en `MDRmarket_2.0_docker/cambios/`.
   Se refleja también en `mdrmarketnewdatabase.sql` y se prueba en tu base local
   antes de aplicarlo en el servidor. Cómo escribirlos:
   [cambios/README.md](https://github.com/RaschifDaguer/MDRmarket_2.0_docker/blob/main/cambios/README.md).
4. **Formato:** en la app, `dart format -l 120` solo sobre los archivos que
   cambiaste. En la API, `vendor/bin/pint` sobre los archivos que cambiaste.
5. **Nunca subas secretos** (el repo es público):
   - archivos `.env` y `dart_defines*.local.json`;
   - claves de Google, `APP_KEY`, contraseñas;
   - llaves de firma (`.jks`, `key.properties`).

---

## 9. Más documentación

| Documento | De qué trata |
|---|---|
| [api/README.md](api/README.md) | Detalles de la API: seguridad, archivos, pruebas |
| [app/README.md](app/README.md) | Detalles de la app: estructura, APK de Android, mapa con Google |
| [servidor/README.md](servidor/README.md) | Cómo está armado y se maneja el servidor |
| [docs/API_FRONTEND.md](docs/API_FRONTEND.md) | Todas las rutas de la API con ejemplos |
| [docs/BASE_DE_DATOS.md](docs/BASE_DE_DATOS.md) | Cómo está pensada la base de datos |
| [docs/DIAGRAMA_BD.md](docs/DIAGRAMA_BD.md) | Diagrama de la base |
| [docs/HOJA_DE_RUTA.md](docs/HOJA_DE_RUTA.md) | Qué está hecho y qué falta |
