class ApiConfig {
  // Para desarrollo local
  static const String _baseUrlDev = 'http://192.168.1.51:3000';

  // Para producción - URL de Railway
  static const String _baseUrlProd =
      'https://aceesgroup-production.up.railway.app';

  // Cambiar a true cuando compiles la APK para producción
  static const bool _isProduction = true;

  static String get baseUrl => _isProduction ? _baseUrlProd : _baseUrlDev;

  // URLs de endpoints
  static String get loginUrl => '$baseUrl/login';
  static String get usuariosUrl => '$baseUrl/usuarios';
  static String get asistenciasUrl => '$baseUrl/asistencias';
  static String get facultadesUrl => '$baseUrl/facultades';
  static String get escuelasUrl => '$baseUrl/escuelas';
  static String get externosUrl => '$baseUrl/externos';
  static String get alumnosUrl => '$baseUrl/alumnos';
  static String get visitasUrl => '$baseUrl/visitas';
}
