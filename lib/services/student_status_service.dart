import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/student_status_model.dart';
import '../models/alumno_model.dart';
import '../models/asistencia_model.dart';
import '../models/presencia_model.dart';
import '../models/decision_manual_model.dart';
import '../config/api_config.dart';

class StudentStatusService {
  static final StudentStatusService _instance = StudentStatusService._internal();
  factory StudentStatusService() => _instance;
  StudentStatusService._internal();

  // Headers por defecto
  Map<String, String> get _headers => {'Content-Type': 'application/json'};

  // Consultar estado completo del estudiante
  Future<StudentStatusModel> getStudentStatus(String codigoUniversitario) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/estudiantes/$codigoUniversitario/estado'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return StudentStatusModel.fromMap(data);
      } else if (response.statusCode == 404) {
        throw Exception('Estudiante no encontrado');
      } else {
        throw Exception('Error al consultar estado: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Consultar estado del estudiante por DNI
  Future<StudentStatusModel> getStudentStatusByDni(String dni) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/estudiantes/dni/$dni/estado'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return StudentStatusModel.fromMap(data);
      } else if (response.statusCode == 404) {
        throw Exception('Estudiante no encontrado');
      } else {
        throw Exception('Error al consultar estado: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener historial de asistencias del estudiante
  Future<List<AsistenciaModel>> getStudentAttendanceHistory(
    String codigoUniversitario, {
    DateTime? fechaInicio,
    DateTime? fechaFin,
    int limit = 50,
  }) async {
    try {
      String url = '${ApiConfig.baseUrl}/estudiantes/$codigoUniversitario/asistencias?limit=$limit';
      
      if (fechaInicio != null) {
        url += '&fecha_inicio=${fechaInicio.toIso8601String()}';
      }
      if (fechaFin != null) {
        url += '&fecha_fin=${fechaFin.toIso8601String()}';
      }

      final response = await http.get(Uri.parse(url), headers: _headers);

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => AsistenciaModel.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener historial: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener presencia actual del estudiante
  Future<PresenciaModel?> getStudentCurrentPresence(String codigoUniversitario) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/estudiantes/$codigoUniversitario/presencia'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null) {
          return PresenciaModel.fromJson(data);
        }
        return null;
      } else if (response.statusCode == 404) {
        return null; // No hay presencia actual
      } else {
        throw Exception('Error al obtener presencia: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener decisiones manuales del estudiante
  Future<List<DecisionManualModel>> getStudentManualDecisions(
    String codigoUniversitario, {
    int limit = 20,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/estudiantes/$codigoUniversitario/decisiones?limit=$limit'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => DecisionManualModel.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener decisiones: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener estadísticas del estudiante
  Future<Map<String, dynamic>> getStudentStatistics(
    String codigoUniversitario, {
    DateTime? fechaInicio,
    DateTime? fechaFin,
  }) async {
    try {
      String url = '${ApiConfig.baseUrl}/estudiantes/$codigoUniversitario/estadisticas';
      
      if (fechaInicio != null) {
        url += '?fecha_inicio=${fechaInicio.toIso8601String()}';
      }
      if (fechaFin != null) {
        url += fechaInicio != null ? '&' : '?';
        url += 'fecha_fin=${fechaFin.toIso8601String()}';
      }

      final response = await http.get(Uri.parse(url), headers: _headers);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Error al obtener estadísticas: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener alertas del estudiante
  Future<Map<String, dynamic>> getStudentAlerts(String codigoUniversitario) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/estudiantes/$codigoUniversitario/alertas'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Error al obtener alertas: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Buscar estudiantes por nombre o código
  Future<List<AlumnoModel>> searchStudents(String query) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/estudiantes/buscar?q=${Uri.encodeComponent(query)}'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => AlumnoModel.fromJson(json)).toList();
      } else {
        throw Exception('Error al buscar estudiantes: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener estudiantes recientes (últimos consultados)
  Future<List<AlumnoModel>> getRecentStudents() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/estudiantes/recientes'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => AlumnoModel.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener estudiantes recientes: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener estudiantes con alertas
  Future<List<AlumnoModel>> getStudentsWithAlerts() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/estudiantes/alertas'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => AlumnoModel.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener estudiantes con alertas: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener resumen ejecutivo del estudiante
  Future<Map<String, dynamic>> getStudentExecutiveSummary(String codigoUniversitario) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/estudiantes/$codigoUniversitario/resumen'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Error al obtener resumen: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener patrones de asistencia del estudiante
  Future<Map<String, dynamic>> getStudentAttendancePatterns(String codigoUniversitario) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/estudiantes/$codigoUniversitario/patrones'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Error al obtener patrones: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener reporte detallado del estudiante
  Future<Map<String, dynamic>> getStudentDetailedReport(
    String codigoUniversitario, {
    DateTime? fechaInicio,
    DateTime? fechaFin,
  }) async {
    try {
      String url = '${ApiConfig.baseUrl}/estudiantes/$codigoUniversitario/reporte';
      
      if (fechaInicio != null) {
        url += '?fecha_inicio=${fechaInicio.toIso8601String()}';
      }
      if (fechaFin != null) {
        url += fechaInicio != null ? '&' : '?';
        url += 'fecha_fin=${fechaFin.toIso8601String()}';
      }

      final response = await http.get(Uri.parse(url), headers: _headers);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Error al obtener reporte: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }
}
