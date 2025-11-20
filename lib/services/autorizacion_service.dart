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
  
  // Datos crudos y filtros
  List<DecisionManualModel> _todasLasAsistenciasRaw = [];
  DateTime? _filtroFechaInicio;
  DateTime? _filtroFechaFin;
  String? _filtroCarrera;
  
  bool _isLoading = false;

  // Getters
  List<DecisionManualModel> get historialDecisiones =>
      List.unmodifiable(_historialDecisiones);
  List<PresenciaModel> get presenciaActual =>
      List.unmodifiable(_presenciaActual);
  bool get isLoading => _isLoading;
  
  // Getters de filtros activos
  DateTime? get filtroFechaInicio => _filtroFechaInicio;
  DateTime? get filtroFechaFin => _filtroFechaFin;
  String? get filtroCarrera => _filtroCarrera;
  bool get hayFiltrosActivos => 
      _filtroFechaInicio != null || _filtroFechaFin != null || _filtroCarrera != null;

  // Obtener lista única de carreras disponibles en el historial
  List<String> get carrerasDisponibles {
    final carreras = <String>{};
    for (var decision in _todasLasAsistenciasRaw) {
      // Extraer carrera de datosEstudiante si existe, o intentar inferir
      if (decision.datosEstudiante != null && decision.datosEstudiante!['escuela'] != null) {
        carreras.add(decision.datosEstudiante!['escuela']);
      }
    }
    return carreras.toList()..sort();
  }

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

  // Cargar historial de asistencias del guardia (para estadísticas)
  Future<void> cargarHistorialDecisiones(String guardiaId) async {
    _setLoading(true);
    try {
      // TEMPORAL: Usar endpoint de todas las asistencias y filtrar por guardia
      final todasAsistencias = await _apiService.getAllAsistencias();
      
      // Filtrar por guardia y últimas 24 horas
      final ahora = DateTime.now();
      final hace24Horas = ahora.subtract(const Duration(hours: 24));
      
      final asistenciasGuardia = todasAsistencias.where((asistencia) {
        final esDelGuardia = asistencia.guardiaId == guardiaId;
        final esReciente = asistencia.fechaHora.isAfter(hace24Horas);
        return esDelGuardia && esReciente;
      }).toList();

      // Convertir asistencias a decisiones para mostrar estadísticas
      _historialDecisiones = asistenciasGuardia
          .map((asistencia) => DecisionManualModel(
                id: asistencia.id,
                estudianteId: asistencia.codigoUniversitario,
                estudianteDni: asistencia.dni,
                estudianteNombre: '${asistencia.nombre} ${asistencia.apellido}',
                tipoAcceso: asistencia.tipo,
                puntoControl: asistencia.puerta,
                guardiaId: asistencia.guardiaId ?? guardiaId,
                guardiaNombre: asistencia.guardiaNombre ?? 'Guardia',

                autorizado: asistencia.estado == 'autorizado',
                razon: asistencia.razonDecision ?? 'Acceso NFC autorizado',
                timestamp: asistencia.fechaHora,
              ))
          .toList();
          
      // Guardar copia completa para filtrado profundo
      _todasLasAsistenciasRaw = List.from(_historialDecisiones);
      
      // Inicialmente aplicar filtro de 24h por defecto (limpiando filtros explícitos)
      _filtroFechaInicio = null;
      _filtroFechaFin = null;
      _filtroCarrera = null;

      notifyListeners();
    } catch (e) {
      // Si falla la conexión, usar datos vacíos pero no fallar
      _historialDecisiones = [];
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // Actualizar estado de una asistencia
  Future<void> actualizarEstadoAsistencia(
      String id, String estado, String? razon) async {
    _setLoading(true);
    try {
      await _apiService.updateAsistenciaEstado(id, estado, razon);
      
      // Actualizar localmente
      final index = _historialDecisiones.indexWhere((d) => d.id == id);
      if (index != -1) {
        final decisionAnterior = _historialDecisiones[index];
        _historialDecisiones[index] = DecisionManualModel(
          id: decisionAnterior.id,
          estudianteId: decisionAnterior.estudianteId,
          estudianteDni: decisionAnterior.estudianteDni,
          estudianteNombre: decisionAnterior.estudianteNombre,
          guardiaId: decisionAnterior.guardiaId,
          guardiaNombre: decisionAnterior.guardiaNombre,
          autorizado: estado == 'autorizado',
          razon: razon ?? decisionAnterior.razon,
          timestamp: decisionAnterior.timestamp,
          puntoControl: decisionAnterior.puntoControl,
          tipoAcceso: decisionAnterior.tipoAcceso,
          datosEstudiante: decisionAnterior.datosEstudiante,
        );
        notifyListeners();
      }
    } catch (e) {
      rethrow;
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

  // Búsqueda
  String _searchQuery = '';

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  }

  // Establecer filtros avanzados
  void setFiltros({DateTime? inicio, DateTime? fin, String? carrera}) {
    _filtroFechaInicio = inicio;
    _filtroFechaFin = fin;
    _filtroCarrera = carrera;
    notifyListeners();
  }

  // Limpiar filtros y volver a vista por defecto (24h)
  void limpiarFiltros() {
    _filtroFechaInicio = null;
    _filtroFechaFin = null;
    _filtroCarrera = null;
    notifyListeners();
  }

  List<DecisionManualModel> get decisionesFiltradas {
    List<DecisionManualModel> baseList;
    
    // 1. Determinar lista base según filtros de fecha
    if (hayFiltrosActivos) {
      // Si hay filtros activos, usamos la lista completa RAW
      baseList = _todasLasAsistenciasRaw;
      
      // Filtrar por rango de fechas si aplica
      if (_filtroFechaInicio != null) {
        baseList = baseList.where((d) => 
            d.timestamp.isAfter(_filtroFechaInicio!) || 
            d.timestamp.isAtSameMomentAs(_filtroFechaInicio!)).toList();
      }
      
      if (_filtroFechaFin != null) {
        // Ajustar fin al final del día
        final finAjustado = DateTime(
            _filtroFechaFin!.year, _filtroFechaFin!.month, _filtroFechaFin!.day, 23, 59, 59);
        baseList = baseList.where((d) => 
            d.timestamp.isBefore(finAjustado) || 
            d.timestamp.isAtSameMomentAs(finAjustado)).toList();
      }
      
      // Filtrar por carrera si aplica
      if (_filtroCarrera != null && _filtroCarrera!.isNotEmpty) {
        baseList = baseList.where((d) {
          final escuela = d.datosEstudiante?['escuela']?.toString() ?? '';
          return escuela == _filtroCarrera;
        }).toList();
      }
    } else {
      // Si no hay filtros, comportamiento por defecto: últimas 24h
      baseList = decisionesRecientes;
    }

    // 2. Aplicar búsqueda de texto sobre la lista base
    if (_searchQuery.isEmpty) {
      return baseList;
    }

    final queryLower = _searchQuery.toLowerCase();
    return baseList.where((decision) {
      final nombreMatch =
          decision.estudianteNombre.toLowerCase().contains(queryLower);
      final dniMatch = decision.estudianteDni.contains(queryLower);
      return nombreMatch || dniMatch;
    }).toList();
  }

  // Obtener personas actualmente en campus
  int get personasEnCampus =>
      _presenciaActual.where((p) => p.estaDentro).length;

  // Obtener personas que llevan mucho tiempo en campus
  List<PresenciaModel> get personasLargoTiempo => _presenciaActual
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
