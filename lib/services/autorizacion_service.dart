import 'package:flutter/foundation.dart';
import '../models/decision_manual_model.dart';
import '../models/alumno_model.dart';
import '../models/presencia_model.dart';
import '../services/api_service.dart';

class AutorizacionService extends ChangeNotifier {
  static final AutorizacionService _instance = AutorizacionService._internal();
  factory AutorizacionService() => _instance;
  AutorizacionService._internal();

  final ApiService _apiService = ApiService();

  List<DecisionManualModel> _historialDecisiones = [];
  List<PresenciaModel> _presenciaActual = [];
  bool _isLoading = false;

  // Getters
  List<DecisionManualModel> get historialDecisiones =>
      List.unmodifiable(_historialDecisiones);
  List<PresenciaModel> get presenciaActual =>
      List.unmodifiable(_presenciaActual);
  bool get isLoading => _isLoading;

  // Verificar si un estudiante está activo y puede acceder
  Future<Map<String, dynamic>> verificarEstadoEstudiante(
    AlumnoModel estudiante,
  ) async {
    try {
      // Verificar estado básico
      if (!estudiante.isActive) {
        return {
          'puede_acceder': false,
          'razon': 'Estudiante inactivo en el sistema',
          'requiere_autorizacion_manual': true,
        };
      }

      // Verificar presencia actual para determinar entrada/salida automáticamente
      final presencia = await _obtenerPresenciaEstudiante(estudiante.dni);
      String tipoAcceso = 'entrada';

      if (presencia != null && presencia.estaDentro) {
        // Si ya está dentro, es una SALIDA
        tipoAcceso = 'salida';
      }

      // Estudiante puede acceder (entrada o salida automática)
      return {
        'puede_acceder': true,
        'razon': 'Estudiante verificado correctamente',
        'requiere_autorizacion_manual': false,
        'tipo_acceso': tipoAcceso,
      };
    } catch (e) {
      return {
        'puede_acceder': false,
        'razon': 'Error al verificar estado: $e',
        'requiere_autorizacion_manual': true,
      };
    }
  }

  // Determinar el tipo de acceso basado en el historial
  Future<String> determinarTipoAcceso(String estudianteDni) async {
    try {
      return await _apiService.determinarTipoAcceso(estudianteDni);
    } catch (e) {
      debugPrint('Error determinando tipo acceso: $e');
      return 'entrada'; // Por defecto
    }
  }

  // Registrar una decisión manual del guardia
  Future<void> registrarDecisionManual(DecisionManualModel decision) async {
    _setLoading(true);
    try {
      await _apiService.registrarDecisionManual(decision);
      _historialDecisiones.insert(0, decision);

      // Si la decisión es de entrada autorizada, actualizar presencia
      if (decision.autorizado && decision.tipoAcceso == 'entrada') {
        await _apiService.actualizarPresencia(
          decision.estudianteDni,
          decision.tipoAcceso,
          decision.puntoControl,
          decision.guardiaId,
        );
      }

      notifyListeners();
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Cargar historial de decisiones del guardia
  Future<void> cargarHistorialDecisiones(String guardiaId) async {
    _setLoading(true);
    try {
      _historialDecisiones = await _apiService.getDecisionesGuardia(guardiaId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error cargando historial: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Cargar presencia actual en el campus
  Future<void> cargarPresenciaActual() async {
    _setLoading(true);
    try {
      _presenciaActual = await _apiService.getPresenciaActual();
      notifyListeners();
    } catch (e) {
      debugPrint('Error cargando presencia: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Obtener presencia específica de un estudiante
  Future<PresenciaModel?> _obtenerPresenciaEstudiante(String dni) async {
    try {
      await cargarPresenciaActual();
      return _presenciaActual.firstWhere(
        (p) => p.estudianteDni == dni && p.estaDentro,
        orElse: () => throw StateError('No encontrado'),
      );
    } catch (e) {
      return null;
    }
  }

  // Obtener estadísticas de decisiones
  Map<String, int> get estadisticasDecisiones {
    final total = _historialDecisiones.length;
    final autorizadas = _historialDecisiones.where((d) => d.autorizado).length;
    final denegadas = total - autorizadas;

    return {'total': total, 'autorizadas': autorizadas, 'denegadas': denegadas};
  }

  // Obtener decisiones recientes (últimas 24 horas)
  List<DecisionManualModel> get decisionesRecientes {
    final ahora = DateTime.now();
    final hace24Horas = ahora.subtract(const Duration(hours: 24));

    return _historialDecisiones
        .where((decision) => decision.timestamp.isAfter(hace24Horas))
        .toList();
  }

  // Obtener personas actualmente en campus
  int get personasEnCampus =>
      _presenciaActual.where((p) => p.estaDentro).length;

  // Obtener personas que llevan mucho tiempo en campus
  List<PresenciaModel> get personasLargoTiempo =>
      _presenciaActual
          .where((p) => p.estaDentro && p.llevaVariasHoras)
          .toList();

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Limpiar datos al cerrar sesión
  void limpiarDatos() {
    _historialDecisiones.clear();
    _presenciaActual.clear();
    notifyListeners();
  }
}
