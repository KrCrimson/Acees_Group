import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/alumno_model.dart';
import '../models/usuario_model.dart';
import '../models/asistencia_model.dart';
import '../models/facultad_escuela_model.dart';
import '../models/visita_externo_model.dart';
import '../models/decision_manual_model.dart';
import '../models/presencia_model.dart';
import '../config/api_config.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Headers por defecto
  Map<String, String> get _headers => {'Content-Type': 'application/json'};

  // ==================== ALUMNOS ====================

  Future<List<AlumnoModel>> getAlumnos() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.alumnosUrl),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => AlumnoModel.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener alumnos: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<AlumnoModel> getAlumnoByCodigo(String codigo) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.alumnosUrl}/$codigo'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return AlumnoModel.fromJson(json.decode(response.body));
      } else if (response.statusCode == 404) {
        throw Exception('Alumno no encontrado');
      } else if (response.statusCode == 403) {
        final data = json.decode(response.body);
        throw Exception(data['error'] ?? 'Alumno inactivo');
      } else {
        throw Exception('Error al buscar alumno: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // ==================== USUARIOS ====================

  Future<UsuarioModel> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.loginUrl),
        headers: _headers,
        body: json.encode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        return UsuarioModel.fromJson(json.decode(response.body));
      } else if (response.statusCode == 401) {
        throw Exception('Credenciales incorrectas');
      } else {
        throw Exception('Error en el servidor');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<List<UsuarioModel>> getUsuarios() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.usuariosUrl),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => UsuarioModel.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener usuarios: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<UsuarioModel> createUsuario(UsuarioModel usuario) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.usuariosUrl),
        headers: _headers,
        body: json.encode(usuario.toJson()),
      );

      if (response.statusCode == 201) {
        return UsuarioModel.fromJson(json.decode(response.body));
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Error al crear usuario');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<void> changePassword(String userId, String newPassword) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.usuariosUrl}/$userId/password'),
        headers: _headers,
        body: json.encode({'password': newPassword}),
      );

      if (response.statusCode != 200) {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Error al cambiar contraseña');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Actualizar estado de usuario (activar/desactivar)
  Future<void> updateUserStatus(String userId, String newStatus) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.usuariosUrl}/$userId'),
        headers: _headers,
        body: json.encode({'estado': newStatus}),
      );

      if (response.statusCode != 200) {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Error al actualizar estado');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // ==================== ASISTENCIAS ====================

  Future<List<AsistenciaModel>> getAsistencias() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.asistenciasUrl),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => AsistenciaModel.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener asistencias: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<AsistenciaModel> registrarAsistencia(
    AsistenciaModel asistencia,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.asistenciasUrl),
        headers: _headers,
        body: json.encode(asistencia.toJson()),
      );

      if (response.statusCode == 201) {
        return AsistenciaModel.fromJson(json.decode(response.body));
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Error al registrar asistencia');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // ==================== FACULTADES Y ESCUELAS ====================

  Future<List<FacultadModel>> getFacultades() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.facultadesUrl),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => FacultadModel.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener facultades: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<List<EscuelaModel>> getEscuelas({String? siglasFacultad}) async {
    try {
      String url = ApiConfig.escuelasUrl;
      if (siglasFacultad != null) {
        url += '?siglas_facultad=$siglasFacultad';
      }

      final response = await http.get(Uri.parse(url), headers: _headers);

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => EscuelaModel.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener escuelas: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // ==================== VISITAS Y EXTERNOS ====================

  Future<List<VisitaModel>> getVisitas() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.visitasUrl),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => VisitaModel.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener visitas: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<VisitaModel> registrarVisita(VisitaModel visita) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.visitasUrl),
        headers: _headers,
        body: json.encode(visita.toJson()),
      );

      if (response.statusCode == 201) {
        return VisitaModel.fromJson(json.decode(response.body));
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Error al registrar visita');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<List<ExternoModel>> getExternos() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.externosUrl),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => ExternoModel.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener externos: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // ==================== DECISIONES MANUALES ====================

  Future<void> registrarDecisionManual(DecisionManualModel decision) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/decisiones-manuales'),
        headers: _headers,
        body: json.encode(decision.toJson()),
      );

      if (response.statusCode != 201) {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Error al registrar decisión');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<List<DecisionManualModel>> getDecisionesGuardia(
    String guardiaId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/decisiones-manuales/guardia/$guardiaId',
        ),
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

  // ==================== CONTROL DE PRESENCIA ====================

  Future<List<PresenciaModel>> getPresenciaActual() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/presencia'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => PresenciaModel.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener presencia: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<void> actualizarPresencia(
    String estudianteDni,
    String tipoAcceso,
    String puntoControl,
    String guardiaId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/presencia/actualizar'),
        headers: _headers,
        body: json.encode({
          'estudiante_dni': estudianteDni,
          'tipo_acceso': tipoAcceso,
          'punto_control': puntoControl,
          'guardia_id': guardiaId,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode != 200) {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Error al actualizar presencia');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // ==================== TESTING ====================

  String getBaseUrl() {
    return ApiConfig.baseUrl;
  }

  Future<bool> testServerConnection() async {
    try {
      print('🧪 Probando conexión al servidor...');
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/test'),
        headers: _headers,
      );

      print('📨 Respuesta test: ${response.statusCode}');
      print('📨 Cuerpo test: ${response.body}');

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error en test de conexión: $e');
      return false;
    }
  }

  // ==================== ASISTENCIAS MEJORADAS ====================

  Future<void> registrarAsistenciaCompleta(AsistenciaModel asistencia) async {
    try {
      print('📤 INICIANDO REGISTRO DE ASISTENCIA COMPLETA');
      print('   URL destino: ${ApiConfig.baseUrl}/asistencias/completa');
      print('   DNI: ${asistencia.dni}');
      print('   Nombre: ${asistencia.nombreCompleto}');
      print('   Tipo: ${asistencia.tipo}');
      print('   Código: ${asistencia.codigoUniversitario}');
      print('   Guardia ID: ${asistencia.guardiaId}');
      print('   Guardia: ${asistencia.guardiaNombre}');
      print('   Fecha: ${asistencia.fechaHora}');
      print('   Headers: $_headers');

      final jsonData = asistencia.toJson();
      print('📋 Datos JSON completos:');
      jsonData.forEach((key, value) {
        print('   $key: $value');
      });

      final body = json.encode(jsonData);
      print('📋 Body final: $body');

      print('🌐 Enviando petición POST...');
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/asistencias/completa'),
            headers: _headers,
            body: body,
          )
          .timeout(Duration(seconds: 30));

      print('📨 RESPUESTA RECIBIDA:');
      print('   Status Code: ${response.statusCode}');
      print('   Headers: ${response.headers}');
      print('   Body: ${response.body}');

      if (response.statusCode == 201) {
        print('✅ ASISTENCIA REGISTRADA EXITOSAMENTE EN MONGODB');
        try {
          final responseData = json.decode(response.body);
          print('✅ ID en MongoDB: ${responseData['_id']}');
        } catch (e) {
          print('⚠️ No se pudo parsear respuesta JSON, pero status 201 OK');
        }
      } else if (response.statusCode >= 400 && response.statusCode < 500) {
        // Error del cliente (400-499)
        try {
          final error = json.decode(response.body);
          print(
              '❌ ERROR DEL CLIENTE (${response.statusCode}): ${error['error']}');
          throw Exception(
              'Error ${response.statusCode}: ${error['error'] ?? 'Error desconocido'}');
        } catch (e) {
          print(
              '❌ ERROR DEL CLIENTE (${response.statusCode}): ${response.body}');
          throw Exception('Error ${response.statusCode}: ${response.body}');
        }
      } else if (response.statusCode >= 500) {
        // Error del servidor (500+)
        print(
            '❌ ERROR DEL SERVIDOR (${response.statusCode}): ${response.body}');
        throw Exception(
            'Error del servidor ${response.statusCode}: ${response.body}');
      } else {
        print(
            '❌ RESPUESTA INESPERADA (${response.statusCode}): ${response.body}');
        throw Exception(
            'Respuesta inesperada ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ EXCEPCIÓN CRÍTICA EN REGISTRO: $e');
      print('❌ Tipo de error: ${e.runtimeType}');
      if (e is TimeoutException) {
        throw Exception('TIMEOUT: El servidor no respondió en 30 segundos');
      } else if (e is FormatException) {
        throw Exception('ERROR DE FORMATO: ${e.message}');
      } else {
        throw Exception('ERROR DE CONEXIÓN: $e');
      }
    }
  }

  Future<String> determinarTipoAcceso(String estudianteDni) async {
    try {
      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/asistencias/ultimo-acceso/$estudianteDni',
        ),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final ultimoTipo = data['ultimo_tipo'] ?? 'salida';
        // Si último fue entrada, ahora debería ser salida y viceversa
        return ultimoTipo == 'entrada' ? 'salida' : 'entrada';
      } else {
        // Si no hay registros previos, asumir entrada
        return 'entrada';
      }
    } catch (e) {
      // En caso de error, asumir entrada
      return 'entrada';
    }
  }

  // ==================== SESIONES GUARDIAS (US059) ====================

  Future<Map<String, dynamic>> iniciarSesionGuardia({
    required String guardiaId,
    required String guardiaNombre,
    required String puntoControl,
    Map<String, dynamic>? deviceInfo,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/sesiones/iniciar'),
        headers: _headers,
        body: json.encode({
          'guardia_id': guardiaId,
          'guardia_nombre': guardiaNombre,
          'punto_control': puntoControl,
          'device_info': deviceInfo ?? {},
        }),
      );

      final responseData = json.decode(response.body);

      return {
        'success': response.statusCode == 201,
        'conflict': response.statusCode == 409,
        'data': responseData,
      };
    } catch (e) {
      throw Exception('Error de conexión al iniciar sesión: $e');
    }
  }

  Future<bool> enviarHeartbeat(String sessionToken) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/sesiones/heartbeat'),
        headers: _headers,
        body: json.encode({'session_token': sessionToken}),
      );

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error en heartbeat: $e');
    }
  }

  Future<bool> finalizarSesionGuardia(String sessionToken) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/sesiones/finalizar'),
        headers: _headers,
        body: json.encode({'session_token': sessionToken}),
      );

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error al finalizar sesión: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getSesionesActivas() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/sesiones/activas'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception(
          'Error al obtener sesiones activas: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<bool> forzarFinalizacionSesion({
    required String guardiaId,
    required String adminId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/sesiones/forzar-finalizacion'),
        headers: _headers,
        body: json.encode({'guardia_id': guardiaId, 'admin_id': adminId}),
      );

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error al forzar finalización: $e');
    }
  }

  // ==================== MÉTODOS PARA SINCRONIZACIÓN AVANZADA ====================

  /// Obtener versiones de las colecciones del servidor
  Future<Map<String, dynamic>> getVersiones() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/versiones'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Error al obtener versiones: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al obtener versiones: $e');
    }
  }

  /// Obtener sesiones activas del servidor
  Future<List<Map<String, dynamic>>> getActiveSessions() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/sesiones/activas'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['sesiones'] ?? []);
      } else {
        throw Exception(
          'Error al obtener sesiones activas: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error al obtener sesiones activas: $e');
    }
  }

  /// Obtener datos de asistencias para sincronización
  Future<List<AsistenciaModel>> getAsistenciasSync() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.asistenciasUrl),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['asistencias'] as List)
            .map((asistencia) => AsistenciaModel.fromJson(asistencia))
            .toList();
      } else {
        throw Exception('Error al obtener asistencias: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al obtener asistencias: $e');
    }
  }

  /// Probar conectividad con el servidor
  Future<void> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        // Conexión exitosa
        return;
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Connection timeout');
    } catch (e) {
      throw Exception('Connection test failed: $e');
    }
  }

  // Obtener asistencias de un guardia específico (últimas 24 horas)
  Future<List<AsistenciaModel>> getAsistenciasGuardia(String guardiaId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/asistencias/guardia/$guardiaId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => AsistenciaModel.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener asistencias: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener todas las asistencias con guardia (para estadísticas)
  Future<List<AsistenciaModel>> getAllAsistencias() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/asistencias/con-guardia'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> asistencias = data['asistencias'];
        return asistencias.map((json) => AsistenciaModel.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener asistencias: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }
}
