import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/reports_viewmodel.dart';
import '../../widgets/status_widgets.dart';

class ReportsView extends StatefulWidget {
  @override
  _ReportsViewState createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReportsData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReportsData() async {
    final reportsViewModel = Provider.of<ReportsViewModel>(
      context,
      listen: false,
    );
    await reportsViewModel.loadAllData();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportsViewModel>(
      builder: (context, reportsViewModel, child) {
        if (reportsViewModel.isLoading) {
          return LoadingWidget(message: 'Cargando reportes...');
        }

        if (reportsViewModel.errorMessage != null) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              SizedBox(height: 16),
              Text(reportsViewModel.errorMessage!, textAlign: TextAlign.center),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadReportsData,
                child: Text('Reintentar'),
              ),
            ],
          );
        }

        return Column(
          children: [
            // Header con resumen
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reportes y Análisis',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          'Asistencias Hoy',
                          '${reportsViewModel.getTotalAsistenciasHoy()}',
                          Colors.blue,
                          Icons.today,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard(
                          'Esta Semana',
                          '${reportsViewModel.getTotalAsistenciasEstaSemana()}',
                          Colors.green,
                          Icons.date_range,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Tabs
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: 'Estadísticas', icon: Icon(Icons.bar_chart)),
                Tab(text: 'Asistencias', icon: Icon(Icons.list)),
                Tab(text: 'Estudiantes', icon: Icon(Icons.school)),
              ],
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildStatisticsTab(reportsViewModel),
                  _buildAttendanceTab(reportsViewModel),
                  _buildStudentsTab(reportsViewModel),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsTab(ReportsViewModel reportsViewModel) {
    return RefreshIndicator(
      onRefresh: _loadReportsData,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Top Facultades por Asistencias
            _buildTopFacultades(reportsViewModel),
            SizedBox(height: 16),

            // 2. Top Escuelas por Asistencias
            _buildTopEscuelas(reportsViewModel),
            SizedBox(height: 16),

            // 3. Entradas vs Salidas
            _buildEntradasVsSalidas(reportsViewModel),
            SizedBox(height: 16),

            // 4. Distribución por Horas
            _buildHourDistribution(reportsViewModel),
            SizedBox(height: 16),

            // 5. Tendencia Semanal
            _buildTendenciaSemanal(reportsViewModel),
            SizedBox(height: 16),

            // 6. Top 10 Estudiantes Activos
            _buildTopEstudiantes(reportsViewModel),
            SizedBox(height: 16),

            // 7. Comparativa Mensual
            _buildComparativaMensual(reportsViewModel),
            SizedBox(height: 16),

            // 8. Resumen General
            _buildGeneralSummary(reportsViewModel),
          ],
        ),
      ),
    );
  }

  Widget _buildTopEscuelas(ReportsViewModel reportsViewModel) {
    final topEscuelas = reportsViewModel.getTopEscuelas();
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.school, color: Colors.orange),
                SizedBox(width: 8),
                Text('Top Escuelas por Asistencias', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 12),
            ...topEscuelas.map((entry) => Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(entry.key)),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('${entry.value}', style: TextStyle(color: Colors.orange[700], fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildEntradasVsSalidas(ReportsViewModel reportsViewModel) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: FutureBuilder<Map<String, int>>(
          future: reportsViewModel.getEntradasVsSalidas(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            
            final stats = snapshot.data ?? {'entradas': 0, 'salidas': 0};
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.swap_horiz, color: Colors.purple),
                    SizedBox(width: 8),
                    Text('Entradas vs Salidas (Hoy)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.login, color: Colors.green, size: 32),
                            SizedBox(height: 8),
                            Text('${stats['entradas']}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                            Text('Entradas', style: TextStyle(color: Colors.grey[600])),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.logout, color: Colors.orange, size: 32),
                            SizedBox(height: 8),
                            Text('${stats['salidas']}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange)),
                            Text('Salidas', style: TextStyle(color: Colors.grey[600])),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTendenciaSemanal(ReportsViewModel reportsViewModel) {
    final tendencia = reportsViewModel.getTendenciaSemanal();
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: Colors.blue),
                SizedBox(width: 8),
                Text('Tendencia Semanal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 12),
            Container(
              height: 150,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: tendencia.length,
                itemBuilder: (context, index) {
                  final dia = tendencia[index];
                  final maxValue = tendencia.map((d) => d['count'] as int).reduce((a, b) => a > b ? a : b);
                  final altura = (dia['count'] as int) == 0 ? 0.0 : ((dia['count'] as int) / maxValue) * 100;
                  return Container(
                    width: 50,
                    margin: EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('${dia['count']}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        Container(
                          width: 30,
                          height: altura,
                          decoration: BoxDecoration(
                            color: Colors.blue[400],
                            borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(dia['label'] as String, style: TextStyle(fontSize: 10)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopEstudiantes(ReportsViewModel reportsViewModel) {
    final topEstudiantes = reportsViewModel.getTopEstudiantes();
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_events, color: Colors.amber),
                SizedBox(width: 8),
                Text('Top 10 Estudiantes Más Activos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 12),
            ...topEstudiantes.asMap().entries.map((entry) {
              final index = entry.key;
              final estudiante = entry.value;
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: index < 3 ? Colors.amber[100] : Colors.grey[200],
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text('${index + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: index < 3 ? Colors.amber[700] : Colors.grey[600])),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(child: Text(estudiante['nombre'] as String, style: TextStyle(fontSize: 13))),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('${estudiante['count']}', style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildComparativaMensual(ReportsViewModel reportsViewModel) {
    final comparativa = reportsViewModel.getComparativaMensual();
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_month, color: Colors.teal),
                SizedBox(width: 8),
                Text('Comparativa Últimos 3 Meses', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 12),
            ...comparativa.map((mes) => Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(mes['mes'] as String),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.teal[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('${mes['count']}', style: TextStyle(color: Colors.teal[700], fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildTopFacultades(ReportsViewModel reportsViewModel) {
    final topFacultades = reportsViewModel.getTopFacultades();

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Facultades por Asistencias',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            ...topFacultades
                .map(
                  (entry) => Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(entry.key)),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${entry.value}',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHourDistribution(ReportsViewModel reportsViewModel) {
    final asistenciasPorHora = reportsViewModel.getAsistenciasPorHora();

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Distribución por Horas del Día',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Container(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 24,
                itemBuilder: (context, index) {
                  final hora = index;
                  final asistencias = asistenciasPorHora[hora] ?? 0;
                  final maxAsistencias =
                      asistenciasPorHora.values.isNotEmpty
                          ? asistenciasPorHora.values.reduce(
                            (a, b) => a > b ? a : b,
                          )
                          : 1;
                  final altura =
                      asistencias == 0
                          ? 0.0
                          : (asistencias / maxAsistencias) * 150;

                  return Container(
                    width: 30,
                    margin: EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (asistencias > 0)
                          Text('$asistencias', style: TextStyle(fontSize: 10)),
                        Container(
                          width: 20,
                          height: altura,
                          decoration: BoxDecoration(
                            color: Colors.blue[400],
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${hora.toString().padLeft(2, '0')}h',
                          style: TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralSummary(ReportsViewModel reportsViewModel) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumen General',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            _buildSummaryRow(
              'Total Estudiantes',
              '${reportsViewModel.alumnos.length}',
            ),
            _buildSummaryRow(
              'Total Asistencias',
              '${reportsViewModel.asistencias.length}',
            ),
            _buildSummaryRow(
              'Total Facultades',
              '${reportsViewModel.facultades.length}',
            ),
            _buildSummaryRow(
              'Total Escuelas',
              '${reportsViewModel.escuelas.length}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildAttendanceTab(ReportsViewModel reportsViewModel) {
    return Column(
      children: [
        // Barra de búsqueda y filtros
        Container(
          padding: EdgeInsets.all(12),
          color: Colors.grey[100],
          child: Column(
            children: [
              // Búsqueda
              TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar por DNI o nombre...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
                onChanged: (value) => reportsViewModel.setAsistenciaSearchQuery(value),
              ),
              SizedBox(height: 8),
              // Filtros en fila
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Filtro Facultad
                    _buildFilterChip(
                      'Facultad',
                      reportsViewModel.selectedFacultadFilter,
                      Icons.business,
                      () => _showFacultadFilter(context, reportsViewModel),
                    ),
                    SizedBox(width: 8),
                    // Filtro Escuela
                    _buildFilterChip(
                      'Escuela',
                      reportsViewModel.selectedEscuelaFilter,
                      Icons.school,
                      () => _showEscuelaFilter(context, reportsViewModel),
                    ),
                    SizedBox(width: 8),
                    // Filtro Tipo
                    _buildFilterChip(
                      'Tipo',
                      reportsViewModel.selectedTipoFilter,
                      Icons.swap_horiz,
                      () => _showTipoFilter(context, reportsViewModel),
                    ),
                    SizedBox(width: 8),
                    // Limpiar filtros
                    if (reportsViewModel.hasAsistenciaFilters)
                      TextButton.icon(
                        onPressed: () => reportsViewModel.clearAsistenciaFilters(),
                        icon: Icon(Icons.clear, size: 16),
                        label: Text('Limpiar'),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Lista filtrada
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadReportsData,
            child: reportsViewModel.filteredAsistencias.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                        SizedBox(height: 16),
                        Text('No se encontraron asistencias', style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: reportsViewModel.filteredAsistencias.length,
                    itemBuilder: (context, index) {
                      final asistencia = reportsViewModel.filteredAsistencias[index];
                      final isEntrada = asistencia.entradaTipo.toLowerCase().contains('entrada');
                      return Card(
                        margin: EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isEntrada ? Colors.green[100] : Colors.orange[100],
                            child: Icon(
                              isEntrada ? Icons.login : Icons.logout,
                              color: isEntrada ? Colors.green : Colors.orange,
                            ),
                          ),
                          title: Text(asistencia.nombreCompleto),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Código: ${asistencia.codigoUniversitario}'),
                              Text('${asistencia.siglasFacultad} - ${asistencia.siglasEscuela}'),
                              Text('Fecha: ${asistencia.fechaFormateada}'),
                            ],
                          ),
                          trailing: Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isEntrada ? Colors.green[100] : Colors.orange[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              asistencia.entradaTipo,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isEntrada ? Colors.green[700] : Colors.orange[700],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String? value, IconData icon, VoidCallback onTap) {
    final hasValue = value != null && value.isNotEmpty;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: hasValue ? Colors.blue[100] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: hasValue ? Colors.blue : Colors.grey[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: hasValue ? Colors.blue[700] : Colors.grey[600]),
            SizedBox(width: 4),
            Text(
              hasValue ? value : label,
              style: TextStyle(
                fontSize: 12,
                color: hasValue ? Colors.blue[700] : Colors.grey[700],
                fontWeight: hasValue ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFacultadFilter(BuildContext context, ReportsViewModel vm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Filtrar por Facultad'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('Todas'),
                leading: Radio(value: null, groupValue: vm.selectedFacultadFilter, onChanged: (_) {
                  vm.setFacultadFilter(null);
                  Navigator.pop(context);
                }),
              ),
              ...vm.facultades.map((f) => ListTile(
                title: Text(f.siglas),
                leading: Radio(value: f.siglas, groupValue: vm.selectedFacultadFilter, onChanged: (_) {
                  vm.setFacultadFilter(f.siglas);
                  Navigator.pop(context);
                }),
              )),
            ],
          ),
        ),
      ),
    );
  }

  void _showEscuelaFilter(BuildContext context, ReportsViewModel vm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Filtrar por Escuela'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('Todas'),
                leading: Radio(value: null, groupValue: vm.selectedEscuelaFilter, onChanged: (_) {
                  vm.setEscuelaFilter(null);
                  Navigator.pop(context);
                }),
              ),
              ...vm.escuelas.map((e) => ListTile(
                title: Text(e.siglas),
                leading: Radio(value: e.siglas, groupValue: vm.selectedEscuelaFilter, onChanged: (_) {
                  vm.setEscuelaFilter(e.siglas);
                  Navigator.pop(context);
                }),
              )),
            ],
          ),
        ),
      ),
    );
  }

  void _showTipoFilter(BuildContext context, ReportsViewModel vm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Filtrar por Tipo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Todos'),
              leading: Radio(value: null, groupValue: vm.selectedTipoFilter, onChanged: (_) {
                vm.setTipoFilter(null);
                Navigator.pop(context);
              }),
            ),
            ListTile(
              title: Text('Entrada'),
              leading: Radio(value: 'entrada', groupValue: vm.selectedTipoFilter, onChanged: (_) {
                vm.setTipoFilter('entrada');
                Navigator.pop(context);
              }),
            ),
            ListTile(
              title: Text('Salida'),
              leading: Radio(value: 'salida', groupValue: vm.selectedTipoFilter, onChanged: (_) {
                vm.setTipoFilter('salida');
                Navigator.pop(context);
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentsTab(ReportsViewModel reportsViewModel) {
    return Column(
      children: [
        // Barra de búsqueda y filtros
        Container(
          padding: EdgeInsets.all(12),
          color: Colors.grey[100],
          child: Column(
            children: [
              // Búsqueda
              TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar por código o nombre...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
                onChanged: (value) => reportsViewModel.setEstudianteSearchQuery(value),
              ),
              SizedBox(height: 8),
              // Filtros en fila
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Filtro Facultad
                    _buildFilterChip(
                      'Facultad',
                      reportsViewModel.selectedFacultadFilterEst,
                      Icons.business,
                      () => _showFacultadFilterEst(context, reportsViewModel),
                    ),
                    SizedBox(width: 8),
                    // Filtro Escuela
                    _buildFilterChip(
                      'Escuela',
                      reportsViewModel.selectedEscuelaFilterEst,
                      Icons.school,
                      () => _showEscuelaFilterEst(context, reportsViewModel),
                    ),
                    SizedBox(width: 8),
                    // Filtro Estado
                    _buildFilterChip(
                      'Estado',
                      reportsViewModel.selectedEstadoFilter,
                      Icons.toggle_on,
                      () => _showEstadoFilter(context, reportsViewModel),
                    ),
                    SizedBox(width: 8),
                    // Limpiar filtros
                    if (reportsViewModel.hasEstudianteFilters)
                      TextButton.icon(
                        onPressed: () => reportsViewModel.clearEstudianteFilters(),
                        icon: Icon(Icons.clear, size: 16),
                        label: Text('Limpiar'),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Lista filtrada
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadReportsData,
            child: reportsViewModel.filteredEstudiantes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                        SizedBox(height: 16),
                        Text('No se encontraron estudiantes', style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: reportsViewModel.filteredEstudiantes.length,
                    itemBuilder: (context, index) {
                      final alumno = reportsViewModel.filteredEstudiantes[index];
                      return Card(
                        margin: EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: alumno.isActive ? Colors.green[100] : Colors.red[100],
                            child: Icon(
                              Icons.school,
                              color: alumno.isActive ? Colors.green : Colors.red,
                            ),
                          ),
                          title: Text(alumno.nombreCompleto),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Código: ${alumno.codigoUniversitario}'),
                              Text('${alumno.siglasFacultad} - ${alumno.siglasEscuela}'),
                            ],
                          ),
                          trailing: Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: alumno.isActive ? Colors.green[100] : Colors.red[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              alumno.isActive ? 'Activo' : 'Inactivo',
                              style: TextStyle(
                                color: alumno.isActive ? Colors.green[700] : Colors.red[700],
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  void _showFacultadFilterEst(BuildContext context, ReportsViewModel vm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Filtrar por Facultad'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('Todas'),
                leading: Radio(value: null, groupValue: vm.selectedFacultadFilterEst, onChanged: (_) {
                  vm.setFacultadFilterEst(null);
                  Navigator.pop(context);
                }),
              ),
              ...vm.facultades.map((f) => ListTile(
                title: Text(f.siglas),
                leading: Radio(value: f.siglas, groupValue: vm.selectedFacultadFilterEst, onChanged: (_) {
                  vm.setFacultadFilterEst(f.siglas);
                  Navigator.pop(context);
                }),
              )),
            ],
          ),
        ),
      ),
    );
  }

  void _showEscuelaFilterEst(BuildContext context, ReportsViewModel vm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Filtrar por Escuela'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('Todas'),
                leading: Radio(value: null, groupValue: vm.selectedEscuelaFilterEst, onChanged: (_) {
                  vm.setEscuelaFilterEst(null);
                  Navigator.pop(context);
                }),
              ),
              ...vm.escuelas.map((e) => ListTile(
                title: Text(e.siglas),
                leading: Radio(value: e.siglas, groupValue: vm.selectedEscuelaFilterEst, onChanged: (_) {
                  vm.setEscuelaFilterEst(e.siglas);
                  Navigator.pop(context);
                }),
              )),
            ],
          ),
        ),
      ),
    );
  }

  void _showEstadoFilter(BuildContext context, ReportsViewModel vm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Filtrar por Estado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Todos'),
              leading: Radio(value: null, groupValue: vm.selectedEstadoFilter, onChanged: (_) {
                vm.setEstadoFilter(null);
                Navigator.pop(context);
              }),
            ),
            ListTile(
              title: Text('Activo'),
              leading: Radio(value: 'activo', groupValue: vm.selectedEstadoFilter, onChanged: (_) {
                vm.setEstadoFilter('activo');
                Navigator.pop(context);
              }),
            ),
            ListTile(
              title: Text('Inactivo'),
              leading: Radio(value: 'inactivo', groupValue: vm.selectedEstadoFilter, onChanged: (_) {
                vm.setEstadoFilter('inactivo');
                Navigator.pop(context);
              }),
            ),
          ],
        ),
      ),
    );
  }
}
