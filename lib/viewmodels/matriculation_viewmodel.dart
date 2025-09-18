import 'package:flutter/foundation.dart';
import '../models/matriculation_model.dart';
import '../services/matriculation_service.dart';
import '../services/hybrid_api_service.dart';

class MatriculationViewModel extends ChangeNotifier {
  final MatriculationService _matriculationService = MatriculationService();
  final HybridApiService _hybridApiService = HybridApiService();

  // Estado
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Datos
  MatriculationModel? _currentMatriculation;
  List<MatriculationModel> _searchResults = [];
  List<MatriculationModel> _matriculasPorVencer = [];
  List<MatriculationModel> _matriculasVencidas = [];
  List<MatriculationModel> _matriculasPendientePago = [];
  Map<String, dynamic> _estadisticas = {};
  List<Map<String, dynamic>> _alertas = [];

  // Filtros
  String _selectedCiclo = '';
  String _selectedAnio = '';
  String _selectedEstado = '';
  String _selectedFacultad = '';

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  MatriculationModel? get currentMatriculation => _currentMatriculation;
  List<MatriculationModel> get searchResults => _searchResults;
  List<MatriculationModel> get matriculasPorVencer => _matriculasPorVencer;
  List<MatriculationModel> get matriculasVencidas => _matriculasVencidas;
  List<MatriculationModel> get matriculasPendientePago => _matriculasPendientePago;
  Map<String, dynamic> get estadisticas => _estadisticas;
  List<Map<String, dynamic>> get alertas => _alertas;

  // Filtros
  String get selectedCiclo => _selectedCiclo;
  String get selectedAnio => _selectedAnio;
  String get selectedEstado => _selectedEstado;
  String get selectedFacultad => _selectedFacultad;

