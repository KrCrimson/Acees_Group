import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/matriculation_model.dart';
import '../config/api_config.dart';

class MatriculationService {
  static final MatriculationService _instance = MatriculationService._internal();
  factory MatriculationService() => _instance;
  MatriculationService._internal();

  // Headers por defecto
  Map<String, String> get _headers => {'Content-Type': 'application/json'};

  // Verificar vigencia de matrícula por código universitario
  Future<MatriculationModel> verificarVigenciaMatricula(String codigoUniversitario) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/matriculas/verificar/$codigoUniversitario'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return MatriculationModel.fromJson(data);
      } else if (response.statusCode == 404) {
        throw Exception('No se encontró matrícula para el estudiante');
      } else {
        throw Exception('Error al verificar matrícula: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Verificar vigencia de matrícula por DNI
  Future<MatriculationModel> verificarVigenciaMatriculaByDni(String dni) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/matriculas/verificar/dni/$dni'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return MatriculationModel.fromJson(data);
      } else if (response.statusCode == 404) {
        throw Exception('No se encontró matrícula para el estudiante');
      } else {
        throw Exception('Error al verificar matrícula: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener historial de matrículas del estudiante
  Future<List<MatriculationModel>> getHistorialMatriculas(String codigoUniversitario) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/matriculas/historial/$codigoUniversitario'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => MatriculationModel.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener historial: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener matrículas por vencer
  Future<List<MatriculationModel>> getMatriculasPorVencer({int dias = 30}) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/matriculas/por-vencer?dias=$dias'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => MatriculationModel.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener matrículas por vencer: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener matrículas vencidas
  Future<List<MatriculationModel>> getMatriculasVencidas() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/matriculas/vencidas'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => MatriculationModel.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener matrículas vencidas: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener matrículas con problemas de pago
  Future<List<MatriculationModel>> getMatriculasPendientePago() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/matriculas/pendiente-pago'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => MatriculationModel.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener matrículas pendientes: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener estadísticas de matrículas
  Future<Map<String, dynamic>> getEstadisticasMatriculas() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/matriculas/estadisticas'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Error al obtener estadísticas: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener matrículas por ciclo académico
  Future<List<MatriculationModel>> getMatriculasByCiclo(String cicloAcademico) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/matriculas/ciclo/$cicloAcademico'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => MatriculationModel.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener matrículas por ciclo: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener matrículas por facultad
  Future<List<MatriculationModel>> getMatriculasByFacultad(String siglasFacultad) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/matriculas/facultad/$siglasFacultad'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => MatriculationModel.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener matrículas por facultad: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Buscar matrículas por criterios
  Future<List<MatriculationModel>> buscarMatriculas({
    String? codigoUniversitario,
    String? dni,
    String? nombre,
    String? cicloAcademico,
    String? estadoMatricula,
    String? siglasFacultad,
  }) async {
    try {
      String url = '${ApiConfig.baseUrl}/matriculas/buscar?';
      List<String> params = [];

      if (codigoUniversitario != null) params.add('codigo=$codigoUniversitario');
      if (dni != null) params.add('dni=$dni');
      if (nombre != null) params.add('nombre=${Uri.encodeComponent(nombre)}');
      if (cicloAcademico != null) params.add('ciclo=$cicloAcademico');
      if (estadoMatricula != null) params.add('estado=$estadoMatricula');
      if (siglasFacultad != null) params.add('facultad=$siglasFacultad');

      url += params.join('&');

      final response = await http.get(Uri.parse(url), headers: _headers);

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => MatriculationModel.fromJson(json)).toList();
      } else {
        throw Exception('Error al buscar matrículas: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener resumen de matrícula del estudiante
  Future<Map<String, dynamic>> getResumenMatricula(String codigoUniversitario) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/matriculas/resumen/$codigoUniversitario'),
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

  // Validar acceso basado en matrícula
  Future<Map<String, dynamic>> validarAccesoMatricula(String codigoUniversitario) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/matriculas/validar-acceso/$codigoUniversitario'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Error al validar acceso: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener alertas de matrícula
  Future<List<Map<String, dynamic>>> getAlertasMatricula() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/matriculas/alertas'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Error al obtener alertas: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener ciclos académicos disponibles
  Future<List<String>> getCiclosAcademicos() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/matriculas/ciclos'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.cast<String>();
      } else {
        throw Exception('Error al obtener ciclos: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener años académicos disponibles
  Future<List<String>> getAniosAcademicos() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/matriculas/anios'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.cast<String>();
      } else {
        throw Exception('Error al obtener años: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }
}
