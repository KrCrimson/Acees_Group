import 'package:flutter/foundation.dart';
import '../models/guard_report_model.dart';
import '../models/asistencia_model.dart';
import '../services/guard_reports_service.dart';

class GuardReportsViewModel extends ChangeNotifier {
  final GuardReportsService _guardReportsService = GuardReportsService();

  // Estado
  bool _isLoading = false;
  String? _errorMessage;
  DateTime _fechaInicio = DateTime.now().subtract(Duration(days: 7));
  DateTime _fechaFin = DateTime.now();

  // Datos
  GuardActivitySummaryModel? _resumenActividad;
  List<GuardReportModel> _rankingGuardias = [];
  Map<int, int> _actividadSemanal = {};
  Map<String, int> _topPuertas = {};
  Map<String, int> _topFacultades = {};
  List<AsistenciaModel> _autorizacionesManuales = [];

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DateTime get fechaInicio => _fechaInicio;
  DateTime get fechaFin => _fechaFin;
  GuardActivitySummaryModel? get resumenActividad => _resumenActividad;
  List<GuardReportModel> get rankingGuardias => _rankingGuardias;
  Map<int, int> get actividadSemanal => _actividadSemanal;
  Map<String, int> get topPuertas => _topPuertas;
  Map<String, int> get topFacultades => _topFacultades;
  List<AsistenciaModel> get autorizacionesManuales => _autorizacionesManuales;

