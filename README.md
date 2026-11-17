# App E-Commerce Flutter — Aplicaciones Móviles (Uniminuto)

- `backend/` → API REST (Node.js + Express, JWT, bcrypt)
- `app_src/` → código fuente Flutter (`lib/`, `pubspec.yaml`, `tool/`)
- `render.yaml` → configuración para desplegar el backend en Render

## 1. Subir el backend a Render

1. Sube esta carpeta (`tienda/`) a un repositorio de GitHub.
2. **Base de datos gratis (recomendado):** en https://www.mongodb.com/atlas crea un cluster M0 gratis →
   *Database Access* (crea usuario/clave) → *Network Access* → agrega `0.0.0.0/0` →
   *Connect → Drivers* y copia la cadena `mongodb+srv://usuario:clave@cluster.../`.
   Sin esto, en el plan gratis de Render los usuarios y pedidos se borran cada vez que el servicio se duerme o se redespliega.
3. En Render: *New → Blueprint* y elige tu repo (usa `render.yaml`), o *New → Web Service* con:
   Root Directory `backend`, Build `npm install`, Start `npm start`, Health Check `/api/health`.
4. En *Environment* define:
   - `JWT_SECRET` → una clave larga y aleatoria
   - `MONGODB_URI` → la cadena de Atlas
5. Al terminar, abre `https://TU-SERVICIO.onrender.com/api/health` → debe responder `{"ok":true}`.

> Alternativa sin Mongo: plan de pago + *Disk* montado en `/data` y variable `DATA_DIR=/data`.

## 2. Conectar la app Flutter
En `app_src/lib/config.dart` cambia `TU-SERVICIO` por el nombre de tu servicio de Render, o compila con:
```
flutter run --dart-define=API_URL=https://TU-SERVICIO.onrender.com/api
flutter build apk --dart-define=API_URL=https://TU-SERVICIO.onrender.com/api
```
Nota: en el plan gratis el servidor se duerme tras 15 min sin uso y la primera petición tarda ~50 s
(la app ya espera hasta 60 s). Para evitarlo, crea un monitor en UptimeRobot que llame a `/api/health` cada 5 min.

## 3. Crear el proyecto Flutter
```
flutter create --org co.edu.uniminuto tienda_app
```
Reemplaza dentro de `tienda_app/` la carpeta `lib/`, `pubspec.yaml` y `tool/` de `app_src/`. Luego:
```
cd tienda_app
flutter pub get
dart run tool/patch_manifest.dart      # permiso INTERNET
flutter run
```

## Backend local (opcional)
```
cd backend && npm install && npm start     # http://localhost:3000/api
```
Con el emulador usa `--dart-define=API_URL=http://10.0.2.2:3000/api`.

## Endpoints
POST /api/auth/register · POST /api/auth/login · GET /api/auth/check-username
POST /api/auth/forgot · POST /api/auth/reset
GET/PUT /api/me · PUT /api/me/password
GET /api/products (?category=&q=) · GET /api/products/:id
POST /api/orders · GET /api/orders · GET /api/health

## Recuperación de contraseña (enlace por correo)
`POST /api/auth/forgot` envía un correo con un **enlace** (`/reset-password?token=...`) que abre una página
web del backend para escribir la nueva contraseña (mín. 8 caracteres). El correo también trae un código de 6 dígitos
que se puede usar en la app.

Correo real con **Brevo** (gratis, 300/día; usa API HTTP porque Render gratis bloquea SMTP):
1. Crea cuenta en https://www.brevo.com → *Senders* → verifica tu correo remitente.
2. *SMTP & API → API Keys* → crea una clave.
3. En Render agrega: `BREVO_API_KEY`, `MAIL_FROM` (el remitente verificado) y opcional `MAIL_FROM_NAME`.

Si no configuras correo, funciona en **modo demo**: la respuesta incluye `devLink` y `devCode` y se imprimen en los logs.

## Probar con Postman
Importa `postman/Tienda-API.postman_collection.json` (y opcionalmente el environment).
Cambia la variable `baseUrl` a tu URL de Render (sin `/api`, ej. `https://mi-api.onrender.com`).
Ejecuta *Registro* y luego *Login*: el token JWT se guarda solo y las peticiones protegidas lo usan.
La colección trae tests automáticos (Runner → Run collection).