  // Verificar vigencia de matrícula por código universitario
  Future<void> verificarVigenciaMatricula(String codigoUniversitario) async {
    _setLoading(true);
    _clearMessages();

    try {
      _currentMatriculation = await _matriculationService.verificarVigenciaMatricula(codigoUniversitario);
      _setSuccess('Matrícula verificada exitosamente');
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  // Verificar vigencia de matrícula por DNI
  Future<void> verificarVigenciaMatriculaByDni(String dni) async {
    _setLoading(true);
    _clearMessages();

    try {
      _currentMatriculation = await _matriculationService.verificarVigenciaMatriculaByDni(dni);
      _setSuccess('Matrícula verificada exitosamente');
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  // Buscar matrículas
  Future<void> buscarMatriculas({
    String? codigoUniversitario,
    String? dni,
    String? nombre,
    String? cicloAcademico,
    String? estadoMatricula,
    String? siglasFacultad,
  }) async {
    _setLoading(true);
    _clearMessages();

    try {
      _searchResults = await _matriculationService.buscarMatriculas(
        codigoUniversitario: codigoUniversitario,
        dni: dni,
        nombre: nombre,
        cicloAcademico: cicloAcademico,
        estadoMatricula: estadoMatricula,
        siglasFacultad: siglasFacultad,
      );
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  // Cargar matrículas por vencer
  Future<void> loadMatriculasPorVencer({int dias = 30}) async {
    _setLoading(true);
    _clearMessages();

    try {
      _matriculasPorVencer = await _matriculationService.getMatriculasPorVencer(dias: dias);
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  // Cargar matrículas vencidas
  Future<void> loadMatriculasVencidas() async {
    _setLoading(true);
    _clearMessages();

    try {
      _matriculasVencidas = await _matriculationService.getMatriculasVencidas();
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  // Cargar matrículas pendientes de pago
  Future<void> loadMatriculasPendientePago() async {
    _setLoading(true);
    _clearMessages();

    try {
      _matriculasPendientePago = await _matriculationService.getMatriculasPendientePago();
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  // Cargar estadísticas
  Future<void> loadEstadisticas() async {
    _setLoading(true);
    _clearMessages();

    try {
      _estadisticas = await _matriculationService.getEstadisticasMatriculas();
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  // Cargar alertas
  Future<void> loadAlertas() async {
    _setLoading(true);
    _clearMessages();

    try {
      _alertas = await _matriculationService.getAlertasMatricula();
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  // Obtener historial de matrículas del estudiante actual
  Future<List<MatriculationModel>> getHistorialMatriculas() async {
    if (_currentMatriculation == null) return [];

    try {
      return await _matriculationService.getHistorialMatriculas(_currentMatriculation!.codigoUniversitario);
    } catch (e) {
      _setError('Error al obtener historial: $e');
      return [];
    }
  }

  // Obtener resumen de matrícula del estudiante actual
  Future<Map<String, dynamic>> getResumenMatricula() async {
    if (_currentMatriculation == null) return {};

    try {
      return await _matriculationService.getResumenMatricula(_currentMatriculation!.codigoUniversitario);
    } catch (e) {
      _setError('Error al obtener resumen: $e');
      return {};
    }
  }

  // Validar acceso basado en matrícula
  Future<Map<String, dynamic>> validarAccesoMatricula() async {
    if (_currentMatriculation == null) return {};

    try {
      return await _matriculationService.validarAccesoMatricula(_currentMatriculation!.codigoUniversitario);
    } catch (e) {
      _setError('Error al validar acceso: $e');
      return {};
    }
  }

  // Aplicar filtros
  void aplicarFiltros() {
    buscarMatriculas(
      cicloAcademico: _selectedCiclo.isNotEmpty ? _selectedCiclo : null,
      estadoMatricula: _selectedEstado.isNotEmpty ? _selectedEstado : null,
      siglasFacultad: _selectedFacultad.isNotEmpty ? _selectedFacultad : null,
    );
  }

  // Actualizar filtros
  void updateCiclo(String ciclo) {
    _selectedCiclo = ciclo;
    notifyListeners();
  }

  void updateAnio(String anio) {
    _selectedAnio = anio;
    notifyListeners();
  }

  void updateEstado(String estado) {
    _selectedEstado = estado;
    notifyListeners();
  }

  void updateFacultad(String facultad) {
    _selectedFacultad = facultad;
    notifyListeners();
  }

  // Limpiar filtros
  void limpiarFiltros() {
    _selectedCiclo = '';
    _selectedAnio = '';
    _selectedEstado = '';
    _selectedFacultad = '';
    _searchResults = [];
    notifyListeners();
  }

  // Obtener matrículas filtradas por estado
  List<MatriculationModel> getMatriculasByEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'vigentes':
        return _searchResults.where((m) => m.isVigente).toList();
      case 'vencidas':
        return _searchResults.where((m) => m.isVencida).toList();
      case 'por_vencer':
        return _searchResults.where((m) => m.isPorVencer).toList();
      case 'pendiente_pago':
        return _searchResults.where((m) => m.isPendientePago).toList();
      case 'suspendidas':
        return _searchResults.where((m) => m.isSuspendida).toList();
      case 'canceladas':
        return _searchResults.where((m) => m.isCancelada).toList();
      default:
        return _searchResults;
    }
  }

  // Obtener matrículas filtradas por facultad
  List<MatriculationModel> getMatriculasByFacultad(String facultad) {
    return _searchResults.where((m) => m.codigoUniversitario.contains(facultad)).toList();
  }

  // Obtener estadísticas de búsqueda
  Map<String, int> getSearchStatistics() {
    return {
      'total_resultados': _searchResults.length,
      'vigentes': _searchResults.where((m) => m.isVigente).length,
      'vencidas': _searchResults.where((m) => m.isVencida).length,
      'por_vencer': _searchResults.where((m) => m.isPorVencer).length,
      'pendiente_pago': _searchResults.where((m) => m.isPendientePago).length,
      'suspendidas': _searchResults.where((m) => m.isSuspendida).length,
      'canceladas': _searchResults.where((m) => m.isCancelada).length,
    };
  }

  // Verificar si una matrícula puede acceder
  bool canMatriculationAccess(String codigoUniversitario) {
    if (_currentMatriculation == null) return false;
    return _currentMatriculation!.puedeAcceder;
  }

  // Obtener recomendación de acceso
  String getRecommendedAccess() {
    if (_currentMatriculation == null) return 'No hay matrícula seleccionada';
    return _currentMatriculation!.recomendacionAcceso;
  }

  // Obtener alertas de la matrícula actual
  List<String> getCurrentMatriculationAlerts() {
    if (_currentMatriculation == null) return [];
    return _currentMatriculation!.alertas;
  }

  // Obtener resumen de la matrícula actual
  Map<String, dynamic> getCurrentMatriculationSummary() {
    if (_currentMatriculation == null) return {};
    return _currentMatriculation!.resumenValidacion;
  }

  // Obtener información detallada de la matrícula actual
  Map<String, dynamic> getCurrentMatriculationDetails() {
    if (_currentMatriculation == null) return {};
    return _currentMatriculation!.informacionDetallada;
  }

  // Limpiar estado actual
  void clearCurrentMatriculation() {
    _currentMatriculation = null;
    _clearMessages();
    notifyListeners();
  }

  // Limpiar resultados de búsqueda
  void clearSearchResults() {
    _searchResults = [];
    notifyListeners();
  }

  // Obtener matrículas con alertas
  List<MatriculationModel> getMatriculasConAlertas() {
    return _searchResults.where((m) => m.tieneAlertas).toList();
  }

  // Obtener matrículas que pueden acceder
  List<MatriculationModel> getMatriculasQuePuedenAcceder() {
    return _searchResults.where((m) => m.puedeAcceder).toList();
  }

  // Obtener matrículas que no pueden acceder
  List<MatriculationModel> getMatriculasQueNoPuedenAcceder() {
    return _searchResults.where((m) => !m.puedeAcceder).toList();
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
