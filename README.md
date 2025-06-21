# Sistema de Control de Accesos - Flutter + Firebase

## Descripción General
Aplicación móvil para el control de accesos universitarios, con roles de usuario (alumno, guardia, admin), registro de entradas y salidas, reportes y notificaciones. Utiliza Flutter, Firebase Auth, Firestore y notificaciones push.

## Características principales
- **Autenticación:** Login seguro con Firebase Auth.
- **Registro de alumnos:** Formulario de registro y guardado en Firestore.
- **Escaneo QR:** Para registrar entradas y salidas.
- **Roles:**
  - **Alumno:** Acceso a su historial y registro de visitas.
  - **Guardia:** Escaneo y registro de accesos, visualización de pendientes de salida.
  - **Admin:** Panel de reportes, gráficos de rendimiento, gestión de usuarios y visualización de ingresos/egresos.
- **Reportes y gráficos:** Estadísticas por facultad, escuela, hora, tipo de entrada, puerta, rendimiento de guardias y flujo de ingresos/egresos.
- **Notificaciones:** (En proceso de integración) Notificaciones push para alertar sobre pendientes de salida y eventos importantes.

## Estructura del proyecto
- `lib/`
  - `main.dart`: Inicialización, rutas y lógica de autenticación.
  - `auth_service.dart`: Lógica de login, registro y gestión de usuarios.
  - `login_screen.dart`, `registro_alumno.dart`: Pantallas de acceso y registro.
  - `screens/`
    - `user/`: Pantallas de usuario/alumno (escaneo, historial, pendientes, etc).
    - `admin/`: Pantallas de admin (reportes, gráficos, gestión de usuarios).
    - `services/`: Servicios auxiliares (alarmas, etc).

## Instalación y configuración
1. Clona el repositorio y ejecuta `flutter pub get`.
2. Agrega tu archivo `google-services.json` en `android/app/` y/o `GoogleService-Info.plist` en `ios/Runner/`.
3. Configura Firebase Cloud Messaging en la consola de Firebase.
4. Ejecuta la app con `flutter run`.

## Dependencias principales
```yaml
firebase_core: ^3.1.1
firebase_auth: ^5.5.3
cloud_firestore: ^5.0.1
firebase_messaging: ^15.0.2
provider: ^6.1.1
mobile_scanner: ^3.3.0
fluttertoast: ^8.2.2
intl: ^0.18.1
share_plus: ^7.0.0
fl_chart: ^0.63.0
flutter_tts: ^3.8.5
expandable: ^5.0.1
google_fonts: ^6.1.0
flutter_svg: ^2.0.9
carousel_slider: ^4.2.1
shimmer: ^3.0.0
animations: ^2.0.8
cupertino_icons: ^1.0.2
```

## Notificaciones push (en proceso)
- Se está integrando `firebase_messaging` para notificaciones push.
- Asegúrate de tener permisos y configuración en Firebase Console.
- El token FCM se obtiene al iniciar la app y se usará para enviar alertas a usuarios con pendientes de salida.

## Reportes y gráficos
- Gráficos por facultad, escuela, hora, tipo de entrada, puerta.
- **Nuevos:**
  - Gráficos de rendimiento de guardias (quién registra más alumnos).
  - Gráficos de ingresos y egresos por día/semana/usuario.

## Contribuciones
Pull requests y sugerencias son bienvenidas.

## Licencia
MIT
