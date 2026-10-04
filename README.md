# MDR Market 2.0

App de delivery para **Santa Cruz de la Sierra**, del centro al 10mo anillo, con
tres vistas en una sola cuenta:

- **Cliente:** compra productos de los negocios y sigue su pedido.
- **Repartidor:** lleva pedidos en moto, bicicleta, auto, camioneta o camión.
- **Comerciante:** publica productos, recibe pedidos y ve sus ganancias.

Cualquier usuario puede comprar. Si además se registra como repartidor o
comerciante, aparece el botón **"cambiar vista"**.

> 👋 **¿Recién llegas al proyecto?** Lee en orden: [Estado](#estado-actual) →
> [Herramientas](#1-herramientas-que-tienes-que-instalar) →
> [Accesos](#2-accesos-que-tienes-que-pedir) → [Ponerlo en marcha](#3-ponerlo-en-marcha-en-tu-pc) →
> [Cómo trabajar](#5-cómo-trabajar-sin-romper-nada) → [Hoja de ruta](docs/HOJA_DE_RUTA.md).

## 🔗 Enlaces del proyecto

| Qué | Enlace | Acceso |
|---|---|---|
| **API publicada** | https://api-mdrmarket-production.up.railway.app/api | Pública (prueba: [`/up`](https://api-mdrmarket-production.up.railway.app/up)) |
| **Railway** (servidor de la API: logs, variables, despliegues) | https://railway.com/project/2f0bb79b-64b4-4c55-9e58-2bd9222020f3 | Pedir que te agreguen al proyecto `confident-hope` |
| **Aiven** (base de datos de producción) | https://console.aiven.io → proyecto **`mdrmarket`** → servicio **`mdrmarket-db`** | Pedir invitación a la organización |
| **Repo de código** | https://github.com/RaschifDaguer/MDRmarket_2.0 | Público para leer; colaborador para subir cambios |
| **Repo de la base (Docker)** | https://github.com/RaschifDaguer/MDRmarket_2.0_docker | Ídem |
| **Google Cloud** (clave de Maps, para los módulos de mapa) | https://console.cloud.google.com/apis/credentials | Pedir al dueño |

## 🎯 Si vienes a hacer frontend y pruebas

Lo mínimo para empezar, **sin Laragon ni base de datos local**:

1. Instala **Git**, **Flutter 3.44** (`flutter doctor` sin errores), **Android Studio** (SDK + un emulador) y **VS Code** con las extensiones *Flutter* y *Dart*.
2. Pide acceso de colaborador a este repo y clónalo.
3. Ejecuta la app contra el servidor de internet, que ya está conectado a la base de Aiven:
   ```bash
   cd app
   flutter pub get
   flutter run --dart-define=API_URL=https://api-mdrmarket-production.up.railway.app/api
   ```
4. Crea tu propia cuenta desde la pantalla de registro y prueba.
5. Las pantallas que faltan y **cómo probar cada una** están en
   [docs/HOJA_DE_RUTA.md](docs/HOJA_DE_RUTA.md). Antes de subir cambios:
   `flutter analyze` y `flutter test` sin errores.
6. **Si algo falla, abre un Issue en GitHub** con: qué hiciste, qué esperabas,
   qué pasó, captura de pantalla y dispositivo (Chrome / emulador / celular).

Ten en cuenta que la app publicada usa **datos reales**: no borres ni cambies
datos de otros usuarios en tus pruebas. Si necesitas una base propia para
romper cosas, importa la copia `mdrmarket_new_aiven_2026-10-03.sql` del
[repo Docker](https://github.com/RaschifDaguer/MDRmarket_2.0_docker) en Laragon
(sección 3).

---

## Contenido

- [Estado actual](#estado-actual)
- [Cómo está armado](#cómo-está-armado)
- [1. Herramientas que tienes que instalar](#1-herramientas-que-tienes-que-instalar)
- [2. Accesos que tienes que pedir](#2-accesos-que-tienes-que-pedir)
- [3. Ponerlo en marcha en tu PC](#3-ponerlo-en-marcha-en-tu-pc)
- [4. Servidor en internet (Railway + Aiven)](#4-servidor-en-internet-railway--aiven)
- [5. Cómo trabajar sin romper nada](#5-cómo-trabajar-sin-romper-nada)
- [6. Estructura del código](#6-estructura-del-código)
- [7. API: rutas disponibles](#7-api-rutas-disponibles)
- [8. Reglas del negocio que ya están implementadas](#8-reglas-del-negocio-que-ya-están-implementadas)
- [9. Pruebas](#9-pruebas)
- [10. Problemas conocidos](#10-problemas-conocidos)
- [Documentación adicional](#documentación-adicional)

---

## Estado actual

| # | Módulo | Estado |
|---|---|---|
| 1 | **Base de datos** completa: usuarios y roles, documentos, vehículos, 12 categorías con 49 subcategorías, productos, pedidos, envío por km y anillos, reseñas, reportes, sanciones, ganancias del comerciante | ✅ Hecho |
| 2 | **API:** registro (contraseña segura escrita dos veces), inicio y cierre de sesión, perfil y cambio de vista | ✅ Hecho |
| 3 | **App:** pantallas de arranque, inicio de sesión, registro e inicio por vista, con el botón "cambiar vista" | ✅ Hecho |
| — | **Servidor en internet:** API en Railway + base en Aiven, con despliegue automático | ✅ Hecho |
| 4 | Registro de repartidor (vehículo y documentos) y de comerciante (negocio, GPS y foto) | ⏳ Siguiente |
| 5 | Catálogo con categorías, búsqueda y ofertas (frontend + API) | ⏳ |
| 6 | Carrito, pedido y cotización del envío | ⏳ |
| 7 | Vista comerciante: productos y pedidos entrantes | ⏳ |
| 8 | Vista repartidor: pedidos disponibles, aceptar y entregar | ⏳ |
| 9 | **Rastreo del pedido en el mapa** (GPS del repartidor en vivo) | ⏳ |
| 10 | Reseñas, reportes y sanciones en la app | ⏳ |
| 11 | Ganancias del comerciante (reportes y gráficos) | ⏳ |
| 12 | Panel de administrador web (Filament) | ⏳ |
| 13 | Notificaciones, recuperar contraseña y publicación (APK / Play Store / iOS) | ⏳ |

El detalle de cada módulo pendiente, con qué construir y cómo probarlo, está en
**[docs/HOJA_DE_RUTA.md](docs/HOJA_DE_RUTA.md)**.

---

## Cómo está armado

```
📱 App Flutter  ──HTTP──▶  API Laravel  ──SSL──▶  MySQL 8.4
 (Android, iOS, web)        (Railway)              (Aiven)
```

| Repositorio | Contenido |
|---|---|
| **[MDRmarket_2.0](https://github.com/RaschifDaguer/MDRmarket_2.0)** (este) | Código: `api/` (Laravel) y `app/` (Flutter) |
| **[MDRmarket_2.0_docker](https://github.com/RaschifDaguer/MDRmarket_2.0_docker)** | Base de datos: script `mdrmarketnewdatabase.sql` + Dockerfile |

| Parte | Dónde corre | URL / acceso |
|---|---|---|
| API | Railway, plan Free | https://api-mdrmarket-production.up.railway.app/api |
| Base de datos | Aiven for MySQL, plan Free, servicio `mdrmarket-db` | Consola de Aiven (pedir acceso) |
| Código | GitHub | Los dos repos de arriba |

**Decisión importante:** la estructura de la base **la define el script SQL**
del repo Docker, **no** las migraciones de Laravel. Tiene triggers, vistas y
procedimientos que hacen cumplir las reglas del negocio (stock, reseñas,
sanciones…). Ver [docs/BASE_DE_DATOS.md](docs/BASE_DE_DATOS.md).

---

## 1. Herramientas que tienes que instalar

### Elige tu camino: no todos necesitan todo

| Vas a trabajar en… | Instala | ¿Laragon? |
|---|---|---|
| **Solo la app** (pantallas Flutter) | Git, Flutter, Android Studio (SDK y emulador), VS Code | ❌ No. La app usa la API de Railway, que ya está conectada a la base de Aiven |
| **La API** (Laravel) | Lo anterior + PHP 8.3 y Composer | ✅ Recomendado. Es la forma más fácil de tener PHP, Composer y MySQL en Windows (alternativas: XAMPP, Herd o Docker) |
| **La base de datos** | Un cliente MySQL: **DBeaver**, **MySQL Workbench** o **HeidiSQL** | ❌ No obligatorio. Puedes conectarte directo a Aiven con SSL ([cómo](docs/BASE_DE_DATOS.md#conectarse-a-la-base-de-producción-aiven)) |

> ⚠️ Aiven es la base **de producción**. Prueba los cambios primero en una base
> local (Laragon o Docker) y aplícalos en Aiven solo cuando funcionen.

### Versiones

Versiones con las que se desarrolló (usa las mismas o más nuevas dentro de la misma versión mayor):

| Herramienta | Versión | Para qué | Notas |
|---|---|---|---|
| **Git** | 2.54 | Clonar y subir cambios | https://git-scm.com |
| **Laragon** | 8.6 (trae PHP 8.3, MySQL 8.4, Apache, phpMyAdmin, HeidiSQL) | Correr la API y la base en tu PC | https://laragon.org — en Windows es lo más simple |
| **PHP** | 8.3 (mínimo 8.2) | La API | Viene con Laragon |
| **Composer** | 2.9 | Dependencias de PHP | Viene con Laragon o https://getcomposer.org |
| **MySQL** | 8.4 | Base de datos local | Viene con Laragon |
| **Flutter SDK** | 3.44.1 (Dart 3.12.1), canal stable | La app | https://docs.flutter.dev/get-started/install — corre `flutter doctor` al terminar |
| **Android Studio** | Reciente | SDK de Android y emulador | Solo para Android SDK + emulador; el código se edita en VS Code |
| **VS Code** | Reciente | Editor | Extensiones: *Flutter*, *Dart*, *PHP Intelephense*, *Laravel Extra Intellisense* (opcional) |
| **Google Chrome** | Reciente | Probar la app en web | `flutter run -d chrome` |
| Docker Desktop | Opcional | Levantar la base con un comando | Solo si no usas Laragon |
| Xcode (Mac) | Opcional | Compilar para iPhone | **Solo en Mac.** Desde Windows no se puede compilar iOS |

Paquetes principales (se instalan solos con `composer install` / `flutter pub get`):

- **App:** `flutter_riverpod` 3.4 (estado), `go_router` 18 (navegación), `dio` 5 (HTTP), `flutter_secure_storage` 11 (token guardado cifrado).
- **API:** `laravel/framework` 12, `laravel/sanctum` 4 (login con tokens), `laravel-lang/common` (mensajes en español).

---

## 2. Accesos que tienes que pedir

Pídeselos al dueño del proyecto (**Raschif Daguer**, GitHub `RaschifDaguer`):

| Acceso | Para qué | Cómo te lo da |
|---|---|---|
| **GitHub** — colaborador en los dos repos | Subir cambios (push) | Repo → *Settings → Collaborators → Add people* |
| **Railway** — proyecto `confident-hope` | Ver logs y variables de la API | *Project Settings → Members* (si el plan lo permite; si no, te comparte los logs) |
| **Aiven** — proyecto `mdrmarket` | Ver/administrar la base de producción | *Admin → Users → Invite* |
| **Valores del `.env` de producción** | Solo si vas a tocar el servidor | Por mensaje privado, **nunca** por el repo ni grupos |
| **Clave de Google Maps** | Módulos de mapa y rastreo (9) | Es la misma de la versión anterior; va en `.env`, no en el código |

> 🔒 **Secretos:** contraseñas, `APP_KEY`, la clave de Google y el `ca.pem` de
> Aiven **nunca** se suben al repositorio. Los `.gitignore` ya excluyen `.env`
> y `*.pem`.

---

## 3. Ponerlo en marcha en tu PC

### 3.1 Clonar
```bash
git clone https://github.com/RaschifDaguer/MDRmarket_2.0.git
git clone https://github.com/RaschifDaguer/MDRmarket_2.0_docker.git
```

### 3.2 Base de datos local
1. Abre **Laragon → Start All**.
2. Abre **phpMyAdmin** (o HeidiSQL) → **Importar** → uno de estos dos archivos del repo Docker:
   - `mdrmarket_new_aiven_2026-10-03.sql`: **copia exacta de producción (Aiven)**. Úsala para tener lo mismo que la app publicada.
   - `mdrmarketnewdatabase.sql`: script maestro comentado, para crear la base desde cero.

   Cualquiera de los dos crea solo la base **`mdrmarket_new`** (hoy con 10
   usuarios, 3 negocios y 26 productos de ejemplo). ⚠️ Ninguno se importa en Aiven.

   *Alternativa con Docker:* dentro de `MDRmarket_2.0_docker`, `docker compose up -d --build`
   (queda en `localhost:3307`, usuario `root`, contraseña `root`).

### 3.3 API
```bash
cd MDRmarket_2.0/api
composer install
copy .env.example .env          # en Mac/Linux: cp .env.example .env
php artisan key:generate
php artisan serve --host=0.0.0.0 --port=8001
```
Abre http://localhost:8001/up → debe responder. El `.env.example` ya apunta a
`mdrmarket_new` en `127.0.0.1:3306` con usuario `root` sin contraseña (Laragon).

### 3.4 App
```bash
cd MDRmarket_2.0/app
flutter pub get
flutter run -d chrome           # navegador
flutter run                     # emulador Android abierto en Android Studio
```

| Dónde corre la app | API que usa por defecto |
|---|---|
| Chrome | `http://localhost:8001/api` |
| Emulador Android | `http://10.0.2.2:8001/api` (así ve el emulador a tu PC) |
| Celular real en tu Wi-Fi | `flutter run --dart-define=API_URL=http://IP-DE-TU-PC:8001/api` |
| Contra el servidor de internet | `flutter run --dart-define=API_URL=https://api-mdrmarket-production.up.railway.app/api` |

Usuarios de ejemplo: los `*@mdrmarket.local` del script. Lo más simple es
**crear tu propia cuenta** desde la pantalla de registro.

### 3.5 Atajos sin Laragon

- **Solo app:** salta 3.2 y 3.3, y en 3.4 corre
  `flutter run --dart-define=API_URL=https://api-mdrmarket-production.up.railway.app/api`.
- **API local contra la base de Aiven** (sin MySQL local): en `api/.env` pon los
  datos de Aiven y la ruta del certificado (pídelos al dueño):
  ```
  DB_HOST=mdrmarket-db-mdrmarket.h.aivencloud.com
  DB_PORT=26451
  DB_DATABASE=mdrmarket_new
  DB_USERNAME=avnadmin
  DB_PASSWORD=(pedir al dueño)
  MYSQL_ATTR_SSL_CA=C:/ruta/a/ca.pem
  ```
  ⚠️ Así trabajas sobre **datos reales**: lo que crees o borres se ve en la app publicada.

---

## 4. Servidor en internet (Railway + Aiven)

- **Despliegue automático:** cada `git push` a `main` que cambie algo dentro de
  `api/` hace que Railway reconstruya y publique la API sola (3–5 min).
  Cambios solo en `app/` no redespliegan nada.
- **La app instalada en celulares no se actualiza sola:** si cambias pantallas,
  hay que generar e instalar un APK nuevo (`flutter build apk`).
- **La base en Aiven NO se actualiza sola.** Si cambias el script SQL, hay que
  aplicar el cambio a mano. **Nunca importes el script completo en Aiven**: borra
  todas las tablas y los datos. Ver [docs/BASE_DE_DATOS.md](docs/BASE_DE_DATOS.md#cómo-cambiar-la-base).
- Configuración de Railway (Root Directory `/api`, variables, `DB_SSL_CA_BASE64`):
  ver [api/README.md](api/README.md#docker-y-railway).

---

## 5. Cómo trabajar sin romper nada

1. **Una rama por módulo o arreglo:**
   ```bash
   git checkout main && git pull
   git checkout -b modulo-4-registro-repartidor
   ```
2. **Prueba en tu PC** (Laragon + `flutter run`) antes de subir.
3. **Corre las pruebas** (ver [Pruebas](#9-pruebas)) y `flutter analyze` sin errores.
4. **Sube la rama y abre un Pull Request** a `main`. Que el otro lo revise.
5. Al unir a `main`, si tocaste `api/`, Railway publica solo. Revisa que el
   servicio quede *Online* y prueba `https://…/up`.

Convenciones del código:

- **Todo en español:** nombres de tablas, columnas, variables, mensajes y commits.
- **App:** una carpeta por funcionalidad en `app/lib/features/<feature>/` con
  `data/` (llamadas a la API), `domain/` (modelos) y `presentation/` (pantallas y
  estado con Riverpod). Lo compartido va en `app/lib/core/`.
- **API:** controladores en `app/Http/Controllers/Api`, validaciones en
  `app/Http/Requests`, respuestas con `app/Http/Resources`. Errores siempre en
  JSON y en español.
- **Reglas del negocio importantes van en la base** (triggers), así se cumplen
  aunque alguien llame a la API de otra forma.

---

## 6. Estructura del código

```
MDRmarket_2.0/
├── README.md                 ← este archivo
├── docs/
│   ├── HOJA_DE_RUTA.md       ← qué falta y cómo hacerlo
│   └── BASE_DE_DATOS.md      ← cómo está la base y cómo cambiarla
├── api/                      ← Laravel 12
│   ├── app/Http/Controllers/Api/AuthController.php
│   ├── app/Http/Requests/RegistroRequest.php
│   ├── app/Http/Resources/UsuarioResource.php
│   ├── app/Models/Usuario.php        (modelo de login, tabla `usuario`)
│   ├── routes/api.php
│   ├── bootstrap/app.php             (errores JSON en español)
│   ├── lang/es/                      (mensajes de validación)
│   ├── Dockerfile + docker/entrypoint.sh  (imagen para Railway)
│   └── README.md
└── app/                      ← Flutter
    ├── lib/main.dart, app.dart
    ├── lib/core/            config (URL de la API), red (Dio), router, tema, almacenamiento
    ├── lib/features/auth/   login, registro, sesión
    ├── lib/features/inicio/ pantalla de inicio por vista + cambio de vista
    ├── test/                pruebas
    └── README.md
```

En la PC del dueño, `C:\Raschif\laragon\www\mdrmarket_v2_api` es un enlace a
`api/` para que Laragon la muestre; no hace falta replicarlo.

---

## 7. API: rutas disponibles

| Método | Ruta | Sesión | Para qué |
|---|---|---|---|
| POST | `/api/auth/registro` | — | Crear cuenta. Devuelve `token` y `usuario` |
| POST | `/api/auth/login` | — | Iniciar sesión. Devuelve `token` y `usuario` |
| POST | `/api/auth/logout` | ✔ | Cerrar sesión en este dispositivo |
| GET | `/api/me` | ✔ | Usuario, `vistas` y `puede_cambiar_vista` |
| PUT | `/api/me/vista` | ✔ | Guardar la vista activa (`cliente` / `repartidor` / `comerciante`) |

Sesión = cabecera `Authorization: Bearer <token>` (Laravel Sanctum).
Prueba rápida:
```bash
curl https://api-mdrmarket-production.up.railway.app/api/me -H "Accept: application/json"
# → 401 {"message":"Tu sesión expiró o no iniciaste sesión."}
```

---

## 8. Reglas del negocio que ya están implementadas

- **Registro:** correo, contraseña **escrita dos veces** (mínimo 8 caracteres
  con mayúscula, minúscula y número), nombre, apellido y carnet
  (número + complemento + expedido). Correo y carnet no se pueden repetir.
- **Vistas:** cliente siempre; repartidor si tiene perfil (aunque esté en
  revisión); comerciante si tiene un negocio. El botón "cambiar vista" **solo
  aparece si tiene más de una**.
- **Convertirse en repartidor o comerciante** pidiendo solo lo que falta:
  `CALL sp_datos_faltantes(usuario, 'repartidor')`. Al repartidor se le piden
  carnet (anverso y reverso), licencia, foto del vehículo, foto de la placa y
  RUAT; a una bicicleta solo carnet y foto del vehículo.
- **Envío:** precio por km recorrido (`tarifa_envio`: hasta 3 km 3 Bs, hasta
  6 km 5 Bs, hasta 10 km 8 Bs, hasta 15 km 12 Bs, hasta 20 km 15 Bs, hasta 30 km 20 Bs)
  y cobertura del centro al **10mo anillo** (`fn_cotizar_envio`).
- **Stock:** se descuenta en la base al crear el pedido (falla con "Stock
  insuficiente") y se devuelve si se cancela.
- **Reseñas:** una por usuario para cada producto, negocio o repartidor,
  editable; solo después de recibir un pedido; nadie se reseña a sí mismo.
- **Reportes y sanciones:** reportes con motivo; las sanciones bloquean pedidos,
  ocultan negocios/productos y vencen solas.
- **Ganancias del comerciante:** las ventas se registran solas al entregar un
  pedido; reportes por día, semana, mes o año (`sp_reporte_negocio`).
- **Horario:** todo se guarda en **UTC**; los reportes se muestran en hora de
  Bolivia (-04:00).

Detalle completo en [docs/BASE_DE_DATOS.md](docs/BASE_DE_DATOS.md).

---

## 9. Pruebas

```bash
# App (desde app/)
flutter analyze
flutter test                                                        # formulario de registro
flutter test --dart-define=API_URL=http://127.0.0.1:8001/api        # + recorrido real contra la API local

# API (con la API encendida)
curl http://localhost:8001/up
```

Regla del equipo: **cada módulo nuevo trae al menos una prueba simple que
demuestre que cumple su función** (ver "Cómo probarlo" en cada módulo de la
[hoja de ruta](docs/HOJA_DE_RUTA.md)).

---

## 10. Problemas conocidos

| Síntoma | Causa | Qué hacer |
|---|---|---|
| La primera consulta al servidor tarda 10–30 s | Railway Free "duerme" la API sin uso | Normal; las siguientes son rápidas |
| La API responde 500 en todo lo que usa la base | Aiven apagó la base gratuita por inactividad | Consola de Aiven → encender el servicio `mdrmarket-db` |
| Railway: `AH00534: More than one MPM loaded` | Imagen php:apache | Ya resuelto en `Dockerfile` y `entrypoint.sh`; no borrar esas líneas |
| Railway: "Free plan resource provision limit exceeded" | Límite del plan Free (1 USD/mes) | Por eso la base está en Aiven y no en Railway |
| La app en el emulador no conecta | Usa `localhost` | El emulador usa `10.0.2.2`; un celular real necesita la IP de la PC |
| Error de CORS en Chrome | API apagada o URL mal escrita | Revisa que la API esté encendida y la URL termine en `/api` |
| VS Code marca en rojo cosas de Laravel | El editor no tiene indexado `vendor/` | Abre la carpeta `api/` sola en VS Code o corre `composer install` |

---

## Documentación adicional

- [docs/HOJA_DE_RUTA.md](docs/HOJA_DE_RUTA.md) — módulos pendientes, uno por uno.
- [docs/BASE_DE_DATOS.md](docs/BASE_DE_DATOS.md) — tablas, vistas, triggers y cómo cambiar la base.
- [api/README.md](api/README.md) — API y despliegue en Railway.
- [app/README.md](app/README.md) — app Flutter.
- [Repo de la base (Docker)](https://github.com/RaschifDaguer/MDRmarket_2.0_docker).
