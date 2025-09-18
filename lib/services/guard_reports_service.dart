import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/guard_report_model.dart';
import '../models/asistencia_model.dart';
import '../config/api_config.dart';

class GuardReportsService {
  static final GuardReportsService _instance = GuardReportsService._internal();
  factory GuardReportsService() => _instance;
  GuardReportsService._internal();

  // Headers por defecto
  Map<String, String> get _headers => {'Content-Type': 'application/json'};

  // Obtener reporte de actividad de guardias por rango de fechas
  Future<GuardActivitySummaryModel> getGuardActivitySummary(
    DateTime fechaInicio,
    DateTime fechaFin,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/reportes/guardias/resumen?'
            'fecha_inicio=${fechaInicio.toIso8601String()}&'
            'fecha_fin=${fechaFin.toIso8601String()}'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return GuardActivitySummaryModel.fromMap(data);
      } else {
        throw Exception('Error al obtener resumen de guardias: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener ranking de guardias por actividad
  Future<List<GuardReportModel>> getGuardRanking(
    DateTime fechaInicio,
    DateTime fechaFin, {
    int limit = 20,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/reportes/guardias/ranking?'
            'fecha_inicio=${fechaInicio.toIso8601String()}&'
            'fecha_fin=${fechaFin.toIso8601String()}&'
            'limit=$limit'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => GuardReportModel.fromMap(json)).toList();
      } else {
        throw Exception('Error al obtener ranking de guardias: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener actividad de guardias por día de la semana
  Future<Map<int, int>> getGuardActivityByWeekday(
    DateTime fechaInicio,
    DateTime fechaFin,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/reportes/guardias/actividad-semanal?'
            'fecha_inicio=${fechaInicio.toIso8601String()}&'
            'fecha_fin=${fechaFin.toIso8601String()}'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Map<int, int>.from(data);
      } else {
        throw Exception('Error al obtener actividad semanal: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener reporte detallado de un guardia específico
  Future<GuardReportModel> getGuardDetailedReport(
    String guardiaId,
    DateTime fechaInicio,
    DateTime fechaFin,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/reportes/guardias/$guardiaId?'
            'fecha_inicio=${fechaInicio.toIso8601String()}&'
            'fecha_fin=${fechaFin.toIso8601String()}'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return GuardReportModel.fromMap(data);
      } else {
        throw Exception('Error al obtener reporte del guardia: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener asistencias con autorización manual por guardia
  Future<List<AsistenciaModel>> getGuardManualAuthorizations(
    String guardiaId,
    DateTime fechaInicio,
    DateTime fechaFin,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/reportes/guardias/$guardiaId/autorizaciones?'
            'fecha_inicio=${fechaInicio.toIso8601String()}&'
            'fecha_fin=${fechaFin.toIso8601String()}'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => AsistenciaModel.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener autorizaciones: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener estadísticas de puertas más utilizadas
  Future<Map<String, int>> getTopGates(
    DateTime fechaInicio,
    DateTime fechaFin, {
    int limit = 10,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/reportes/guardias/puertas?'
            'fecha_inicio=${fechaInicio.toIso8601String()}&'
            'fecha_fin=${fechaFin.toIso8601String()}&'
            'limit=$limit'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Map<String, int>.from(data);
      } else {
        throw Exception('Error al obtener estadísticas de puertas: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener estadísticas de facultades más atendidas
  Future<Map<String, int>> getTopFaculties(
    DateTime fechaInicio,
    DateTime fechaFin, {
    int limit = 10,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/reportes/guardias/facultades?'
            'fecha_inicio=${fechaInicio.toIso8601String()}&'
            'fecha_fin=${fechaFin.toIso8601String()}&'
            'limit=$limit'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Map<String, int>.from(data);
      } else {
        throw Exception('Error al obtener estadísticas de facultades: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Exportar reporte de guardias a CSV
  Future<String> exportGuardReportToCSV(
    DateTime fechaInicio,
    DateTime fechaFin,
    String guardiaId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/reportes/guardias/export/csv?'
            'fecha_inicio=${fechaInicio.toIso8601String()}&'
            'fecha_fin=${fechaFin.toIso8601String()}&'
            'guardia_id=$guardiaId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return response.body;
      } else {
        throw Exception('Error al exportar reporte: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Generar reporte PDF de guardias
  Future<List<int>> generateGuardReportPDF(
    DateTime fechaInicio,
    DateTime fechaFin,
    String guardiaId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/reportes/guardias/export/pdf?'
            'fecha_inicio=${fechaInicio.toIso8601String()}&'
            'fecha_fin=${fechaFin.toIso8601String()}&'
            'guardia_id=$guardiaId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('Error al generar PDF: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }
}
