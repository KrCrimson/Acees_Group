import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class PhotoService {
  // Cambié const por static get porque ApiConfig.baseUrl es dinámico
  static String get baseUrl => ApiConfig.baseUrl;

  /// Obtener URL de foto de alumno
  static String getAlumnoPhotoUrl(String dni) {
    return '$baseUrl/api/fotos/alumno/$dni';
  }

  /// Verificar si un alumno tiene foto
  static Future<bool> alumnoTieneFoto(String dni) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/fotos/alumno/$dni/exists'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['tiene_foto'] ?? false;
      }

      return false;
    } catch (e) {
      print('❌ Error verificando foto para DNI $dni: $e');
      return false;
    }
  }

  /// Obtener estadísticas de fotos
  static Future<Map<String, dynamic>> getEstadisticasFotos() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/fotos/stats'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }

      return {
        'total_alumnos': 0,
        'con_foto': 0,
        'sin_foto': 0,
        'porcentaje_con_foto': 0,
      };
    } catch (e) {
      print('❌ Error obteniendo estadísticas de fotos: $e');
      return {
        'total_alumnos': 0,
        'con_foto': 0,
        'sin_foto': 0,
        'porcentaje_con_foto': 0,
      };
    }
  }

  /// Obtener lista de alumnos con foto
  static Future<List<Map<String, dynamic>>> getAlumnosConFoto({
    int limit = 50,
    int skip = 0,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
            '$baseUrl/api/fotos/alumnos-con-foto?limit=$limit&skip=$skip'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['alumnos'] ?? []);
      }

      return [];
    } catch (e) {
      print('❌ Error obteniendo alumnos con foto: $e');
      return [];
    }
  }

  /// Precargar foto en cache (opcional)
  static Future<bool> preloadPhoto(String dni) async {
    try {
      final response = await http.head(
        Uri.parse(getAlumnoPhotoUrl(dni)),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error precargando foto para DNI $dni: $e');
      return false;
    }
  }

  /// Generar iniciales del nombre para fallback
  static String getInitials(String nombre) {
    if (nombre.trim().isEmpty) return '?';

    final names = nombre.trim().split(' ');
    if (names.length >= 2) {
      return '${names[0][0]}${names[1][0]}'.toUpperCase();
    } else if (names.isNotEmpty) {
      return names[0][0].toUpperCase();
    }
    return '?';
  }

  /// Generar color consistente basado en el nombre
  static int getColorForName(String nombre) {
    final colors = [
      0xFF2196F3, // Blue
      0xFF4CAF50, // Green
      0xFFFF9800, // Orange
      0xFF9C27B0, // Purple
      0xFF009688, // Teal
      0xFF3F51B5, // Indigo
      0xFFE91E63, // Pink
      0xFF795548, // Brown
    ];

    final index = nombre.hashCode.abs() % colors.length;
    return colors[index];
  }
}
