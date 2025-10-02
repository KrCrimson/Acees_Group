# 📱 Acees Group - Sistema de Control de Acceso NFC

Sistema completo de control de acceso con tecnología NFC desarrollado en Flutter con arquitectura MVVM.

## 🏗️ Arquitectura del Proyecto

```
📁 Acees_Group/
├── 📱 lib/                     # App Flutter (Frontend)
├── 🌐 backend/                 # API REST (Node.js + Express)
├── ⚙️ railway.toml            # Configuración Railway
├── 🚀 start-backend.sh        # Script de desarrollo
└── 📚 RAILWAY_DEPLOY.md       # Guía de despliegue
```

## 🚀 Despliegue

### 🌐 Producción (Railway)
- **URL**: https://acees-group-backend-production.up.railway.app
- **Documentación**: Ver [RAILWAY_DEPLOY.md](RAILWAY_DEPLOY.md)

### 💻 Desarrollo Local
```bash
# Clonar repositorio
git clone https://github.com/KrCrimson/Acees_Group.git
cd Acees_Group

# Iniciar backend
./start-backend.sh

# Iniciar app Flutter (en otra terminal)
flutter run
```

## 📋 Características

- ✅ **Autenticación segura** con JWT
- ✅ **Lectura NFC** con manejo de múltiples tags
- ✅ **Modo offline** con sincronización automática
- ✅ **Dashboard administrativo** completo
- ✅ **Gestión de asistencias** en tiempo real
- ✅ **Reportes y estadísticas** avanzadas
- ✅ **Arquitectura MVVM** escalable

## 🛠️ Tecnologías

### Frontend (Flutter)
- **Patrón**: MVVM con Provider
- **Base de datos local**: SQLite
- **NFC**: flutter_nfc_kit
- **HTTP**: http package
- **Estado**: Provider + ChangeNotifier

### Backend (Node.js)
- **Framework**: Express.js
- **Base de datos**: MongoDB Atlas
- **Autenticación**: bcrypt
- **Despliegue**: Railway
- **CORS**: Configurado para móviles

## 📡 API Endpoints

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| `GET` | `/api/health` | Health check |
| `POST` | `/login` | Autenticación |
| `GET` | `/alumnos/:codigo` | Buscar alumno |
| `POST` | `/asistencias` | Registrar asistencia |
| `GET` | `/asistencias` | Listar asistencias |

## 🔧 Configuración

### Variables de Entorno (Backend)
```bash
MONGODB_URI=mongodb+srv://...
NODE_ENV=production
PORT=3000
HOST=0.0.0.0
```

### Configuración Flutter
```dart
// lib/config/api_config.dart
static const String _baseUrlProd = 'https://tu-app.up.railway.app';
static const bool _isProduction = true;
```

## 🚀 Inicio Rápido

1. **Clonar** el repositorio
2. **Backend**: `./start-backend.sh`
3. **Flutter**: `flutter run`
4. **Producción**: Ver [RAILWAY_DEPLOY.md](RAILWAY_DEPLOY.md)

---

**Desarrollado por**: Acees Group  
**Tecnología**: Flutter + Node.js + MongoDB  
**Despliegue**: Railway Platform
