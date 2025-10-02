# 🚂 Despliegue en Railway - Acees Group Backend

## 📋 Pasos para Desplegar en Railway

### 1. Preparación
1. Asegúrate de tener tu repositorio en GitHub
2. Tener cuenta en [Railway](https://railway.app)
3. MongoDB Atlas configurado

### 2. Crear Proyecto en Railway
```bash
# Instalar Railway CLI (opcional)
npm install -g @railway/cli

# Login
railway login
```

### 3. Conectar Repositorio
1. Ve a [railway.app](https://railway.app)
2. Click en "New Project"
3. Selecciona "Deploy from GitHub repo"
4. Conecta tu repositorio `Acees_Group`

### 4. Configurar Variables de Entorno
En el dashboard de Railway, agrega estas variables:

```bash
NODE_ENV=production
MONGODB_URI=tu_mongodb_atlas_uri_aqui
PORT=3000
HOST=0.0.0.0
```

### 5. Configurar Build
Railway detectará automáticamente tu `railway.toml` y:
- Ejecutará `npm install` en la carpeta `backend`
- Iniciará con `npm start`

### 6. Obtener URL del Servicio
1. Una vez desplegado, Railway te dará una URL como:
   `https://acees-group-backend-production.up.railway.app`

2. Actualiza `lib/config/api_config.dart` con esta URL

### 7. Variables de Entorno Requeridas

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `MONGODB_URI` | Conexión a MongoDB Atlas | `mongodb+srv://...` |
| `NODE_ENV` | Entorno de ejecución | `production` |
| `PORT` | Puerto (Railway lo asigna automáticamente) | `3000` |
| `HOST` | Host para bind | `0.0.0.0` |

### 8. Verificar Despliegue

Una vez desplegado, verifica que funciona:

```bash
# Probar endpoint de salud
curl https://tu-app.up.railway.app/api/health

# Respuesta esperada:
{
  "status": "OK",
  "message": "Server is running",
  "timestamp": "2025-10-02T...",
  "database": "connected"
}
```

### 9. Logs y Monitoreo

Para ver logs en tiempo real:
```bash
railway logs --follow
```

O en el dashboard web de Railway.

### 🔧 Configuración de Archivos

#### railway.toml
```toml
[build]
builder = "NIXPACKS"
watchPatterns = ["backend/**"]

[deploy]
startCommand = "cd backend && npm start"
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 10
```

#### package.json (backend)
```json
{
  "scripts": {
    "start": "node index.js",
    "railway:start": "node index.js"
  },
  "engines": {
    "node": ">=18.0.0",
    "npm": ">=8.0.0"
  }
}
```

### 🚀 Comandos Útiles

```bash
# Deploy manual (con CLI)
railway up

# Ver variables de entorno
railway variables

# Conectar a la base de datos (si usas Railway DB)
railway connect

# Ver servicios
railway status
```

### 🔒 Seguridad

1. **Variables de entorno**: Nunca commitear archivos `.env`
2. **CORS**: Configurado para permitir tu dominio
3. **MongoDB**: Usar MongoDB Atlas con IP whitelisting
4. **HTTPS**: Railway provee HTTPS automáticamente

### 🐛 Troubleshooting

#### Error de conexión a MongoDB
```bash
# Verificar variables de entorno
railway variables

# Revisar logs
railway logs --tail 100
```

#### Error de CORS
- Verificar que el origen esté en `corsOptions`
- Revisar headers permitidos

#### Error de puerto
- Railway asigna el puerto automáticamente
- Asegúrate de usar `process.env.PORT`

### 📱 Actualizar App Flutter

Después del despliegue, actualiza:

```dart
// lib/config/api_config.dart
static const String _baseUrlProd = 'https://tu-nueva-url.up.railway.app';
```

### 🔄 CI/CD Automático

Railway automáticamente redespliega cuando haces push a la rama principal:

1. Push a GitHub → Railway detecta cambios → Autodeploy
2. Ver progreso en el dashboard de Railway
3. Verificar con `/api/health`

---

¿Necesitas ayuda con algún paso específico? ¡Pregunta! 🚀