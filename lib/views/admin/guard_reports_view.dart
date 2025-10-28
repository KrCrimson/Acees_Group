import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/guard_reports_viewmodel.dart';
import '../../widgets/status_widgets.dart';

class GuardReportsView extends StatefulWidget {
  @override
  _GuardReportsViewState createState() => _GuardReportsViewState();
}

class _GuardReportsViewState extends State<GuardReportsView>
    with TickerProviderStateMixin {
  late TabController _tabController;
  DateTime _fechaInicio = DateTime.now().subtract(Duration(days: 7));
  DateTime _fechaFin = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
    final guardReportsViewModel = Provider.of<GuardReportsViewModel>(
      context,
      listen: false,
    );
    await guardReportsViewModel.loadAllGuardReports();
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _fechaInicio,
        end: _fechaFin,
      ),
    );

    if (picked != null) {
      setState(() {
        _fechaInicio = picked.start;
        _fechaFin = picked.end;
      });
      
      // Actualizar el ViewModel con las nuevas fechas
      final guardReportsViewModel = Provider.of<GuardReportsViewModel>(
        context,
        listen: false,
      );
      guardReportsViewModel.updateDateRange(_fechaInicio, _fechaFin);
      await guardReportsViewModel.loadAllGuardReports();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GuardReportsViewModel>(
      builder: (context, guardReportsViewModel, child) {
        if (guardReportsViewModel.isLoading) {
          return LoadingWidget(message: 'Cargando reportes de guardias...');
        }

        if (guardReportsViewModel.errorMessage != null) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              SizedBox(height: 16),
              Text(guardReportsViewModel.errorMessage!, textAlign: TextAlign.center),
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
            // Header con filtros de fecha
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Reportes de Actividad de Guardias',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      IconButton(
                        onPressed: _loadReportsData,
                        icon: Icon(Icons.refresh),
                        tooltip: 'Actualizar datos',
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDateFilter(),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCards(guardReportsViewModel),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Tabs
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: [
                Tab(text: 'Resumen General', icon: Icon(Icons.dashboard)),
                Tab(text: 'Ranking Guardias', icon: Icon(Icons.leaderboard)),
                Tab(text: 'Actividad Diaria', icon: Icon(Icons.calendar_today)),
                Tab(text: 'Autorizaciones', icon: Icon(Icons.verified_user)),
              ],
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildGeneralSummaryTab(guardReportsViewModel),
                  _buildRankingTab(guardReportsViewModel),
                  _buildDailyActivityTab(guardReportsViewModel),
                  _buildAuthorizationsTab(guardReportsViewModel),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDateFilter() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rango de Fechas',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            InkWell(
              onTap: _selectDateRange,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.date_range, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_fechaInicio.day}/${_fechaInicio.month}/${_fechaInicio.year} - ${_fechaFin.day}/${_fechaFin.month}/${_fechaFin.year}',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(GuardReportsViewModel guardReportsViewModel) {
    final resumen = guardReportsViewModel.resumenActividad;
    
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Total Asistencias',
            resumen != null ? '${resumen.totalAsistencias}' : '0',
            Colors.blue,
            Icons.people,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            'Guardias Activos',
            resumen != null ? '${resumen.guardiasActivos}' : '0',
            Colors.green,
            Icons.security,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            'Autorizaciones',
            resumen != null ? '${resumen.autorizacionesManuales}' : '0',
            Colors.orange,
            Icons.verified_user,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 10, color: Colors.grey[700]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralSummaryTab(GuardReportsViewModel guardReportsViewModel) {
    final resumen = guardReportsViewModel.resumenActividad;
    
    return RefreshIndicator(
      onRefresh: _loadReportsData,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Resumen general
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resumen General del Período',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 12),
                    if (resumen != null) ...[
                      _buildSummaryRow('Total Asistencias', '${resumen.totalAsistencias}'),
                      _buildSummaryRow('Guardias Activos', '${resumen.guardiasActivos}'),
                      _buildSummaryRow('Autorizaciones Manuales', '${resumen.autorizacionesManuales}'),
                      _buildSummaryRow('Puerta Más Usada', resumen.puertaMasUsada),
                      _buildSummaryRow('Facultad Más Atendida', resumen.facultadMasAtendida),
                      _buildSummaryRow('Promedio Diario', '${resumen.promedioDiario.toStringAsFixed(1)}'),
                    ] else ...[
                      Text('No hay datos disponibles', style: TextStyle(color: Colors.grey)),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Actividad por día de la semana
            _buildWeeklyActivityChart(guardReportsViewModel),
            SizedBox(height: 16),

            // Top puertas
            _buildTopPuertas(guardReportsViewModel),
          ],
        ),
      ),
    );
  }

  Widget _buildRankingTab(GuardReportsViewModel guardReportsViewModel) {
    final ranking = guardReportsViewModel.rankingGuardias;
    
    return RefreshIndicator(
      onRefresh: _loadReportsData,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: ranking.length,
        itemBuilder: (context, index) {
          final guardia = ranking[index];
          
          return Card(
            margin: EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _getRankingColor(index),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                'Guardia ${guardia.guardiaId.substring(0, 8)}...',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total: ${guardia.totalAsistencias} asistencias'),
                  Text('Entradas: ${guardia.entradas} | Salidas: ${guardia.salidas}'),
                  Text('Autorizaciones: ${guardia.autorizacionesManuales}'),
                  Text('Promedio diario: ${guardia.promedioDiario.toStringAsFixed(1)}'),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${guardia.totalAsistencias}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _getRankingColor(index),
                    ),
                  ),
                  Text(
                    'asistencias',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDailyActivityTab(GuardReportsViewModel guardReportsViewModel) {
    final actividadPorDia = guardReportsViewModel.actividadSemanal;
    final diasSemana = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    
    return RefreshIndicator(
      onRefresh: _loadReportsData,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Actividad por Día de la Semana',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    Container(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: 7,
                        itemBuilder: (context, index) {
                          final dia = index + 1;
                          final actividad = actividadPorDia[dia] ?? 0;
                          final maxActividad = actividadPorDia.values.isNotEmpty
                              ? actividadPorDia.values.reduce((a, b) => a > b ? a : b)
                              : 1;
                          final altura = actividad == 0
                              ? 0.0
                              : (actividad / maxActividad) * 150;

                          return Container(
                            width: 60,
                            margin: EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (actividad > 0)
                                  Text('$actividad', style: TextStyle(fontSize: 10)),
                                Container(
                                  width: 40,
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
                                  diasSemana[index],
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
            ),
            SizedBox(height: 16),

            // Lista detallada por día
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detalle por Día',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 12),
                    ...diasSemana.asMap().entries.map((entry) {
                      final index = entry.key;
                      final dia = index + 1;
                      final actividad = actividadPorDia[dia] ?? 0;
                      
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(entry.value),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$actividad',
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthorizationsTab(GuardReportsViewModel guardReportsViewModel) {
    final guardiasConAutorizaciones = guardReportsViewModel.getGuardiasConMasAutorizaciones(limit: 50);
    
    return RefreshIndicator(
      onRefresh: _loadReportsData,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: guardiasConAutorizaciones.length,
        itemBuilder: (context, index) {
          final guardia = guardiasConAutorizaciones[index];
          final autorizaciones = guardia.autorizacionesManuales;
          
          return Card(
            margin: EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: autorizaciones > 10 
                    ? Colors.red[100] 
                    : autorizaciones > 5 
                        ? Colors.orange[100] 
                        : Colors.green[100],
                child: Icon(
                  Icons.verified_user,
                  color: autorizaciones > 10 
                      ? Colors.red 
                      : autorizaciones > 5 
                          ? Colors.orange 
                          : Colors.green,
                ),
              ),
              title: Text(
                'Guardia ${guardia.guardiaId.substring(0, 8)}...',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total asistencias: ${guardia.totalAsistencias}'),
                  Text('Puerta más usada: ${guardia.puertaMasUsada}'),
                  Text('Facultad más atendida: ${guardia.facultadMasAtendida}'),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$autorizaciones',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: autorizaciones > 10 
                          ? Colors.red 
                          : autorizaciones > 5 
                              ? Colors.orange 
                              : Colors.green,
                    ),
                  ),
                  Text(
                    'autorizaciones',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWeeklyActivityChart(GuardReportsViewModel guardReportsViewModel) {
    final actividadPorDia = guardReportsViewModel.actividadSemanal;
    final diasSemana = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actividad por Día de la Semana',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            ...diasSemana.asMap().entries.map((entry) {
              final index = entry.key;
              final dia = index + 1;
              final actividad = actividadPorDia[dia] ?? 0;
              
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.value),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$actividad',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopPuertas(GuardReportsViewModel guardReportsViewModel) {
    final topPuertas = guardReportsViewModel.topPuertas.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Puertas por Actividad',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            ...topPuertas.take(5).map((entry) => Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(entry.key)),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${entry.value}',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            )).toList(),
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

  Color _getRankingColor(int index) {
    if (index == 0) return Colors.amber[700]!;
    if (index == 1) return Colors.grey[400]!;
    if (index == 2) return Colors.brown[400]!;
    return Colors.blue[400]!;
  }
}
