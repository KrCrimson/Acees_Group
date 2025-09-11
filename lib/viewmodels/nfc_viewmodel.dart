import 'package:flutter/foundation.dart';
import '../models/alumno_model.dart';
import '../models/asistencia_model.dart';
import '../services/api_service.dart';
import '../services/nfc_service.dart';

class NfcViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final NfcService _nfcService = NfcService();

  bool _isScanning = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  AlumnoModel? _scannedAlumno;

  // Getters
  bool get isScanning => _isScanning;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  AlumnoModel? get scannedAlumno => _scannedAlumno;
  bool get isNfcReady => !_isScanning && !_isLoading;

  // Verificar disponibilidad NFC
  Future<bool> checkNfcAvailability() async {
    try {
      return await _nfcService.isNfcAvailable();
    } catch (e) {
      _setError('Error al verificar NFC: $e');
      return false;
    }
  }

  // Iniciar escaneo NFC
  Future<void> startNfcScan() async {
    if (_isScanning || _isLoading) return;

    _setScanning(true);
    _clearMessages();
    _scannedAlumno = null;

    try {
      // Verificar NFC disponible
      bool available = await _nfcService.isNfcAvailable();
      if (!available) {
        throw Exception('NFC no está disponible en este dispositivo');
      }

      // Leer pulsera NFC
      String codigoUniversitario = await _nfcService.readNfcCard();

      // Validar alumno en el servidor
      _setLoading(true);
      _scannedAlumno = await _apiService.getAlumnoByCodigo(codigoUniversitario);

      if (_scannedAlumno!.isActive) {
        // Registrar asistencia
        await _registrarAsistencia(_scannedAlumno!);
        _setSuccess(
          '✅ Acceso concedido para ${_scannedAlumno!.nombreCompleto}',
        );
      } else {
        _setError('❌ Estudiante inactivo: ${_scannedAlumno!.nombreCompleto}');
      }
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      _setScanning(false);
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

    _setScanning(false);
    _clearMessages();
  }

  // Registrar asistencia
  Future<void> _registrarAsistencia(AlumnoModel alumno) async {
    try {
      final asistencia = AsistenciaModel(
        id: '', // Se genera en el servidor
        nombre: alumno.nombre,
        apellido: alumno.apellido,
        dni: alumno.dni,
        codigoUniversitario: alumno.codigoUniversitario,
        siglasFacultad: alumno.siglasFacultad,
        siglasEscuela: alumno.siglasEscuela,
        tipo: 'estudiante',
        fechaHora: DateTime.now(),
        entradaTipo: 'NFC',
        puerta: 'Principal', // Esto puede venir de configuración
      );

      await _apiService.registrarAsistencia(asistencia);
    } catch (e) {
      // No lanzar error, ya que el acceso fue validado
      debugPrint('Error al registrar asistencia: $e');
    }
  }

  // Limpiar datos
  void clearScan() {
    _scannedAlumno = null;
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
}
