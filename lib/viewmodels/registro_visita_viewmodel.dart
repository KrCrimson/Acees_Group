import 'package:flutter/foundation.dart';
import '../models/externo_model.dart';
import '../services/api_service.dart';
import '../services/session_guard_service.dart';

class RegistroVisitaViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final SessionGuardService _sessionGuardService = SessionGuardService();

  bool _isLoading = false;
  bool _isManualMode = false;
  String? _errorMessage;
  
  // Campos del formulario
  String _dni = '';
  String _nombreCompleto = '';
  String? _selectedRazon;
  String _descripcionUbicacion = '';

  // Lista de razones predefinidas
  final List<String> razones = [
    'Soy estudiante olvide mi pulsera', // Requerido
    'Trámite administrativo',
    'Reunión con docente',
    'Proveedor / Servicios',
    'Visita a familiar',
    'Evento académico',
    'Solicitud de información',
    'Entrega de documentos',
    'Personal de mantenimiento externo',
    'Visita institucional',
    'Atención en clínica/servicios',
    'Uso de biblioteca',
    'Otro', // Requerido al final
  ];

  // Getters
  bool get isLoading => _isLoading;
  bool get isManualMode => _isManualMode;
  String? get errorMessage => _errorMessage;
  String get dni => _dni;
  String get nombreCompleto => _nombreCompleto;
  String? get selectedRazon => _selectedRazon;

  void setDni(String value) {
    _dni = value;
    notifyListeners();
  }

  void setNombreCompleto(String value) {
    _nombreCompleto = value;
    notifyListeners();
  }

  void setRazon(String? value) {
    _selectedRazon = value;
    notifyListeners();
  }
  
  void setDescripcionUbicacion(String value) {
    _descripcionUbicacion = value;
    notifyListeners();
  }

  void toggleManualMode(bool value) {
    _isManualMode = value;
    if (!value) {
      // Si desactiva manual, limpiar nombre para obligar búsqueda
      _nombreCompleto = '';
    }
    notifyListeners();
  }

  Future<void> buscarDni() async {
    if (_dni.length != 8) {
      _errorMessage = 'El DNI debe tener 8 dígitos';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final datos = await _apiService.consultarDniReniec(_dni);
      _nombreCompleto = datos['nombre_completo'] ?? '';
      // Si encontramos datos, desactivamos modo manual automáticamente
      _isManualMode = false; 
    } catch (e) {
      _errorMessage = 'No se encontraron datos. Intente modo manual.';
      _nombreCompleto = '';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> registrarVisita() async {
    if (_dni.isEmpty || _nombreCompleto.isEmpty || _selectedRazon == null) {
      _errorMessage = 'Por favor complete todos los campos obligatorios';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Obtener datos del guardia actual
      final guardiaId = _sessionGuardService.guardiaId;
      final guardiaNombre = _sessionGuardService.guardiaNombre;
      
      if (guardiaId == null) throw Exception('No hay sesión de guardia activa');

      final nuevoExterno = ExternoModel(
        nombreCompleto: _nombreCompleto,
        dni: _dni,
        razon: _selectedRazon!,
        guardiaId: guardiaId,
        guardiaNombre: guardiaNombre ?? 'Guardia',
        descripcionUbicacion: _descripcionUbicacion,
        tipo: 'entrada', // Por defecto entrada
      );

      await _apiService.registrarVisitaExterno(nuevoExterno);
      return true;
    } catch (e) {
      _errorMessage = 'Error al registrar: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
