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

  // Getters
  List<AsistenciaModel> get asistencias => _asistencias;
  List<FacultadModel> get facultades => _facultades;
  List<EscuelaModel> get escuelas => _escuelas;
  List<AlumnoModel> get alumnos => _alumnos;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

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
