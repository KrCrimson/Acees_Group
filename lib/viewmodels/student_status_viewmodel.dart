import 'package:flutter/foundation.dart';
import '../models/student_status_model.dart';
import '../models/alumno_model.dart';
import '../services/student_status_service.dart';
import '../services/hybrid_api_service.dart';

class StudentStatusViewModel extends ChangeNotifier {
  final StudentStatusService _studentStatusService = StudentStatusService();
  final HybridApiService _hybridApiService = HybridApiService();

  // Estado
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Datos
  StudentStatusModel? _currentStudentStatus;
  List<AlumnoModel> _searchResults = [];
  List<AlumnoModel> _recentStudents = [];
  List<AlumnoModel> _studentsWithAlerts = [];
  String _lastSearchQuery = '';

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  StudentStatusModel? get currentStudentStatus => _currentStudentStatus;
  List<AlumnoModel> get searchResults => _searchResults;
  List<AlumnoModel> get recentStudents => _recentStudents;
  List<AlumnoModel> get studentsWithAlerts => _studentsWithAlerts;
  String get lastSearchQuery => _lastSearchQuery;

  // Consultar estado del estudiante por código universitario
  Future<void> getStudentStatus(String codigoUniversitario) async {
    _setLoading(true);
    _clearMessages();

    try {
      _currentStudentStatus = await _studentStatusService.getStudentStatus(codigoUniversitario);
      _setSuccess('Estado del estudiante obtenido exitosamente');
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  // Consultar estado del estudiante por DNI
  Future<void> getStudentStatusByDni(String dni) async {
    _setLoading(true);
    _clearMessages();

    try {
      _currentStudentStatus = await _studentStatusService.getStudentStatusByDni(dni);
      _setSuccess('Estado del estudiante obtenido exitosamente');
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  // Buscar estudiantes
  Future<void> searchStudents(String query) async {
    if (query.trim().isEmpty) {
      _searchResults = [];
      _lastSearchQuery = '';
      notifyListeners();
      return;
    }

    _setLoading(true);
    _clearMessages();

    try {
      _searchResults = await _studentStatusService.searchStudents(query);
      _lastSearchQuery = query;
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  // Cargar estudiantes recientes
  Future<void> loadRecentStudents() async {
    _setLoading(true);
    _clearMessages();

    try {
      _recentStudents = await _studentStatusService.getRecentStudents();
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  // Cargar estudiantes con alertas
  Future<void> loadStudentsWithAlerts() async {
    _setLoading(true);
    _clearMessages();

    try {
      _studentsWithAlerts = await _studentStatusService.getStudentsWithAlerts();
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  // Obtener historial de asistencias del estudiante actual
  Future<List<AsistenciaModel>> getStudentAttendanceHistory({
    DateTime? fechaInicio,
    DateTime? fechaFin,
    int limit = 50,
  }) async {
    if (_currentStudentStatus == null) return [];

    try {
      return await _studentStatusService.getStudentAttendanceHistory(
        _currentStudentStatus!.codigoUniversitario,
        fechaInicio: fechaInicio,
        fechaFin: fechaFin,
        limit: limit,
      );
    } catch (e) {
      _setError('Error al obtener historial: $e');
      return [];
    }
  }

  // Obtener estadísticas del estudiante actual
  Future<Map<String, dynamic>> getStudentStatistics({
    DateTime? fechaInicio,
    DateTime? fechaFin,
  }) async {
    if (_currentStudentStatus == null) return {};

    try {
      return await _studentStatusService.getStudentStatistics(
        _currentStudentStatus!.codigoUniversitario,
        fechaInicio: fechaInicio,
        fechaFin: fechaFin,
      );
    } catch (e) {
      _setError('Error al obtener estadísticas: $e');
      return {};
    }
  }

  // Obtener alertas del estudiante actual
  Future<Map<String, dynamic>> getStudentAlerts() async {
    if (_currentStudentStatus == null) return {};

    try {
      return await _studentStatusService.getStudentAlerts(
        _currentStudentStatus!.codigoUniversitario,
      );
    } catch (e) {
      _setError('Error al obtener alertas: $e');
      return {};
    }
  }

  // Obtener resumen ejecutivo del estudiante actual
  Future<Map<String, dynamic>> getStudentExecutiveSummary() async {
    if (_currentStudentStatus == null) return {};

    try {
      return await _studentStatusService.getStudentExecutiveSummary(
        _currentStudentStatus!.codigoUniversitario,
      );
    } catch (e) {
      _setError('Error al obtener resumen: $e');
      return {};
    }
  }

  // Obtener patrones de asistencia del estudiante actual
  Future<Map<String, dynamic>> getStudentAttendancePatterns() async {
    if (_currentStudentStatus == null) return {};

    try {
      return await _studentStatusService.getStudentAttendancePatterns(
        _currentStudentStatus!.codigoUniversitario,
      );
    } catch (e) {
      _setError('Error al obtener patrones: $e');
      return {};
    }
  }

  // Obtener reporte detallado del estudiante actual
  Future<Map<String, dynamic>> getStudentDetailedReport({
    DateTime? fechaInicio,
    DateTime? fechaFin,
  }) async {
    if (_currentStudentStatus == null) return {};

    try {
      return await _studentStatusService.getStudentDetailedReport(
        _currentStudentStatus!.codigoUniversitario,
        fechaInicio: fechaInicio,
        fechaFin: fechaFin,
      );
    } catch (e) {
      _setError('Error al obtener reporte: $e');
      return {};
    }
  }

  // Seleccionar estudiante de los resultados de búsqueda
  void selectStudent(AlumnoModel estudiante) {
    _currentStudentStatus = null;
    notifyListeners();
  }

  // Limpiar estado actual
  void clearCurrentStudent() {
    _currentStudentStatus = null;
    _clearMessages();
    notifyListeners();
  }

  // Limpiar resultados de búsqueda
  void clearSearchResults() {
    _searchResults = [];
    _lastSearchQuery = '';
    notifyListeners();
  }

  // Obtener estudiantes filtrados por estado
  List<AlumnoModel> getStudentsByStatus(String status) {
    switch (status.toLowerCase()) {
      case 'activos':
        return _searchResults.where((s) => s.isActive).toList();
      case 'inactivos':
        return _searchResults.where((s) => !s.isActive).toList();
      case 'recientes':
        return _recentStudents;
      case 'alertas':
        return _studentsWithAlerts;
      default:
        return _searchResults;
    }
  }

  // Obtener estudiantes filtrados por facultad
  List<AlumnoModel> getStudentsByFaculty(String facultad) {
    return _searchResults.where((s) => s.siglasFacultad == facultad).toList();
  }

  // Obtener estudiantes filtrados por escuela
  List<AlumnoModel> getStudentsBySchool(String escuela) {
    return _searchResults.where((s) => s.siglasEscuela == escuela).toList();
  }

  // Obtener estadísticas de búsqueda
  Map<String, int> getSearchStatistics() {
    return {
      'total_resultados': _searchResults.length,
      'activos': _searchResults.where((s) => s.isActive).length,
      'inactivos': _searchResults.where((s) => !s.isActive).length,
      'recientes': _recentStudents.length,
      'con_alertas': _studentsWithAlerts.length,
    };
  }

  // Verificar si un estudiante puede acceder
  bool canStudentAccess(String codigoUniversitario) {
    if (_currentStudentStatus == null) return false;
    return _currentStudentStatus!.puedeAcceder;
  }

  // Obtener próxima acción recomendada
  String getRecommendedAction() {
    if (_currentStudentStatus == null) return 'No hay estudiante seleccionado';
    return _currentStudentStatus!.proximaAccionRecomendada;
  }

  // Obtener resumen del estudiante actual
  Map<String, dynamic> getCurrentStudentSummary() {
    if (_currentStudentStatus == null) return {};
    return _currentStudentStatus!.resumenEjecutivo;
  }

  // Obtener alertas del estudiante actual
  List<String> getCurrentStudentAlerts() {
    if (_currentStudentStatus == null) return [];
    return _currentStudentStatus!.listaAlertas;
  }

  // Obtener estadísticas del estudiante actual
  Map<String, dynamic> getCurrentStudentStats() {
    if (_currentStudentStatus == null) return {};
    return {
      'asistencias_hoy': _currentStudentStatus!.totalAsistenciasHoy,
      'asistencias_semana': _currentStudentStatus!.totalAsistenciasEstaSemana,
      'asistencias_mes': _currentStudentStatus!.totalAsistenciasEsteMes,
      'entradas': _currentStudentStatus!.totalEntradas,
      'salidas': _currentStudentStatus!.totalSalidas,
      'autorizaciones_manuales': _currentStudentStatus!.totalAutorizacionesManuales,
      'decisiones_manuales': _currentStudentStatus!.totalDecisionesManuales,
      'decisiones_autorizadas': _currentStudentStatus!.decisionesAutorizadas,
      'decisiones_rechazadas': _currentStudentStatus!.decisionesRechazadas,
    };
  }

  // Obtener patrones de asistencia del estudiante actual
  Map<String, int> getCurrentStudentAttendancePatterns() {
    if (_currentStudentStatus == null) return {};
    return _currentStudentStatus!.asistenciasPorDiaSemana;
  }

  // Obtener distribución por horas del estudiante actual
  Map<String, int> getCurrentStudentHourlyDistribution() {
    if (_currentStudentStatus == null) return {};
    return _currentStudentStatus!.asistenciasPorHora;
  }

  // Métodos privados
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
