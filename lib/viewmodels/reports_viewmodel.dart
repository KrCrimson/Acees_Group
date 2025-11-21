import 'package:flutter/foundation.dart';
import '../models/asistencia_model.dart';
import '../models/facultad_escuela_model.dart';
import '../models/alumno_model.dart';
import '../services/api_service.dart';

class ReportsViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<AsistenciaModel> _asistencias = [];
  List<FacultadModel> _facultades = [];
  List<EscuelaModel> _escuelas = [];
  List<AlumnoModel> _alumnos = [];

  bool _isLoading = false;
  String? _errorMessage;

  // Filtros para Asistencias
  String _asistenciaSearchQuery = '';
  String? _selectedFacultadFilter;
  String? _selectedEscuelaFilter;
  String? _selectedTipoFilter;

  // Filtros para Estudiantes
  String _estudianteSearchQuery = '';
  String? _selectedFacultadFilterEst;
  String? _selectedEscuelaFilterEst;
  String? _selectedEstadoFilter;

  // Getters
  List<AsistenciaModel> get asistencias => _asistencias;
  List<FacultadModel> get facultades => _facultades;
  List<EscuelaModel> get escuelas => _escuelas;
  List<AlumnoModel> get alumnos => _alumnos;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Getters de filtros - Asistencias
  String? get selectedFacultadFilter => _selectedFacultadFilter;
  String? get selectedEscuelaFilter => _selectedEscuelaFilter;
  String? get selectedTipoFilter => _selectedTipoFilter;
  bool get hasAsistenciaFilters => _asistenciaSearchQuery.isNotEmpty || _selectedFacultadFilter != null || _selectedEscuelaFilter != null || _selectedTipoFilter != null;

  // Getters de filtros - Estudiantes
  String? get selectedFacultadFilterEst => _selectedFacultadFilterEst;
  String? get selectedEscuelaFilterEst => _selectedEscuelaFilterEst;
  String? get selectedEstadoFilter => _selectedEstadoFilter;
  bool get hasEstudianteFilters => _estudianteSearchQuery.isNotEmpty || _selectedFacultadFilterEst != null || _selectedEscuelaFilterEst != null || _selectedEstadoFilter != null;

  // Listas filtradas
  List<AsistenciaModel> get filteredAsistencias {
    var filtered = _asistencias;
    
    if (_asistenciaSearchQuery.isNotEmpty) {
      filtered = filtered.where((a) =>
        a.nombreCompleto.toLowerCase().contains(_asistenciaSearchQuery.toLowerCase()) ||
        a.codigoUniversitario.toLowerCase().contains(_asistenciaSearchQuery.toLowerCase())
      ).toList();
    }
    
    if (_selectedFacultadFilter != null) {
      filtered = filtered.where((a) => a.siglasFacultad == _selectedFacultadFilter).toList();
    }
    
    if (_selectedEscuelaFilter != null) {
      filtered = filtered.where((a) => a.siglasEscuela == _selectedEscuelaFilter).toList();
    }
    
    if (_selectedTipoFilter != null) {
      filtered = filtered.where((a) => a.entradaTipo.toLowerCase().contains(_selectedTipoFilter!.toLowerCase())).toList();
    }
    
    return filtered;
  }

  List<AlumnoModel> get filteredEstudiantes {
    var filtered = _alumnos;
    
    if (_estudianteSearchQuery.isNotEmpty) {
      filtered = filtered.where((a) =>
        a.nombreCompleto.toLowerCase().contains(_estudianteSearchQuery.toLowerCase()) ||
        a.codigoUniversitario.toLowerCase().contains(_estudianteSearchQuery.toLowerCase())
      ).toList();
    }
    
    if (_selectedFacultadFilterEst != null) {
      filtered = filtered.where((a) => a.siglasFacultad == _selectedFacultadFilterEst).toList();
    }
    
    if (_selectedEscuelaFilterEst != null) {
      filtered = filtered.where((a) => a.siglasEscuela == _selectedEscuelaFilterEst).toList();
    }
    
    if (_selectedEstadoFilter != null) {
      final isActive = _selectedEstadoFilter == 'activo';
      filtered = filtered.where((a) => a.isActive == isActive).toList();
    }
    
    return filtered;
  }

  // Cargar todos los datos
  Future<void> loadAllData() async {
    _setLoading(true);
    _clearError();

    try {
      // Cargar datos en paralelo
      final futures = await Future.wait([
        _apiService.getAsistencias(),
        _apiService.getFacultades(),
        _apiService.getEscuelas(),
        _apiService.getAlumnos(),
      ]);

      _asistencias = futures[0] as List<AsistenciaModel>;
      _facultades = futures[1] as List<FacultadModel>;
      _escuelas = futures[2] as List<EscuelaModel>;
      _alumnos = futures[3] as List<AlumnoModel>;

      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  // Cargar solo asistencias
  Future<void> loadAsistencias() async {
    _setLoading(true);
    _clearError();

    try {
      _asistencias = await _apiService.getAsistencias();
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  // Filtros y análisis

  // Asistencias por fecha
  List<AsistenciaModel> getAsistenciasByDate(DateTime date) {
    return _asistencias.where((asistencia) {
      return asistencia.fechaHora.year == date.year &&
          asistencia.fechaHora.month == date.month &&
          asistencia.fechaHora.day == date.day;
    }).toList();
  }

  // Asistencias por rango de fechas
  List<AsistenciaModel> getAsistenciasByDateRange(
    DateTime start,
    DateTime end,
  ) {
    return _asistencias.where((asistencia) {
      return asistencia.fechaHora.isAfter(start) &&
          asistencia.fechaHora.isBefore(end.add(Duration(days: 1)));
    }).toList();
  }

  // Asistencias por facultad
  List<AsistenciaModel> getAsistenciasByFacultad(String siglasFacultad) {
    return _asistencias
        .where((asistencia) => asistencia.siglasFacultad == siglasFacultad)
        .toList();
  }

  // Asistencias por escuela
  List<AsistenciaModel> getAsistenciasByEscuela(String siglasEscuela) {
    return _asistencias
        .where((asistencia) => asistencia.siglasEscuela == siglasEscuela)
        .toList();
  }

  // Estadísticas

  // Total asistencias hoy
  int getTotalAsistenciasHoy() {
    final hoy = DateTime.now();
    return getAsistenciasByDate(hoy).length;
  }

  // Total asistencias esta semana
  int getTotalAsistenciasEstaSemana() {
    final ahora = DateTime.now();
    final inicioSemana = ahora.subtract(Duration(days: ahora.weekday - 1));
    return getAsistenciasByDateRange(inicioSemana, ahora).length;
  }

  // Asistencias por hora del día
  Map<int, int> getAsistenciasPorHora() {
    Map<int, int> asistenciasPorHora = {};

    for (var asistencia in _asistencias) {
      int hora = asistencia.fechaHora.hour;
      asistenciasPorHora[hora] = (asistenciasPorHora[hora] ?? 0) + 1;
    }

    return asistenciasPorHora;
  }

  // Top facultades con más asistencias
  List<MapEntry<String, int>> getTopFacultades({int limit = 5}) {
    Map<String, int> asistenciasPorFacultad = {};

    for (var asistencia in _asistencias) {
      asistenciasPorFacultad[asistencia.siglasFacultad] =
          (asistenciasPorFacultad[asistencia.siglasFacultad] ?? 0) + 1;
    }

    var sorted =
        asistenciasPorFacultad.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(limit).toList();
  }

  // Top escuelas con más asistencias
  List<MapEntry<String, int>> getTopEscuelas({int limit = 5}) {
    Map<String, int> asistenciasPorEscuela = {};
    for (var asistencia in _asistencias) {
      asistenciasPorEscuela[asistencia.siglasEscuela] = (asistenciasPorEscuela[asistencia.siglasEscuela] ?? 0) + 1;
    }
    var sorted = asistenciasPorEscuela.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).toList();
  }

  // Entradas vs Salidas - Usando endpoint del backend
  Future<Map<String, int>> getEntradasVsSalidas() async {
    try {
      final response = await _apiService.getEntradasVsSalidasHoy();
      return {
        'entradas': response['entradas'] ?? 0,
        'salidas': response['salidas'] ?? 0,
      };
    } catch (e) {
      print('Error obteniendo entradas vs salidas: $e');
      return {'entradas': 0, 'salidas': 0};
    }
  }

  // Tendencia semanal
  List<Map<String, dynamic>> getTendenciaSemanal() {
    final ahora = DateTime.now();
    List<Map<String, dynamic>> tendencia = [];
    for (int i = 6; i >= 0; i--) {
      final dia = ahora.subtract(Duration(days: i));
      final count = getAsistenciasByDate(dia).length;
      tendencia.add({
        'label': ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'][dia.weekday % 7],
        'count': count,
      });
    }
    return tendencia;
  }

  // Top estudiantes más activos
  List<Map<String, dynamic>> getTopEstudiantes({int limit = 10}) {
    Map<String, int> asistenciasPorEstudiante = {};
    for (var asistencia in _asistencias) {
      asistenciasPorEstudiante[asistencia.nombreCompleto] = (asistenciasPorEstudiante[asistencia.nombreCompleto] ?? 0) + 1;
    }
    var sorted = asistenciasPorEstudiante.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((e) => {'nombre': e.key, 'count': e.value}).toList();
  }

  // Comparativa mensual
  List<Map<String, dynamic>> getComparativaMensual() {
    final ahora = DateTime.now();
    List<Map<String, dynamic>> comparativa = [];
    for (int i = 2; i >= 0; i--) {
      final mes = DateTime(ahora.year, ahora.month - i, 1);
      final siguienteMes = DateTime(ahora.year, ahora.month - i + 1, 1);
      final count = getAsistenciasByDateRange(mes, siguienteMes).length;
      comparativa.add({
        'mes': ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'][mes.month - 1],
        'count': count,
      });
    }
    return comparativa;
  }

  // Métodos de filtrado - Asistencias
  void setAsistenciaSearchQuery(String query) {
    _asistenciaSearchQuery = query;
    notifyListeners();
  }

  void setFacultadFilter(String? facultad) {
    _selectedFacultadFilter = facultad;
    notifyListeners();
  }

  void setEscuelaFilter(String? escuela) {
    _selectedEscuelaFilter = escuela;
    notifyListeners();
  }

  void setTipoFilter(String? tipo) {
    _selectedTipoFilter = tipo;
    notifyListeners();
  }

  void clearAsistenciaFilters() {
    _asistenciaSearchQuery = '';
    _selectedFacultadFilter = null;
    _selectedEscuelaFilter = null;
    _selectedTipoFilter = null;
    notifyListeners();
  }

  // Métodos de filtrado - Estudiantes
  void setEstudianteSearchQuery(String query) {
    _estudianteSearchQuery = query;
    notifyListeners();
  }

  void setFacultadFilterEst(String? facultad) {
    _selectedFacultadFilterEst = facultad;
    notifyListeners();
  }

  void setEscuelaFilterEst(String? escuela) {
    _selectedEscuelaFilterEst = escuela;
    notifyListeners();
  }

  void setEstadoFilter(String? estado) {
    _selectedEstadoFilter = estado;
    notifyListeners();
  }

  void clearEstudianteFilters() {
    _estudianteSearchQuery = '';
    _selectedFacultadFilterEst = null;
    _selectedEscuelaFilterEst = null;
    _selectedEstadoFilter = null;
    notifyListeners();
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
