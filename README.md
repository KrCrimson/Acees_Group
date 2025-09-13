# Sistema de Control de Acceso - ACEES Group

Una aplicación móvil desarrollada en Flutter para el control de acceso y gestión de estudiantes en instituciones educativas. El sistema integra autenticación Firebase, escaneo de códigos QR/códigos de barras, y un completo sistema de reportes administrativos.

## 👥 Integrantes del Proyecto

| Nombre | Código de Estudiante |
|--------|---------------------|
| Sebastián Arce Bracamonte | 2019062986 |
| Brant Antony Chata Choque | 2021072615 |

## 📋 Descripción del Proyecto

ACEES Group es un sistema integral de control de acceso que permite:

- **Autenticación de usuarios** con roles diferenciados (administrador/usuario)
- **Escaneo de códigos QR/códigos de barras** para registro de entrada y salida
- **Gestión de estudiantes** con registro completo de datos académicos
- **Sistema de reportes** con gráficos y estadísticas
- **Notificaciones y alarmas** para el control de acceso
- **Registro de visitantes externos**
- **Historial de movimientos** con filtros y búsquedas

## 🏗️ Arquitectura del Sistema

### Tecnologías Principales
- **Flutter**: Framework de desarrollo multiplataforma
- **Firebase**: Backend como servicio (Authentication, Firestore)
- **Provider**: Gestión de estado
- **Mobile Scanner**: Escaneo de códigos QR/códigos de barras

### Estructura de la Aplicación

#### Autenticación y Roles
- Sistema de login con Firebase Authentication
- Roles diferenciados: Administrador y Usuario
- Wrapper automático que redirige según el rol del usuario

#### Pantallas de Usuario (Estudiante)
- **UserScannerScreen**: Pantalla principal con escáner QR para registro de entrada/salida
- **UserHistoryScreen**: Historial personal de accesos
- **UserNotificationsScreen**: Notificaciones del sistema
- **UserAlarmDetailsScreen**: Detalles de alarmas de seguridad
- **VisitorFormScreen**: Formulario para registro de visitantes

#### Pantallas de Administrador
- **AdminView**: Panel principal de administración
- **AdminReportScreen**: Reportes generales del sistema
- **AdminReportChartScreen**: Gráficos y estadísticas
- **PendingExitScreen**: Gestión de salidas pendientes
- **ExternalVisitsReportScreen**: Reportes de visitas externas
- **AlarmDetailsScreen**: Gestión de alarmas del sistema

#### Funcionalidades Clave
- **Registro de Estudiantes**: Sistema completo de registro con facultades y escuelas
- **Control de Acceso**: Doble entrada (Principal/Cochera) con validaciones
- **Sistema TTS**: Retroalimentación por voz para confirmaciones
- **Reportes Avanzados**: Gráficos con FL Chart para visualización de datos
- **Gestión de Alarmas**: Sistema de notificaciones y seguimiento

## 🚀 Características Técnicas

### Dependencias Principales
```yaml
dependencies:
  firebase_core: ^3.1.1           # Core de Firebase
  firebase_auth: ^5.5.3           # Autenticación
  cloud_firestore: ^5.0.1         # Base de datos NoSQL
  mobile_scanner: ^3.3.0          # Escaneo QR/Códigos de barras
  provider: ^6.1.1                # Gestión de estado
  fl_chart: ^0.63.0                # Gráficos y estadísticas
  flutter_tts: ^3.8.5             # Text-to-Speech
  fluttertoast: ^8.2.2             # Notificaciones toast
  google_fonts: ^6.1.0            # Fuentes personalizadas
  intl: ^0.18.1                   # Internacionalización
```

### Plataformas Soportadas
- ✅ Android
- ✅ iOS
- ✅ Web
- ✅ Windows
- ✅ macOS
- ✅ Linux

## 📱 Funcionalidades del Sistema

### Para Usuarios (Estudiantes)
1. **Escaneo de QR**: Registro rápido de entrada y salida
2. **Historial Personal**: Consulta de movimientos propios
3. **Registro de Visitantes**: Formulario para acompañantes
4. **Notificaciones**: Alertas del sistema en tiempo real

### Para Administradores
1. **Panel de Control**: Vista general del sistema
2. **Reportes Detallados**: Estadísticas de acceso por períodos
3. **Gráficos Interactivos**: Visualización de datos con FL Chart
4. **Gestión de Alarmas**: Control de eventos de seguridad
5. **Reportes de Visitantes**: Seguimiento de accesos externos

## 🛠️ Instalación y Configuración

### Requisitos Previos
- Flutter SDK (v3.7.2 o superior)
- Firebase CLI
- Android Studio / VS Code
- Git

