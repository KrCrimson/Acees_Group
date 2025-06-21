# Sistema de Control de Accesos Universitarios

## ¿Por qué lo hacemos?
El control de accesos en universidades es fundamental para la seguridad, la gestión de aforos y el registro de asistencia. Este sistema digitaliza y automatiza el proceso, permitiendo un monitoreo en tiempo real, reportes avanzados y una experiencia moderna para alumnos, guardias y administradores.

## ¿Cómo funciona?
- **Usuarios:** Se autentican mediante correo y contraseña usando Firebase Auth.
- **Registro de accesos:** Los guardias escanean el QR del alumno para registrar entrada/salida. Los datos se almacenan en Firestore.
- **Historial y reportes:** Alumnos y admins pueden consultar el historial de asistencias, aplicar filtros avanzados (DNI, nombre, facultad, escuela, fechas) y exportar a CSV.
- **Roles:**
  - **Guardia:** Registra accesos y ve pendientes de salida.
  - **Admin:** Visualiza reportes, gráficos de rendimiento y flujo de accesos.
- **Filtros avanzados:** Permiten búsquedas por facultad, escuela (dependiente de la facultad), nombre, DNI y rango de fechas.

## ¿Qué usamos?
- **Flutter:** Framework principal para la app multiplataforma.
- **Firebase:**
  - **Auth:** Autenticación de usuarios.
  - **Firestore:** Base de datos en tiempo real.
  - **Cloud Functions:** (opcional) Para lógica de backend y notificaciones.
- **Otras librerías:**
  - `provider`, `mobile_scanner`, `intl`, `share_plus`, `fl_chart`, `flutter_tts`, `expandable`, `google_fonts`, `flutter_svg`, `carousel_slider`, `shimmer`, `animations`, `cupertino_icons`.

## Árbol del proyecto (resumido)
```
Acees_Group-Arce/
├── android/
├── ios/
├── linux/
├── macos/
├── web/
├── windows/
├── lib/
│   ├── main.dart
│   ├── auth_service.dart
│   ├── login_screen.dart
│   ├── registro_alumno.dart
│   ├── firebase_options.dart
│   └── screens/
│       ├── admin/
│       │   ├── admin_report_chart_screen.dart
│       │   ├── admin_report_screen.dart
│       │   ├── admin_view.dart
│       │   ├── add_edit_user_dialog.dart
│       │   ├── alarm_details_screen.dart
│       │   ├── external_visits_report_screen.dart
│       │   ├── pending_exit_screen.dart
│       │   └── user_card.dart
│       └── user/
│           ├── user_history_screen.dart
│           ├── user_scanner_screen.dart
│           ├── user_alarm_details_screen.dart
│           ├── user_notifications_screen.dart
│           ├── pending_all_exit_screen.dart
│           └── visitor_form_screen.dart
├── pubspec.yaml
├── firebase.json
└── README.md
```

## Dependencias principales
```
flutter, firebase_core, firebase_auth, cloud_firestore, provider, mobile_scanner, fluttertoast, intl, share_plus, fl_chart, flutter_tts, expandable, google_fonts, flutter_svg, carousel_slider, shimmer, animations, cupertino_icons
```

## Conclusiones
- El sistema facilita el control de accesos y la gestión de asistencia en entornos universitarios.
- Los filtros avanzados y la exportación de datos permiten análisis detallados.
- La arquitectura modular y el uso de Firebase aseguran escalabilidad y mantenimiento sencillo.
- El sistema es multiplataforma (Android, iOS, Web, Windows, Linux, macOS).
- Se puede ampliar fácilmente con nuevas funcionalidades como notificaciones push, reportes personalizados o integración con otros sistemas.

---
Desarrollado con Flutter y Firebase.
