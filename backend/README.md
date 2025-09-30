# Backend - Sistema de Asistencias

Backend para el sistema de control de asistencias desarrollado con Node.js, Express y MongoDB Atlas.

## 🚀 Tecnologías

- **Node.js** v12+
- **Express.js** - Framework web
- **MongoDB Atlas** - Base de datos en la nube
- **Mongoose** - ODM para MongoDB
- **CORS** - Manejo de peticiones cross-origin
- **dotenv** - Variables de entorno

## 📦 Instalación Local

1. Clona el repositorio
2. Instala las dependencias:
   ```bash
   npm install
   ```
3. Configura las variables de entorno:
   ```bash
   cp .env.example .env
   ```
4. Edita `.env` con tu conexión a MongoDB Atlas
5. Ejecuta el servidor:
   ```bash
   npm start
   ```

El servidor estará disponible en `http://localhost:3000`

## 🌐 Despliegue en Railway

### Paso 1: Preparación
1. Asegúrate de que todos los cambios estén en el repositorio de GitHub
2. Ve a [Railway.app](https://railway.app) y crea una cuenta
3. Conecta tu cuenta de GitHub

### Paso 2: Crear Proyecto
1. Haz clic en "New Project"
2. Selecciona "Deploy from GitHub repo"
3. Elige tu repositorio
4. Railway detectará automáticamente que es un proyecto Node.js

### Paso 3: Configurar Variables de Entorno
En el dashboard de Railway:
1. Ve a la pestaña "Variables"
2. Agrega las siguientes variables:
   - `MONGODB_URI`: Tu string de conexión a MongoDB Atlas
   - Railway asignará automáticamente `PORT`

### Paso 4: Desplegar
1. Railway comenzará el despliegue automáticamente
2. Obtendrás una URL como `https://tu-proyecto.railway.app`
3. Usa esta URL en tu aplicación Flutter

## 📱 Configuración Flutter

Después del despliegue, actualiza la URL en tu app Flutter:

1. Ve a `lib/config/api_config.dart`
2. Actualiza `_baseUrlProd` con tu URL de Railway
3. Cambia `_isProduction = true` para compilar la APK final

## 🔧 Endpoints Disponibles

- `POST /login` - Autenticación de usuarios
- `GET /usuarios` - Lista de usuarios
- `GET /asistencias` - Registros de asistencia
- `GET /facultades` - Lista de facultades
- `GET /escuelas` - Lista de escuelas
- `POST /asistencias` - Crear registro de asistencia
- Y más...

## 🔒 Seguridad

- Las credenciales de MongoDB están en variables de entorno
- CORS configurado para peticiones web
- El archivo `.env` no se incluye en el repositorio

## 🛠️ Desarrollo

Para development local:
```bash
npm run dev
```

## 📝 Notas

- La aplicación usa MongoDB Atlas (no local)
- El puerto se asigna dinámicamente en producción
- Compatible con Node.js v12+