### Pasos de Instalación

1. **Clonar el repositorio**
```bash
git clone https://github.com/KrCrimson/Acees_Group.git
cd Acees_Group
```

2. **Instalar dependencias**
```bash
flutter pub get
```

3. **Configurar Firebase**
- Configurar proyecto en Firebase Console
- Añadir archivos de configuración (`google-services.json` para Android, `GoogleService-Info.plist` para iOS)
- Habilitar Authentication y Firestore

4. **Ejecutar la aplicación**
```bash
flutter run
```

## 🏢 Base de Datos

### Colecciones en Firestore
- **usuarios**: Datos de usuarios con roles y permisos
- **estudiantes**: Información académica completa
- **facultades**: Catálogo de facultades
- **escuelas**: Catálogo de escuelas profesionales
- **accesos**: Registro de entradas y salidas
- **visitantes**: Registro de visitantes externos
- **alarmas**: Sistema de notificaciones y alertas

## 🎯 Casos de Uso

1. **Registro de Acceso**: Estudiante escanea su código QR para registrar entrada/salida
2. **Consulta de Reportes**: Administrador genera reportes de acceso por períodos
3. **Registro de Visitantes**: Usuario registra visitante externo con datos completos
4. **Gestión de Alarmas**: Sistema detecta y notifica eventos de seguridad
5. **Análisis Estadístico**: Visualización de patrones de acceso con gráficos


## � Calidad de Código con SonarQube

Este proyecto incluye configuración completa para análisis de calidad de código usando SonarQube/SonarCloud.

### 🔧 Configuración de SonarQube

#### Archivos de Configuración
- `sonar-project.properties`: Configuración principal de SonarQube
- `.github/workflows/`: Workflows de CI/CD con SonarCloud
- `scripts/`: Scripts para análisis local

#### Análisis Local

**Usando PowerShell (Windows):**
```powershell
# Cargar scripts
. .\scripts\quality_analysis.ps1

# Análisis completo
Full-Analysis

# Solo tests con cobertura
Test-Coverage

# Preparar para SonarQube
Prepare-Sonar
```

**Comandos manuales:**
```bash
# Análisis de código
flutter analyze --write=dart_analysis_report.json --format=json

# Tests con cobertura
flutter test --coverage

# SonarQube Scanner (requiere instalación)
sonar-scanner
```

#### SonarCloud (Recomendado)

1. **Configurar en SonarCloud:**
   - Crear proyecto en [sonarcloud.io](https://sonarcloud.io)
   - Obtener token de organización
   - Configurar `sonar.organization` en `sonar-project.properties`

2. **Configurar GitHub Secrets:**
   ```
   SONAR_TOKEN: [tu-token-de-sonarcloud]
   ```

3. **Análisis Automático:**
   - Los workflows se ejecutan automáticamente en push/PR
   - Resultados disponibles en SonarCloud dashboard

#### Métricas Analizadas
- **Calidad de Código**: Bugs, vulnerabilidades, code smells
- **Cobertura de Tests**: Porcentaje de código cubierto
- **Duplicación**: Código duplicado
- **Mantenibilidad**: Deuda técnica y complejidad
- **Confiabilidad**: Bugs y problemas potenciales
- **Seguridad**: Vulnerabilidades y hotspots

#### Exclusiones Configuradas
- Archivos generados (*.g.dart, *.freezed.dart)
- Configuraciones de plataforma (android/, ios/, etc.)
- Archivos de build y generated/

### 📈 Badges de Calidad

Una vez configurado SonarCloud, puedes agregar badges al README:

```markdown
[![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=acees-group&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=acees-group)
[![Coverage](https://sonarcloud.io/api/project_badges/measure?project=acees-group&metric=coverage)](https://sonarcloud.io/summary/new_code?id=acees-group)
[![Bugs](https://sonarcloud.io/api/project_badges/measure?project=acees-group&metric=bugs)](https://sonarcloud.io/summary/new_code?id=acees-group)
```

## �📝 Notas de Desarrollo

- Utiliza arquitectura Provider para gestión de estado
- Implementa principios de Material Design
- Código documentado y estructurado modularmente
- Preparado para despliegue en múltiples plataformas
- Sistema escalable con Firebase como backend
- **Análisis continuo de calidad** con SonarQube/SonarCloud

## 🔒 Seguridad

- Autenticación robusta con Firebase Auth
- Validación de roles en tiempo real
- Encriptación de datos sensibles
- Control de acceso por niveles de usuario

## 📄 Licencia

Este proyecto está desarrollado para uso académico y educativo.

---

*Desarrollado con ❤️ en Flutter por el equipo ACEES Group*
