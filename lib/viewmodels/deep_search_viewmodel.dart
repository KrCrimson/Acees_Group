import 'package:flutter/foundation.dart';
import '../models/decision_manual_model.dart';
import '../services/api_service.dart';
import '../constants/academic_data.dart';

class DeepSearchViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<DecisionManualModel> _allDecisions = [];
  List<DecisionManualModel> _filteredDecisions = [];
  bool _isLoading = false;
  
  // Filtros
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedFacultySiglas;
  String? _selectedSchoolSiglas;
  String _searchQuery = '';

  // Getters
  List<DecisionManualModel> get decisions => _filteredDecisions;
  bool get isLoading => _isLoading;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  String? get selectedFacultySiglas => _selectedFacultySiglas;
  String? get selectedSchoolSiglas => _selectedSchoolSiglas;
  
  // Listas para dropdowns
  List<Map<String, String>> get facultades => AcademicData.facultades;
  List<Map<String, String>> get escuelasDisponibles {
    if (_selectedFacultySiglas == null) return [];
    return AcademicData.getEscuelasPorFacultad(_selectedFacultySiglas!);
  }

  Future<void> loadFullHistory() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Cargar TODO el historial sin filtros de tiempo del backend
      // Asumimos que getAllAsistencias trae todo. Si no, habría que revisar el servicio.
      final asistencias = await _apiService.getAllAsistencias();
      
      _allDecisions = asistencias.map((a) => DecisionManualModel(
        id: a.id,
        estudianteId: a.codigoUniversitario,
        estudianteDni: a.dni,
        estudianteNombre: '${a.nombre} ${a.apellido}',
        tipoAcceso: a.tipo,
        puntoControl: a.puerta,
        guardiaId: a.guardiaId ?? '',
        guardiaNombre: a.guardiaNombre ?? '',
        autorizado: a.estado == 'autorizado',
        razon: a.razonDecision ?? '',
        timestamp: a.fechaHora,
        datosEstudiante: {
          'facultad': a.siglasFacultad,
          'escuela': a.siglasEscuela,
        }
      )).toList();

      // Ordenar por fecha descendente
      _allDecisions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      _applyFilters();
    } catch (e) {
      debugPrint('Error loading history: $e');
      _allDecisions = [];
      _filteredDecisions = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setDateRange(DateTime? start, DateTime? end) {
    _startDate = start;
    _endDate = end;
    _applyFilters();
  }

  void setFaculty(String? facultySiglas) {
    _selectedFacultySiglas = facultySiglas;
    _selectedSchoolSiglas = null; // Reset escuela al cambiar facultad
    _applyFilters();
  }

  void setSchool(String? schoolSiglas) {
    _selectedSchoolSiglas = schoolSiglas;
    _applyFilters();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  void clearFilters() {
    _startDate = null;
    _endDate = null;
    _selectedFacultySiglas = null;
    _selectedSchoolSiglas = null;
    _searchQuery = '';
    _applyFilters();
  }

  void _applyFilters() {
    _filteredDecisions = _allDecisions.where((d) {
      // Filtro de Fecha
      if (_startDate != null) {
        if (d.timestamp.isBefore(_startDate!)) return false;
      }
      if (_endDate != null) {
        final endOfDay = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
        if (d.timestamp.isAfter(endOfDay)) return false;
      }

      // Filtro de Facultad
      if (_selectedFacultySiglas != null) {
        // Asumimos que los datos del estudiante tienen las siglas correctas
        // Ojo: El modelo DecisionManualModel debe tener acceso a estos datos.
        // En el mapeo arriba los guardé en datosEstudiante
        final fac = d.datosEstudiante?['facultad'];
        if (fac != _selectedFacultySiglas) return false;
      }

      // Filtro de Escuela
      if (_selectedSchoolSiglas != null) {
        final esc = d.datosEstudiante?['escuela'];
        // A veces las siglas pueden variar (mayúsculas/minúsculas), normalizamos
        if (esc?.toUpperCase() != _selectedSchoolSiglas?.toUpperCase()) return false;
      }

      // Búsqueda de texto
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchNombre = d.estudianteNombre.toLowerCase().contains(q);
        final matchDni = d.estudianteDni.contains(q);
        if (!matchNombre && !matchDni) return false;
      }

      return true;
    }).toList();

    notifyListeners();
  }
}
