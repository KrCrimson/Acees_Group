import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:collection';
import '../models/alumno_model.dart';
import '../models/asistencia_model.dart';
import '../models/decision_manual_model.dart';
import '../services/api_service.dart';
import '../services/nfc_service.dart';
import '../services/autorizacion_service.dart';
import '../services/offline_service.dart';

class NfcViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final NfcService _nfcService = NfcService();
  final AutorizacionService _autorizacionService = AutorizacionService();
  final OfflineService _offlineService = OfflineService();

  bool _isScanning = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  AlumnoModel? _scannedAlumno;
  String? _lastAccessType; // Para rastrear el último tipo de acceso
  String? _lastAsistenciaId; // ID de la última asistencia registrada

  // Callback para mostrar confirmación con foto
  Function(Map<String, dynamic>, String)? _onAsistenciaRegistrada;

  // Información del guardia actual
  String? _guardiaId;
  String? _guardiaNombre;
  String? _puntoControl;

  // Cola para manejar múltiples detecciones
  final Queue<String> _detectionQueue = Queue<String>();
  bool _processingQueue = false;
  List<AlumnoModel> _recentDetections = [];
  Timer? _queueTimer;

  // SISTEMA DE LOGS EN TIEMPO REAL
  final List<String> _debugLogs = [];
  static const int maxLogs = 50;

  // Getters
  bool get isScanning => _isScanning;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  AlumnoModel? get scannedAlumno => _scannedAlumno;
  String? get lastAccessType => _lastAccessType;
  String? get lastAsistenciaId => _lastAsistenciaId;
  bool get isNfcReady => !_isScanning && !_isLoading;
  List<AlumnoModel> get recentDetections =>
      List.unmodifiable(_recentDetections);
  int get queueSize => _detectionQueue.length;
  bool get isProcessingQueue => _processingQueue;
  List<String> get debugLogs => List.unmodifiable(_debugLogs);

  // Configurar callback para mostrar confirmación con foto
  void setOnAsistenciaRegistrada(
      Function(Map<String, dynamic>, String)? callback) {
    _onAsistenciaRegistrada = callback;
  }

  // Verificar disponibilidad NFC
  Future<bool> checkNfcAvailability() async {
    try {
      return await _nfcService.isNfcAvailable();
    } catch (e) {
      _setError('Error al verificar NFC: $e');
      return false;
    }
  }

  // Iniciar escaneo NFC continuo
  Future<void> startNfcScan() async {
    if (_isScanning) return;

    // VALIDAR que el guardia esté configurado ANTES de iniciar
    if (_guardiaId == null || _guardiaNombre == null) {
      _setError('❌ Error: Guardia no configurado. Reinicie la sesión.');
      return;
    }

    _setScanning(true);
    _clearMessages();
    _scannedAlumno = null;

    try {
      print('🚀 Iniciando escaneo NFC continuo...');
      print('👮 Guardia configurado: $_guardiaNombre (ID: $_guardiaId)');

      // Verificar NFC disponible
      bool available = await _nfcService.isNfcAvailable();
      if (!available) {
        throw Exception('NFC no está disponible en este dispositivo');
      }

      _setSuccess('🔄 ESCÁNER ACTIVO - Acerque las pulseras...');

      // Iniciar bucle de lectura continua
      await _startContinuousScanning();
    } catch (e) {
      String errorMsg = e.toString().replaceAll('Exception: ', '');
      print('❌ Error en escaneo: $errorMsg');
      _setError('❌ $errorMsg');
      _setScanning(false);
    }
  }

  // Bucle de lectura continua
  Future<void> _startContinuousScanning() async {
    while (_isScanning) {
      try {
        print('📡 Esperando próxima pulsera...');

        // Leer pulsera con timeout corto
        String codigoUniversitario = await _nfcService.readNfcWithResult();

        if (_isScanning) {
          // Verificar que aún estamos escaneando
          // Mostrar código leído
          _setSuccess('✅ LEÍDO: $codigoUniversitario\n🔍 Procesando...');

          // Procesar la detección
          await _processingleDetection(codigoUniversitario);

          // Pausa corta antes de la próxima lectura
          await Future.delayed(Duration(seconds: 2));

          if (_isScanning) {
            _setSuccess('🔄 LISTO - Acerque la siguiente pulsera...');
          }
        }
      } catch (e) {
        if (_isScanning) {
          // Si hay error, seguir intentando
          print('⚠️ Error en lectura continua: $e');
          await Future.delayed(Duration(milliseconds: 500));
        }
      }
    }
  }

  // Leer NFC inmediatamente (para cuando se selecciona la app desde el diálogo)
  Future<void> readNfcImmediately() async {
    if (_isLoading) return;

    _setLoading(true);
    _clearMessages();

    try {
      print('🔄 Iniciando lectura NFC inmediata...');

      // Intentar lectura con resultado visible
      String codigoUniversitario = await _nfcService.readNfcWithResult();

      print('✅ Código leído: $codigoUniversitario');

      // Procesar la detección
      await _processingleDetection(codigoUniversitario);
    } catch (e) {
      print('❌ Error en lectura inmediata: $e');
      _setError(
        'Error al leer NFC: ${e.toString().replaceAll('Exception: ', '')}',
      );
    } finally {
      _setLoading(false);
    }
  }

  // Método eliminado - ahora usamos lectura simple

  // Métodos de cola eliminados - ahora usamos lectura simple

  // Convertir código hex de pulsera al formato de BD
  List<String> _generarVariantesCodigoHex(String codigoHex) {
    List<String> variantes = [];

    try {
      // Remover espacios
      String hexLimpio = codigoHex.replaceAll(' ', '');

      addLog('🔄 Generando variantes para: $codigoHex');

      // PRIMERO: Original en mayúsculas (formato más probable según la BD)
      String originalMayus = hexLimpio.toUpperCase();
      variantes.add(originalMayus);
      addLog('   V1 - Original mayús: $originalMayus');

      // SEGUNDO: Original en minúsculas
      String originalMinus = hexLimpio.toLowerCase();
      variantes.add(originalMinus);
      addLog('   V2 - Original minus: $originalMinus');

      // TERCERO: Si tiene 8 caracteres, probar formato invertido
      if (hexLimpio.length == 8) {
        List<String> bytes = [];
        for (int i = 0; i < hexLimpio.length; i += 2) {
          bytes.add(hexLimpio.substring(i, i + 2));
        }

        String invertidoMayus = bytes.reversed.join('').toUpperCase();
        String invertidoMinus = bytes.reversed.join('').toLowerCase();

        variantes.add(invertidoMayus);
        variantes.add(invertidoMinus);
        addLog('   V3 - Invertido mayús: $invertidoMayus');
        addLog('   V4 - Invertido minus: $invertidoMinus');
      }
    } catch (e) {
      addLog('❌ Error generando variantes: $e');
      variantes.add(codigoHex);
    }

    return variantes;
  }

  // Procesar una detección individual con verificación avanzada (US022-US030)
  Future<void> _processingleDetection(String codigoUniversitario) async {
    try {
      _setLoading(true);

      addLog('🔍 PROCESANDO DETECCIÓN:');
      addLog('   Código original: $codigoUniversitario');

      addLog('   Guardia: $_guardiaNombre ($_guardiaId)');

      // GENERAR MÚLTIPLES VARIANTES DEL CÓDIGO Y PROBAR CADA UNA
      List<String> variantes = _generarVariantesCodigoHex(codigoUniversitario);

      AlumnoModel? alumno;

      for (String variante in variantes) {
        try {
          addLog('🔍 Probando variante: "$variante"');
          alumno = await _apiService.getAlumnoByCodigo(variante);
          addLog('✅ ¡ENCONTRADO con variante: "$variante"!');
          addLog('   Alumno: ${alumno.nombreCompleto}');
          addLog('   DNI: ${alumno.dni}');
          addLog('   Código BD: ${alumno.codigoUniversitario}');
          addLog('   Activo: ${alumno.isActive}');
          break; // Salir del bucle cuando encontremos el alumno
        } catch (e) {
          addLog('❌ No encontrado con: "$variante"');
          continue; // Probar la siguiente variante
        }
      }

      // Si no se encontró con ninguna variante
      if (alumno == null) {
        addLog('❌ ERROR: Alumno no encontrado con ninguna variante');
        addLog('   Código original: "$codigoUniversitario"');
        addLog('   Variantes probadas: ${variantes.join(", ")}');
        throw Exception(
            'Alumno con código "$codigoUniversitario" no está registrado en el sistema');
      }

      // Realizar verificación completa del estudiante (US022)
      addLog('🔍 Verificando estado del estudiante...');
      final verificacion = await verificarEstudianteCompleto(alumno);

      addLog('📋 Resultado verificación:');
      addLog('   Puede acceder: ${verificacion['puede_acceder']}');
      addLog('   Razón: ${verificacion['razon']}');
      addLog('   Tipo acceso: ${verificacion['tipo_acceso']}');

      if (verificacion['puede_acceder'] == true) {
        // Usar tipo de acceso automático detectado
        final tipoAcceso = verificacion['tipo_acceso'] ?? 'entrada';

        addLog('✅ ACCESO AUTORIZADO - Registrando $tipoAcceso...');

        // Registrar asistencia completa automáticamente
        await registrarAsistenciaCompleta(alumno, tipoAcceso);

        addLog('✅ Asistencia registrada exitosamente');

        // Añadir a detecciones recientes
        _recentDetections.insert(0, alumno);
        if (_recentDetections.length > 10) {
          _recentDetections = _recentDetections.take(10).toList();
        }

        // Mensaje diferenciado según el tipo
        String emoji = tipoAcceso == 'entrada' ? '🟢' : '🔴';
        String tipoTexto = tipoAcceso == 'entrada' ? 'ENTRADA' : 'SALIDA';
        _lastAccessType = tipoAcceso; // Guardar el tipo de acceso
        _setSuccess(
          '$emoji $tipoTexto registrada: ${alumno.nombreCompleto}',
        );
        _scannedAlumno = alumno;

        // 📸 MOSTRAR CONFIRMACIÓN CON FOTO
        if (_onAsistenciaRegistrada != null) {
          final alumnoData = {
            'DNI': alumno.dni,
            'nombre': alumno.nombre,
            'apellido': alumno.apellido,
            'código_universitario': alumno.codigoUniversitario,
            'siglas_facultad': alumno.siglasFacultad,
            'siglas_escuela': alumno.siglasEscuela,
            'estado': 'verdadero', // Asumimos activo si llegó hasta aquí
          };
          _onAsistenciaRegistrada!(alumnoData, tipoAcceso);
        }

        addLog('🎉 PROCESO COMPLETADO EXITOSAMENTE');
      } else {
        addLog('⚠️ ACCESO DENEGADO - Requiere autorización manual');
        // El estudiante requiere autorización manual (US023-US024)
        _setError('⚠️ Requiere autorización manual: ${verificacion['razon']}');
        _scannedAlumno = alumno; // Mantener para mostrar en UI de verificación
      }
    } catch (e) {
      addLog('❌ ERROR EN PROCESAMIENTO: $e');
      addLog('❌ Stack trace: ${StackTrace.current}');
      _setError('Error procesando $codigoUniversitario: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Detener escaneo NFC
  Future<void> stopNfcScan() async {
    if (!_isScanning) return;

    try {
      await _nfcService.stopNfcSession();
    } catch (e) {
      // Ignorar errores al detener
    }

    // Limpiar timers y cola
    _queueTimer?.cancel();
    _queueTimer = null;
    _detectionQueue.clear();
    _processingQueue = false;

    _setScanning(false);
    _clearMessages();
  }

  // Limpiar detecciones recientes
  void clearRecentDetections() {
    _recentDetections.clear();
    notifyListeners();
  }

  // Limpiar datos
  void clearScan() {
    _scannedAlumno = null;
    _lastAccessType = null;
    _lastAsistenciaId = null;
    _clearMessages();
    notifyListeners();
  }

  // Métodos privados
  void _setScanning(bool scanning) {
    _isScanning = scanning;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    _successMessage = null;
    notifyListeners();
  }

  void _setSuccess(String success) {
    _successMessage = success;
    _errorMessage = null;
    notifyListeners();
  }

  void _clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  // MÉTODOS PARA LOGS EN TIEMPO REAL
  void addLog(String message) {
    final timestamp = DateTime.now();
    final formattedTime =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
    final logMessage = '[$formattedTime] $message';

    _debugLogs.insert(0, logMessage);
    if (_debugLogs.length > maxLogs) {
      _debugLogs.removeRange(maxLogs, _debugLogs.length);
    }

    print(logMessage); // También imprimir en consola
    notifyListeners();
  }

  void clearLogs() {
    _debugLogs.clear();
    notifyListeners();
  }

  // ==================== NUEVOS MÉTODOS PARA US022-US030 ====================

  // Configurar información del guardia
  void configurarGuardia(
    String guardiaId,
    String guardiaNombre,
    String puntoControl,
  ) {
    addLog('👮 Configurando guardia:');
    addLog('   ID: $guardiaId');
    addLog('   Nombre: $guardiaNombre');
    addLog('   Punto Control: $puntoControl');

    // Validar que los datos no estén vacíos
    if (guardiaId.isEmpty || guardiaNombre.isEmpty) {
      addLog('❌ Error: Datos del guardia vacíos');
      return;
    }

    _guardiaId = guardiaId;
    _guardiaNombre = guardiaNombre;
    _puntoControl = puntoControl;

    addLog('✅ Guardia configurado correctamente');
    notifyListeners();
  }

  // Verificación avanzada del estudiante (US022)
  Future<Map<String, dynamic>> verificarEstudianteCompleto(
    AlumnoModel estudiante,
  ) async {
    try {
      // Usar el servicio de autorización para verificación completa
      return await _autorizacionService.verificarEstadoEstudiante(estudiante);
    } catch (e) {
      return {
        'puede_acceder': false,
        'razon': 'Error en verificación: $e',
        'requiere_autorizacion_manual': true,
      };
    }
  }

  // Determinar tipo de acceso inteligente (US028)
  Future<String> determinarTipoAccesoInteligente(String estudianteDni) async {
    try {
      return await _autorizacionService.determinarTipoAcceso(estudianteDni);
    } catch (e) {
      debugPrint('Error determinando tipo acceso: $e');
      return 'entrada';
    }
  }

  // Registrar asistencia mejorada con toda la información (US025-US030)
  Future<void> registrarAsistenciaCompleta(
    AlumnoModel estudiante,
    String tipoAcceso, {
    DecisionManualModel? decisionManual,
  }) async {
    try {
      // VALIDAR que el guardia esté configurado
      if (_guardiaId == null || _guardiaNombre == null) {
        throw Exception('Error: Guardia no configurado. Reinicie la sesión.');
      }

      final now = DateTime.now();

      // Generar ID más legible: YYYYMMDD_HHMMSS_DNI
      final fechaId =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}_${estudiante.dni}';

      final asistencia = AsistenciaModel(
        id: fechaId,
        nombre: estudiante.nombre,
        apellido: estudiante.apellido,
        dni: estudiante.dni,
        codigoUniversitario: estudiante.codigoUniversitario,
        siglasFacultad: estudiante.siglasFacultad,
        siglasEscuela: estudiante.siglasEscuela,
        tipo: tipoAcceso,
        fechaHora: now,
        entradaTipo: 'nfc',
        puerta: _puntoControl ?? 'Principal',
        // ASEGURAR que SIEMPRE se guarden los datos del guardia
        guardiaId: _guardiaId!, // Usar ! porque ya validamos arriba
        guardiaNombre: _guardiaNombre!, // Usar ! porque ya validamos arriba
        autorizacionManual: decisionManual != null,
        razonDecision: decisionManual?.razon,
        timestampDecision: decisionManual?.timestamp,
        // US029 - Ubicación detallada
        descripcionUbicacion:
            'Acceso ${tipoAcceso} - Punto: ${_puntoControl ?? "Principal"} - Guardia: ${_guardiaNombre}',
      );

      _lastAsistenciaId = fechaId;

      addLog(
          '🌐 Estado conexión: ${_offlineService.isOnline ? "ONLINE" : "OFFLINE"}');
      addLog('🔧 FORZANDO REGISTRO ONLINE para debugging...');

      try {
        addLog('📤 Enviando asistencia al servidor...');
        // Registrar asistencia completa"
        await _apiService.registrarAsistenciaCompleta(asistencia);
        addLog('✅ Asistencia enviada al servidor');

        addLog('📤 Actualizando control de presencia...');
        // Actualizar control de presencia (US026-US030)
        await _apiService.actualizarPresencia(
          estudiante.dni,
          tipoAcceso,
          _puntoControl ?? 'Desconocido',
          _guardiaId!,
        );
        addLog('✅ Control de presencia actualizado');

        addLog('🎉 REGISTRO COMPLETADO - Debería aparecer en MongoDB');
      } catch (e) {
        addLog('❌ ERROR CRÍTICO enviando al servidor: $e');
        addLog('❌ Stack trace: ${StackTrace.current}');

        // Si falla, mostrar el error específico
        _setError('ERROR: No se pudo guardar - $e');
        return; // Salir sin mostrar éxito
      }
    } catch (e) {
      _setError('Error al registrar asistencia: $e');
      rethrow;
    }
  }

  // Callback para cuando se toma una decisión manual
  Future<void> onDecisionManualTomada(DecisionManualModel decision) async {
    try {
      if (decision.autorizado && _scannedAlumno != null) {
        // Si se autorizó, registrar la asistencia
        await registrarAsistenciaCompleta(
          _scannedAlumno!,
          decision.tipoAcceso,
          decisionManual: decision,
        );
      }

      // Limpiar el estudiante escaneado
      _scannedAlumno = null;
      notifyListeners();
    } catch (e) {
      _setError('Error procesando decisión manual: $e');
    }
  }

  // Getters para información del guardia
  String? get guardiaId => _guardiaId;
  String? get guardiaNombre => _guardiaNombre;
  String? get puntoControl => _puntoControl;

  @override
  void dispose() {
    _queueTimer?.cancel();
    super.dispose();
  }
}
