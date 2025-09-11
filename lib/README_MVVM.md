# Arquitectura MVVM - Control de Acceso NFC

## Sprint 1 Completado ✅

### Resumen de la Implementación MVVM

La aplicación ha sido completamente reestructurada siguiendo el patrón de arquitectura **MVVM (Model-View-ViewModel)** para asegurar una separación clara de responsabilidades y facilitar el mantenimiento y escalabilidad.

## Estructura del Proyecto

```
lib/
├── main.dart                    # Punto de entrada con Provider
├── config/
│   └── api_config.dart         # Configuración de URLs de API
├── models/                     # Modelos de datos (M)
│   ├── alumno_model.dart       # Modelo de estudiante
│   ├── usuario_model.dart      # Modelo de usuario/administrador
│   ├── asistencia_model.dart   # Modelo de registros de asistencia
│   ├── facultad_escuela_model.dart # Modelo de facultad/escuela
│   └── visita_externo_model.dart   # Modelo de visitantes externos
├── services/                   # Capa de servicios
│   ├── api_service.dart        # Servicio de comunicación con API
│   └── nfc_service.dart        # Servicio de integración NFC
├── viewmodels/                 # ViewModels (VM)
│   ├── auth_viewmodel.dart     # Gestión de autenticación
│   ├── nfc_viewmodel.dart      # Gestión de lecturas NFC
│   ├── admin_viewmodel.dart    # Gestión de funciones administrativas
│   └── reports_viewmodel.dart  # Gestión de reportes y estadísticas
├── views/                      # Vistas de la aplicación (V)
│   ├── login_view.dart         # Pantalla de login
│   ├── admin/
│   │   ├── admin_view.dart     # Vista principal de administrador
│   │   ├── reports_view.dart   # Vista de reportes
│   │   └── user_management_view.dart # Gestión de usuarios
│   └── user/
│       └── user_nfc_view.dart  # Vista de usuario con NFC
└── widgets/                    # Widgets reutilizables
    ├── custom_button.dart      # Botón personalizado
    ├── custom_text_field.dart  # Campo de texto personalizado
    └── status_widgets.dart     # Widgets de estado (success, error, loading)
```

## Funcionalidades Implementadas

### 🔐 Autenticación
- Login seguro con validación de credenciales
- Gestión de sesiones con JWT
- Roles diferenciados (Administrador/Usuario)

### 🏷️ Sistema NFC
- Lectura de tarjetas NFC
- Registro automático de asistencia
- Integración con hardware NFC del dispositivo

### 👥 Gestión de Usuarios (Admin)
- CRUD completo de estudiantes y usuarios
- Asignación de roles y permisos
- Gestión de facultades y escuelas

### 📊 Reportes y Estadísticas
- Reportes de asistencia por estudiante
- Estadísticas de acceso por fecha/hora
- Exportación de datos
- Visualización con gráficos (fl_chart)

### 🎯 Características del Sprint 1
- ✅ Eliminación completa del sistema QR
- ✅ Integración exclusiva con NFC
- ✅ Backend MongoDB Atlas completamente funcional
- ✅ 7 colecciones en base de datos con datos reales
- ✅ API REST desplegada en producción (Render.com)
- ✅ Arquitectura MVVM implementada completamente

## Tecnologías Utilizadas

### Frontend (Flutter)
- **Provider**: Gestión de estado reactivo
- **flutter_nfc_kit**: Integración con hardware NFC
- **http**: Comunicación HTTP con backend
- **fl_chart**: Visualización de datos
- **Material Design 3**: Diseño moderno y accesible

### Backend (Node.js/Express)
- **MongoDB Atlas**: Base de datos en la nube
- **JWT**: Autenticación segura
- **bcrypt**: Encriptación de contraseñas
- **Render.com**: Deploy en producción

## Base de Datos

### MongoDB Atlas - Colecciones:
1. **estudiantes** (41 registros activos)
2. **usuarios** (administradores y operadores)
3. **asistencias** (100+ registros de acceso)
4. **facultades** (datos de facultades universitarias)
5. **escuelas** (programas académicos por facultad)
6. **visitasExternas** (registro de visitantes)
7. **configuracion** (parámetros del sistema)

## URLs de Producción

- **Frontend**: Puede ejecutarse en cualquier dispositivo con Flutter
- **Backend API**: https://movilesii.onrender.com
- **Base de Datos**: MongoDB Atlas (cluster seguro)

## Ventajas de la Arquitectura MVVM

### 1. **Separación de Responsabilidades**
- **Model**: Solo manejo de datos
- **View**: Solo presentación visual
- **ViewModel**: Lógica de negocio y estado

### 2. **Testabilidad Mejorada**
- ViewModels pueden ser probados unitariamente
- Lógica de negocio independiente de la UI

### 3. **Mantenibilidad**
- Código organizado y modular
- Fácil localización y corrección de bugs

### 4. **Escalabilidad**
- Fácil agregar nuevas funcionalidades
- Reutilización de componentes

### 5. **Reactividad**
- Provider permite actualizaciones automáticas de UI
- Estado centralizado y predecible

## Próximos Sprints

El Sprint 1 está **100% completado** con:
- ✅ Sistema QR eliminado completamente
- ✅ NFC como único método de acceso
- ✅ Backend funcional con datos reales
- ✅ Arquitectura MVVM implementada
- ✅ Aplicación móvil profesional y escalable

La aplicación está lista para continuar con los siguientes sprints, construyendo sobre esta sólida base arquitectónica MVVM.
