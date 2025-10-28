import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/student_status_viewmodel.dart';
import '../widgets/status_widgets.dart';

class StudentSearchView extends StatefulWidget {
  @override
  _StudentSearchViewState createState() => _StudentSearchViewState();
}

class _StudentSearchViewState extends State<StudentSearchView> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'todos';
  String _selectedFaculty = 'todas';
  String _selectedSchool = 'todas';

  final List<String> _filters = ['todos', 'activos', 'inactivos', 'recientes', 'alertas'];
  final List<String> _faculties = ['todas', 'FIIS', 'FIC', 'FIM', 'FIA', 'FIE'];
  final List<String> _schools = ['todas', 'Sistemas', 'Computación', 'Mecánica', 'Industrial'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Búsqueda Avanzada'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Filtros
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Column(
              children: [
                // Barra de búsqueda
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre, código o DNI...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) => _performSearch(),
                ),
                SizedBox(height: 16),

                // Filtros
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedFilter,
                        decoration: InputDecoration(
                          labelText: 'Estado',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: _filters.map((filter) {
                          return DropdownMenuItem(
                            value: filter,
                            child: Text(filter.capitalize()),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedFilter = value!;
                          });
                          _performSearch();
                        },
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedFaculty,
                        decoration: InputDecoration(
                          labelText: 'Facultad',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: _faculties.map((faculty) {
                          return DropdownMenuItem(
                            value: faculty,
                            child: Text(faculty.capitalize()),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedFaculty = value!;
                          });
                          _performSearch();
                        },
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedSchool,
                        decoration: InputDecoration(
                          labelText: 'Escuela',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: _schools.map((school) {
                          return DropdownMenuItem(
                            value: school,
                            child: Text(school.capitalize()),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedSchool = value!;
                          });
                          _performSearch();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Resultados
          Expanded(
            child: Consumer<StudentStatusViewModel>(
              builder: (context, studentStatusViewModel, child) {
                if (studentStatusViewModel.isLoading) {
                  return LoadingWidget(message: 'Buscando estudiantes...');
                }

                if (studentStatusViewModel.errorMessage != null) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                      SizedBox(height: 16),
                      Text(studentStatusViewModel.errorMessage!, textAlign: TextAlign.center),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _performSearch,
                        child: Text('Reintentar'),
                      ),
                    ],
                  );
                }

                final filteredResults = _getFilteredResults(studentStatusViewModel);

                if (filteredResults.isEmpty) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                      SizedBox(height: 16),
                      Text(
                        'No se encontraron estudiantes con los filtros aplicados',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    // Estadísticas de búsqueda
                    Container(
                      padding: EdgeInsets.all(16),
                      color: Colors.blue[50],
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildSearchStat('Total', '${filteredResults.length}', Colors.blue),
                          _buildSearchStat('Activos', '${filteredResults.where((s) => s.isActive).length}', Colors.green),
                          _buildSearchStat('Inactivos', '${filteredResults.where((s) => !s.isActive).length}', Colors.red),
                        ],
                      ),
                    ),

                    // Lista de resultados
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: filteredResults.length,
                        itemBuilder: (context, index) {
                          final estudiante = filteredResults[index];
                          return Card(
                            margin: EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: estudiante.isActive ? Colors.green[100] : Colors.red[100],
                                child: Icon(
                                  Icons.person,
                                  color: estudiante.isActive ? Colors.green : Colors.red,
                                ),
                              ),
                              title: Text(
                                estudiante.nombreCompleto,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Código: ${estudiante.codigoUniversitario}'),
                                  Text('DNI: ${estudiante.dni}'),
                                  Text('${estudiante.siglasFacultad} - ${estudiante.siglasEscuela}'),
                                ],
                              ),
                              trailing: Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: estudiante.isActive ? Colors.green[100] : Colors.red[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  estudiante.isActive ? 'Activo' : 'Inactivo',
                                  style: TextStyle(
                                    color: estudiante.isActive ? Colors.green[700] : Colors.red[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => StudentStatusDetailView(
                                      codigoUniversitario: estudiante.codigoUniversitario,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _performSearch() {
    final studentStatusViewModel = Provider.of<StudentStatusViewModel>(
      context,
      listen: false,
    );

    if (_searchController.text.trim().isNotEmpty) {
      studentStatusViewModel.searchStudents(_searchController.text);
    } else {
      studentStatusViewModel.clearSearchResults();
    }
  }

  List<dynamic> _getFilteredResults(StudentStatusViewModel studentStatusViewModel) {
    List<dynamic> results = [];

    // Obtener resultados base según el filtro seleccionado
    switch (_selectedFilter) {
      case 'activos':
        results = studentStatusViewModel.getStudentsByStatus('activos');
        break;
      case 'inactivos':
        results = studentStatusViewModel.getStudentsByStatus('inactivos');
        break;
      case 'recientes':
        results = studentStatusViewModel.getStudentsByStatus('recientes');
        break;
      case 'alertas':
        results = studentStatusViewModel.getStudentsByStatus('alertas');
        break;
      default:
        results = studentStatusViewModel.searchResults;
    }

    // Aplicar filtros adicionales
    if (_selectedFaculty != 'todas') {
      results = results.where((s) => s.siglasFacultad == _selectedFaculty).toList();
    }

    if (_selectedSchool != 'todas') {
      results = results.where((s) => s.siglasEscuela == _selectedSchool).toList();
    }

    return results;
  }

  Widget _buildSearchStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}
