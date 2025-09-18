import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/matriculation_viewmodel.dart';
import '../widgets/status_widgets.dart';
import 'matriculation_detail_view.dart';

class MatriculationSearchView extends StatefulWidget {
  @override
  _MatriculationSearchViewState createState() => _MatriculationSearchViewState();
}

class _MatriculationSearchViewState extends State<MatriculationSearchView> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCiclo = '';
  String _selectedAnio = '';
  String _selectedEstado = '';
  String _selectedFacultad = '';

  final List<String> _ciclos = ['2024-I', '2024-II', '2025-I', '2025-II'];
  final List<String> _anios = ['2024', '2025'];
  final List<String> _estados = ['VIGENTE', 'VENCIDA', 'PENDIENTE_PAGO', 'SUSPENDIDA', 'CANCELADA'];
  final List<String> _facultades = ['FIIS', 'FIC', 'FIM', 'FIA', 'FIE'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Búsqueda de Matrículas'),
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
                    hintText: 'Buscar por código, DNI o nombre...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onSubmitted: (value) => _performSearch(),
                ),
                SizedBox(height: 16),

                // Filtros
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedCiclo.isEmpty ? null : _selectedCiclo,
                        decoration: InputDecoration(
                          labelText: 'Ciclo',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: _ciclos.map((ciclo) {
                          return DropdownMenuItem(
                            value: ciclo,
                            child: Text(ciclo),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCiclo = value ?? '';
                          });
                        },
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedAnio.isEmpty ? null : _selectedAnio,
                        decoration: InputDecoration(
                          labelText: 'Año',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: _anios.map((anio) {
                          return DropdownMenuItem(
                            value: anio,
                            child: Text(anio),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedAnio = value ?? '';
                          });
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedEstado.isEmpty ? null : _selectedEstado,
                        decoration: InputDecoration(
                          labelText: 'Estado',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: _estados.map((estado) {
                          return DropdownMenuItem(
                            value: estado,
                            child: Text(estado.replaceAll('_', ' ')),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedEstado = value ?? '';
                          });
                        },
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedFacultad.isEmpty ? null : _selectedFacultad,
                        decoration: InputDecoration(
                          labelText: 'Facultad',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: _facultades.map((facultad) {
                          return DropdownMenuItem(
                            value: facultad,
                            child: Text(facultad),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedFacultad = value ?? '';
                          });
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _performSearch,
                        icon: Icon(Icons.search),
                        label: Text('Buscar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _clearFilters,
                      icon: Icon(Icons.clear),
                      label: Text('Limpiar'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Resultados
          Expanded(
            child: Consumer<MatriculationViewModel>(
              builder: (context, matriculationViewModel, child) {
                if (matriculationViewModel.isLoading) {
                  return LoadingWidget(message: 'Buscando matrículas...');
                }

                if (matriculationViewModel.errorMessage != null) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                      SizedBox(height: 16),
                      Text(matriculationViewModel.errorMessage!, textAlign: TextAlign.center),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _performSearch,
                        child: Text('Reintentar'),
                      ),
                    ],
                  );
                }

                final filteredResults = _getFilteredResults(matriculationViewModel);

                if (filteredResults.isEmpty) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                      SizedBox(height: 16),
                      Text(
                        'No se encontraron matrículas con los filtros aplicados',
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
                          _buildSearchStat('Vigentes', '${filteredResults.where((m) => m.isVigente).length}', Colors.green),
                          _buildSearchStat('Vencidas', '${filteredResults.where((m) => m.isVencida).length}', Colors.red),
                          _buildSearchStat('Pendientes', '${filteredResults.where((m) => m.isPendientePago).length}', Colors.orange),
                        ],
                      ),
                    ),

                    // Lista de resultados
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: filteredResults.length,
                        itemBuilder: (context, index) {
                          final matriculation = filteredResults[index];
                          return Card(
                            margin: EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getMatriculationColor(matriculation),
                                child: Icon(
                                  _getMatriculationIcon(matriculation),
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                matriculation.nombreCompleto,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Código: ${matriculation.codigoUniversitario}'),
                                  Text('Período: ${matriculation.periodoCompleto}'),
                                  Text('Estado: ${matriculation.estadoMatriculaFormateado}'),
                                  if (matriculation.isPorVencer)
                                    Text('Días restantes: ${matriculation.diasRestantes}'),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    matriculation.puedeAcceder ? Icons.check : Icons.close,
                                    color: matriculation.puedeAcceder ? Colors.green : Colors.red,
                                  ),
                                  Text(
                                    matriculation.puedeAcceder ? 'Acceso' : 'Denegado',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: matriculation.puedeAcceder ? Colors.green : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MatriculationDetailView(
                                      codigoUniversitario: matriculation.codigoUniversitario,
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
    final matriculationViewModel = Provider.of<MatriculationViewModel>(
      context,
      listen: false,
    );

    matriculationViewModel.buscarMatriculas(
      codigoUniversitario: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null,
      cicloAcademico: _selectedCiclo.isNotEmpty ? _selectedCiclo : null,
      estadoMatricula: _selectedEstado.isNotEmpty ? _selectedEstado : null,
      siglasFacultad: _selectedFacultad.isNotEmpty ? _selectedFacultad : null,
    );
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedCiclo = '';
      _selectedAnio = '';
      _selectedEstado = '';
      _selectedFacultad = '';
    });

    final matriculationViewModel = Provider.of<MatriculationViewModel>(
      context,
      listen: false,
    );
    matriculationViewModel.clearSearchResults();
  }

  List<dynamic> _getFilteredResults(MatriculationViewModel matriculationViewModel) {
    List<dynamic> results = matriculationViewModel.searchResults;

    // Aplicar filtros adicionales
    if (_selectedAnio.isNotEmpty) {
      results = results.where((m) => m.anioAcademico == _selectedAnio).toList();
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

  Color _getMatriculationColor(matriculation) {
    if (matriculation.isVigente) return Colors.green;
    if (matriculation.isVencida) return Colors.red;
    if (matriculation.isPorVencer) return Colors.orange;
    if (matriculation.isPendientePago) return Colors.amber;
    if (matriculation.isSuspendida) return Colors.purple;
    if (matriculation.isCancelada) return Colors.grey;
    return Colors.blue;
  }

  IconData _getMatriculationIcon(matriculation) {
    if (matriculation.isVigente) return Icons.check;
    if (matriculation.isVencida) return Icons.error;
    if (matriculation.isPorVencer) return Icons.warning;
    if (matriculation.isPendientePago) return Icons.pending;
    if (matriculation.isSuspendida) return Icons.pause;
    if (matriculation.isCancelada) return Icons.cancel;
    return Icons.school;
  }
}