  // Cargar todos los datos de reportes de guardias
  Future<void> loadAllGuardReports() async {
    _setLoading(true);
    _clearError();

    try {
      await Future.wait([
        _loadResumenActividad(),
        _loadRankingGuardias(),
        _loadActividadSemanal(),
        _loadTopPuertas(),
        _loadTopFacultades(),
      ]);
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  // Cargar resumen de actividad
  Future<void> _loadResumenActividad() async {
    try {
      _resumenActividad = await _guardReportsService.getGuardActivitySummary(
        _fechaInicio,
        _fechaFin,
      );
    } catch (e) {
      // Si falla el servicio, usar datos locales
      _resumenActividad = null;
    }
  }

  // Cargar ranking de guardias
  Future<void> _loadRankingGuardias() async {
    try {
      _rankingGuardias = await _guardReportsService.getGuardRanking(
        _fechaInicio,
        _fechaFin,
        limit: 50,
      );
    } catch (e) {
      // Si falla el servicio, usar datos locales
      _rankingGuardias = [];
    }
  }

  // Cargar actividad semanal
  Future<void> _loadActividadSemanal() async {
    try {
      _actividadSemanal = await _guardReportsService.getGuardActivityByWeekday(
        _fechaInicio,
        _fechaFin,
      );
    } catch (e) {
      // Si falla el servicio, usar datos locales
      _actividadSemanal = {};
    }
  }

  // Cargar top puertas
  Future<void> _loadTopPuertas() async {
    try {
      _topPuertas = await _guardReportsService.getTopGates(
        _fechaInicio,
        _fechaFin,
        limit: 10,
      );
    } catch (e) {
      // Si falla el servicio, usar datos locales
      _topPuertas = {};
    }
  }

  // Cargar top facultades
  Future<void> _loadTopFacultades() async {
    try {
      _topFacultades = await _guardReportsService.getTopFaculties(
        _fechaInicio,
        _fechaFin,
        limit: 10,
      );
    } catch (e) {
      // Si falla el servicio, usar datos locales
      _topFacultades = {};
    }
  }

  // Cargar autorizaciones manuales de un guardia específico
  Future<void> loadAutorizacionesManuales(String guardiaId) async {
    _setLoading(true);
    _clearError();

    try {
      _autorizacionesManuales = await _guardReportsService.getGuardManualAuthorizations(
        guardiaId,
        _fechaInicio,
        _fechaFin,
      );
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  // Actualizar rango de fechas
  void updateDateRange(DateTime fechaInicio, DateTime fechaFin) {
    _fechaInicio = fechaInicio;
    _fechaFin = fechaFin;
    notifyListeners();
  }

  // Obtener reporte detallado de un guardia
  Future<GuardReportModel?> getGuardDetailedReport(String guardiaId) async {
    try {
      return await _guardReportsService.getGuardDetailedReport(
        guardiaId,
        _fechaInicio,
        _fechaFin,
      );
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  // Exportar reporte a CSV
  Future<String?> exportToCSV(String guardiaId) async {
    try {
      return await _guardReportsService.exportGuardReportToCSV(
        _fechaInicio,
        _fechaFin,
        guardiaId,
      );
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  // Generar reporte PDF
  Future<List<int>?> generatePDF(String guardiaId) async {
    try {
      return await _guardReportsService.generateGuardReportPDF(
        _fechaInicio,
        _fechaFin,
        guardiaId,
      );
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  // Filtros y análisis locales (fallback cuando el servicio no está disponible)

  // Obtener guardias con más autorizaciones manuales
  List<GuardReportModel> getGuardiasConMasAutorizaciones({int limit = 10}) {
    final guardiasConAutorizaciones = _rankingGuardias
        .where((guardia) => guardia.autorizacionesManuales > 0)
        .toList();
    
    guardiasConAutorizaciones.sort((a, b) => 
        b.autorizacionesManuales.compareTo(a.autorizacionesManuales));
    
    return guardiasConAutorizaciones.take(limit).toList();
  }

  // Obtener guardias con mayor actividad
  List<GuardReportModel> getGuardiasConMayorActividad({int limit = 10}) {
    final guardiasOrdenados = List<GuardReportModel>.from(_rankingGuardias);
    guardiasOrdenados.sort((a, b) => 
        b.totalAsistencias.compareTo(a.totalAsistencias));
    
    return guardiasOrdenados.take(limit).toList();
  }

  // Obtener guardias con menor actividad
  List<GuardReportModel> getGuardiasConMenorActividad({int limit = 10}) {
    final guardiasOrdenados = List<GuardReportModel>.from(_rankingGuardias);
    guardiasOrdenados.sort((a, b) => 
        a.totalAsistencias.compareTo(b.totalAsistencias));
    
    return guardiasOrdenados.take(limit).toList();
  }

  // Obtener estadísticas de autorizaciones manuales
  Map<String, dynamic> getEstadisticasAutorizaciones() {
    if (_rankingGuardias.isEmpty) {
      return {
        'totalAutorizaciones': 0,
        'promedioPorGuardia': 0.0,
        'guardiasConAutorizaciones': 0,
        'porcentajeGuardiasConAutorizaciones': 0.0,
      };
    }

    final totalAutorizaciones = _rankingGuardias
        .fold(0, (sum, guardia) => sum + guardia.autorizacionesManuales);
    
    final guardiasConAutorizaciones = _rankingGuardias
        .where((guardia) => guardia.autorizacionesManuales > 0)
        .length;
    
    final promedioPorGuardia = totalAutorizaciones / _rankingGuardias.length;
    final porcentajeGuardiasConAutorizaciones = 
        (guardiasConAutorizaciones / _rankingGuardias.length) * 100;

    return {
      'totalAutorizaciones': totalAutorizaciones,
      'promedioPorGuardia': promedioPorGuardia,
      'guardiasConAutorizaciones': guardiasConAutorizaciones,
      'porcentajeGuardiasConAutorizaciones': porcentajeGuardiasConAutorizaciones,
    };
  }

  // Obtener distribución de niveles de actividad
  Map<String, int> getDistribucionNivelesActividad() {
    Map<String, int> distribucion = {
      'Alto': 0,
      'Medio': 0,
      'Bajo': 0,
      'Muy Bajo': 0,
    };

    for (var guardia in _rankingGuardias) {
      distribucion[guardia.nivelActividad] = 
          (distribucion[guardia.nivelActividad] ?? 0) + 1;
    }

    return distribucion;
  }

  // Obtener distribución de niveles de autorizaciones
  Map<String, int> getDistribucionNivelesAutorizaciones() {
    Map<String, int> distribucion = {
      'Alto': 0,
      'Medio': 0,
      'Bajo': 0,
      'Muy Bajo': 0,
    };

    for (var guardia in _rankingGuardias) {
      distribucion[guardia.nivelAutorizaciones] = 
          (distribucion[guardia.nivelAutorizaciones] ?? 0) + 1;
    }

    return distribucion;
  }

  // Métodos privados
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
