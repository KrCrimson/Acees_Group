import 'package:flutter/foundation.dart';
import '../models/actividad_model.dart';
import '../services/api_service.dart';

class HistorialActividadesViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  // Estado de carga
  bool _isLoading = false;
  String? _errorMessage;

  // Datos principales
  List<ActividadModel> _actividades = [];
  List<ActividadModel> _actividadesHoy = [];
  List<ActividadModel> _actividadesSemana = [];
  ProductividadModel? _productividad;
  List<EstadisticasGuardiaModel> _estadisticasComparativas = [];

  // Filtros
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  String? _guardiaSeleccionado;
  String? _tipoActividadSeleccionado;
  String? _puntoControlSeleccionado;

  // Resumen del día
  Map<String, dynamic> _resumenHoy = {};

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<ActividadModel> get actividades => _actividades;
  List<ActividadModel> get actividadesHoy => _actividadesHoy;
  List<ActividadModel> get actividadesSemana => _actividadesSemana;
  ProductividadModel? get productividad => _productividad;
  List<EstadisticasGuardiaModel> get estadisticasComparativas => _estadisticasComparativas;
  
  DateTime? get fechaInicio => _fechaInicio;
  DateTime? get fechaFin => _fechaFin;
  String? get guardiaSeleccionado => _guardiaSeleccionado;
  String? get tipoActividadSeleccionado => _tipoActividadSeleccionado;
  String? get puntoControlSeleccionado => _puntoControlSeleccionado;
  
  Map<String, dynamic> get resumenHoy => _resumenHoy;

  // Helper para setear loading
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Helper para setear error
  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  // ==================== FILTROS ====================

  void setFiltroFecha(DateTime? inicio, DateTime? fin) {
    _fechaInicio = inicio;
    _fechaFin = fin;
    notifyListeners();
  }

  void setFiltroGuardia(String? guardiaId) {
    _guardiaSeleccionado = guardiaId;
    notifyListeners();
  }

  void setFiltroTipoActividad(String? tipo) {
    _tipoActividadSeleccionado = tipo;
    notifyListeners();
  }

  void setFiltroPuntoControl(String? punto) {
    _puntoControlSeleccionado = punto;
    notifyListeners();
  }

  void limpiarFiltros() {
    _fechaInicio = null;
    _fechaFin = null;
    _guardiaSeleccionado = null;
    _tipoActividadSeleccionado = null;
    _puntoControlSeleccionado = null;
    notifyListeners();
  }

  // ==================== CARGAR DATOS ====================

  // Cargar historial completo con filtros
  Future<void> cargarHistorialActividades({
    int page = 1,
    int limit = 50,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await _apiService.getHistorialActividades(
        fechaInicio: _fechaInicio,
        fechaFin: _fechaFin,
        guardiaId: _guardiaSeleccionado,
        tipoActividad: _tipoActividadSeleccionado,
        puntoControl: _puntoControlSeleccionado,
        page: page,
        limit: limit,
      );

      _actividades = response['actividades']
          .map<ActividadModel>((json) => ActividadModel.fromJson(json))
          .toList();

      debugPrint('✅ Cargadas ${_actividades.length} actividades del historial');
    } catch (e) {
      _setError('Error al cargar historial: $e');
      debugPrint('❌ Error cargando historial: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Cargar actividades de hoy
  Future<void> cargarActividadesHoy(String guardiaId) async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await _apiService.getActividadesHoy(guardiaId);
      
      _actividadesHoy = response['actividades']
          .map<ActividadModel>((json) => ActividadModel.fromJson(json))
          .toList();
      
      _resumenHoy = response['resumen'] ?? {};

      debugPrint('✅ Cargadas ${_actividadesHoy.length} actividades de hoy');
    } catch (e) {
      _setError('Error al cargar actividades de hoy: $e');
      debugPrint('❌ Error cargando actividades de hoy: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Cargar actividades de la semana
  Future<void> cargarActividadesSemana(String guardiaId) async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await _apiService.getActividadesSemana(guardiaId);
      
      _actividadesSemana = response['actividades']
          .map<ActividadModel>((json) => ActividadModel.fromJson(json))
          .toList();

      debugPrint('✅ Cargadas ${_actividadesSemana.length} actividades de la semana');
    } catch (e) {
      _setError('Error al cargar actividades de la semana: $e');
      debugPrint('❌ Error cargando actividades de la semana: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Cargar resumen de productividad
  Future<void> cargarResumenProductividad(String guardiaId, {int dias = 7}) async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await _apiService.getResumenProductividad(guardiaId, dias: dias);
      
      _productividad = ProductividadModel.fromJson(response['productividad']);

      debugPrint('✅ Cargado resumen de productividad para $dias días');
    } catch (e) {
      _setError('Error al cargar productividad: $e');
      debugPrint('❌ Error cargando productividad: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Cargar estadísticas comparativas
  Future<void> cargarEstadisticasComparativas({int dias = 7}) async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await _apiService.getEstadisticasComparativas(dias: dias);
      
      _estadisticasComparativas = response['ranking']
          .map<EstadisticasGuardiaModel>((json) => EstadisticasGuardiaModel.fromJson(json))
          .toList();

      debugPrint('✅ Cargadas estadísticas de ${_estadisticasComparativas.length} guardias');
    } catch (e) {
      _setError('Error al cargar estadísticas comparativas: $e');
      debugPrint('❌ Error cargando estadísticas comparativas: $e');
    } finally {
      _setLoading(false);
    }
  }

  // ==================== MÉTODOS UTILITARIOS ====================

  // Obtener actividades agrupadas por día
  Map<String, List<ActividadModel>> get actividadesAgrupadasPorDia {
    final Map<String, List<ActividadModel>> agrupadas = {};
    
    for (final actividad in _actividades) {
      final fecha = '${actividad.fecha.year}-${actividad.fecha.month.toString().padLeft(2, '0')}-${actividad.fecha.day.toString().padLeft(2, '0')}';
      
      if (!agrupadas.containsKey(fecha)) {
        agrupadas[fecha] = [];
      }
      agrupadas[fecha]!.add(actividad);
    }
    
    return agrupadas;
  }

  // Obtener actividades por tipo
  List<ActividadModel> getActividadesPorTipo(String tipo) {
    return _actividades.where((a) => a.tipoActividad == tipo).toList();
  }

  // Obtener estadísticas rápidas de las actividades cargadas
  Map<String, int> get estadisticasRapidas {
    return {
      'total': _actividades.length,
      'sesiones_iniciadas': getActividadesPorTipo('sesion_iniciada').length,
      'sesiones_finalizadas': getActividadesPorTipo('sesion_finalizada').length,
      'registros_entrada': getActividadesPorTipo('registro_entrada').length,
      'registros_salida': getActividadesPorTipo('registro_salida').length,
      'autorizaciones_manuales': getActividadesPorTipo('autorizacion_manual').length,
      'denegaciones': getActividadesPorTipo('denegacion_acceso').length,
    };
  }

  // Aplicar filtros y recargar
  Future<void> aplicarFiltros({
    DateTime? fechaInicio,
    DateTime? fechaFin,
    String? guardiaId,
    String? tipoActividad,
    String? puntoControl,
  }) async {
    setFiltroFecha(fechaInicio, fechaFin);
    setFiltroGuardia(guardiaId);
    setFiltroTipoActividad(tipoActividad);
    setFiltroPuntoControl(puntoControl);
    
    await cargarHistorialActividades();
  }

  // Refrescar todos los datos
  Future<void> refresh() async {
    await cargarHistorialActividades();
  }

  // Limpiar todos los datos
  void limpiarDatos() {
    _actividades = [];
    _actividadesHoy = [];
    _actividadesSemana = [];
    _productividad = null;
    _estadisticasComparativas = [];
    _resumenHoy = {};
    _errorMessage = null;
    notifyListeners();
  }
}