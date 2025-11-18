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

  // Información del guardia actual
  String? _guardiaId;
  String? _guardiaNombre;
  String? _puntoControl;

  // Cola para manejar múltiples detecciones
  final Queue<String> _detectionQueue = Queue<String>();
  bool _processingQueue = false;
  List<AlumnoModel> _recentDetections = [];
  Timer? _queueTimer;

  // Getters
  bool get isScanning => _isScanning;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  AlumnoModel? get scannedAlumno => _scannedAlumno;
  String? get lastAccessType => _lastAccessType;
  bool get isNfcReady => !_isScanning && !_isLoading;
  List<AlumnoModel> get recentDetections =>
      List.unmodifiable(_recentDetections);
  int get queueSize => _detectionQueue.length;
  bool get isProcessingQueue => _processingQueue;

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

  // Procesar una detección individual con verificación avanzada (US022-US030)
  Future<void> _processingleDetection(String codigoUniversitario) async {
    try {
      _setLoading(true);

      print('🔍 PROCESANDO DETECCIÓN:');
      print('   Código: $codigoUniversitario');
      print('   Guardia: $_guardiaNombre ($_guardiaId)');

      // Validar alumno en el servidor
      print('🌐 Buscando alumno en servidor...');
      AlumnoModel alumno = await _apiService.getAlumnoByCodigo(
        codigoUniversitario,
      );

      print('✅ Alumno encontrado: ${alumno.nombreCompleto}');
      print('   DNI: ${alumno.dni}');
      print('   Activo: ${alumno.isActive}');

      // Realizar verificación completa del estudiante (US022)
      print('🔍 Verificando estado del estudiante...');
      final verificacion = await verificarEstudianteCompleto(alumno);

      print('📋 Resultado verificación:');
      print('   Puede acceder: ${verificacion['puede_acceder']}');
      print('   Razón: ${verificacion['razon']}');
      print('   Tipo acceso: ${verificacion['tipo_acceso']}');

      if (verificacion['puede_acceder'] == true) {
        // Usar tipo de acceso automático detectado
        final tipoAcceso = verificacion['tipo_acceso'] ?? 'entrada';

        print('✅ ACCESO AUTORIZADO - Registrando $tipoAcceso...');

        // Registrar asistencia completa automáticamente
        await registrarAsistenciaCompleta(alumno, tipoAcceso);

        print('✅ Asistencia registrada exitosamente');

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

        print('🎉 PROCESO COMPLETADO EXITOSAMENTE');
      } else {
        print('⚠️ ACCESO DENEGADO - Requiere autorización manual');
        // El estudiante requiere autorización manual (US023-US024)
        _setError('⚠️ Requiere autorización manual: ${verificacion['razon']}');
        _scannedAlumno = alumno; // Mantener para mostrar en UI de verificación
      }
    } catch (e) {
      print('❌ ERROR EN PROCESAMIENTO: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      _setError('Error procesando ${codigoUniversitario}: $e');
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

  // ==================== NUEVOS MÉTODOS PARA US022-US030 ====================

  // Configurar información del guardia
  void configurarGuardia(
    String guardiaId,
    String guardiaNombre,
    String puntoControl,
  ) {
    print('👮 Configurando guardia:');
    print('   ID: $guardiaId');
    print('   Nombre: $guardiaNombre');
    print('   Punto Control: $puntoControl');

    // Validar que los datos no estén vacíos
    if (guardiaId.isEmpty || guardiaNombre.isEmpty) {
      print('❌ Error: Datos del guardia vacíos');
      return;
    }

    _guardiaId = guardiaId;
    _guardiaNombre = guardiaNombre;
    _puntoControl = puntoControl;

    print('✅ Guardia configurado correctamente');
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

      print(
          '🌐 Estado conexión: ${_offlineService.isOnline ? "ONLINE" : "OFFLINE"}');
      print('🔧 FORZANDO REGISTRO ONLINE para debugging...');

      try {
        print('📤 Enviando asistencia al servidor...');
        // Registrar asistencia completa
        await _apiService.registrarAsistenciaCompleta(asistencia);
        print('✅ Asistencia enviada al servidor');

        print('📤 Actualizando control de presencia...');
        // Actualizar control de presencia (US026-US030)
        await _apiService.actualizarPresencia(
          estudiante.dni,
          tipoAcceso,
          _puntoControl ?? 'Desconocido',
          _guardiaId!,
        );
        print('✅ Control de presencia actualizado');

        print('🎉 REGISTRO COMPLETADO - Debería aparecer en MongoDB');
      } catch (e) {
        print('❌ ERROR CRÍTICO enviando al servidor: $e');
        print('❌ Stack trace: ${StackTrace.current}');

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

  /// Guardar asistencia para sincronización offline
  Future<void> _guardarAsistenciaOffline(AsistenciaModel asistencia) async {
    await _offlineService.addOfflineEvent(
      EventType.asistencia,
      asistencia.toJson(),
    );
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
