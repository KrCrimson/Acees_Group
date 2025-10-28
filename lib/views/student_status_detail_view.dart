import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/student_status_viewmodel.dart';
import '../widgets/status_widgets.dart';
import '../widgets/connectivity_status_widget.dart';

class StudentStatusDetailView extends StatefulWidget {
  final String codigoUniversitario;

  const StudentStatusDetailView({
    Key? key,
    required this.codigoUniversitario,
  }) : super(key: key);

  @override
  _StudentStatusDetailViewState createState() => _StudentStatusDetailViewState();
}

class _StudentStatusDetailViewState extends State<StudentStatusDetailView>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadStudentStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStudentStatus() async {
    final studentStatusViewModel = Provider.of<StudentStatusViewModel>(
      context,
      listen: false,
    );
    await studentStatusViewModel.getStudentStatus(widget.codigoUniversitario);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Estado del Estudiante'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          ConnectivityStatusWidget(),
          SizedBox(width: 16),
        ],
      ),
      body: Consumer<StudentStatusViewModel>(
        builder: (context, studentStatusViewModel, child) {
          if (studentStatusViewModel.isLoading) {
            return LoadingWidget(message: 'Cargando estado del estudiante...');
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
                  onPressed: _loadStudentStatus,
                  child: Text('Reintentar'),
                ),
              ],
            );
          }

          if (studentStatusViewModel.currentStudentStatus == null) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_off, size: 64, color: Colors.grey[400]),
                SizedBox(height: 16),
                Text('No se encontró información del estudiante'),
              ],
            );
          }

          final studentStatus = studentStatusViewModel.currentStudentStatus!;

          return Column(
            children: [
              // Header con información básica
              _buildStudentHeader(studentStatus),
              
              // Tabs
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: [
                  Tab(text: 'Resumen', icon: Icon(Icons.dashboard)),
                  Tab(text: 'Presencia', icon: Icon(Icons.location_on)),
                  Tab(text: 'Asistencias', icon: Icon(Icons.history)),
                  Tab(text: 'Estadísticas', icon: Icon(Icons.analytics)),
                ],
              ),

              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSummaryTab(studentStatus),
                    _buildPresenceTab(studentStatus),
                    _buildAttendanceTab(studentStatus),
                    _buildStatisticsTab(studentStatus),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStudentHeader(studentStatus) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border(
          bottom: BorderSide(color: Colors.blue[200]!),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: studentStatus.isActive ? Colors.green : Colors.red,
                child: Text(
                  studentStatus.nombreCompleto.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studentStatus.nombreCompleto,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      'Código: ${studentStatus.codigoUniversitario}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    Text(
                      'DNI: ${studentStatus.dni}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    Text(
                      '${studentStatus.facultad} - ${studentStatus.escuela}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: studentStatus.isActive ? Colors.green[100] : Colors.red[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  studentStatus.isActive ? 'Activo' : 'Inactivo',
                  style: TextStyle(
                    color: studentStatus.isActive ? Colors.green[700] : Colors.red[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Icon(
                studentStatus.estaEnCampus ? Icons.location_on : Icons.location_off,
                color: studentStatus.estaEnCampus ? Colors.green : Colors.red,
                size: 16,
              ),
              SizedBox(width: 8),
              Text(
                studentStatus.estadoPresencia,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: studentStatus.estaEnCampus ? Colors.green[700] : Colors.red[700],
                ),
              ),
              if (studentStatus.estaEnCampus && studentStatus.tiempoEnCampus != null) ...[
                SizedBox(width: 16),
                Text(
                  'Tiempo en campus: ${studentStatus.tiempoEnCampusFormateado}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTab(studentStatus) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resumen ejecutivo
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resumen Ejecutivo',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  _buildSummaryRow('Estado', studentStatus.estadoPresencia),
                  _buildSummaryRow('Última actividad', studentStatus.ultimaActividad),
                  _buildSummaryRow('Puede acceder', studentStatus.puedeAcceder ? 'Sí' : 'No'),
                  _buildSummaryRow('Próxima acción', studentStatus.proximaAccionRecomendada),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),

          // Estadísticas rápidas
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estadísticas Rápidas',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard('Hoy', '${studentStatus.totalAsistenciasHoy}', Colors.blue),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard('Semana', '${studentStatus.totalAsistenciasEstaSemana}', Colors.green),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard('Mes', '${studentStatus.totalAsistenciasEsteMes}', Colors.orange),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),

          // Alertas
          if (studentStatus.tieneAlertas) ...[
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          'Alertas',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    ...studentStatus.listaAlertas.map((alerta) => Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.orange, size: 16),
                          SizedBox(width: 8),
                          Expanded(child: Text(alerta)),
                        ],
                      ),
                    )).toList(),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPresenceTab(studentStatus) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Estado de presencia actual
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estado de Presencia Actual',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  if (studentStatus.presenciaActual != null) ...[
                    _buildSummaryRow('En campus', studentStatus.estaEnCampus ? 'Sí' : 'No'),
                    _buildSummaryRow('Hora de entrada', studentStatus.presenciaActual!.horaEntrada.toString()),
                    if (studentStatus.presenciaActual!.horaSalida != null)
                      _buildSummaryRow('Hora de salida', studentStatus.presenciaActual!.horaSalida.toString()),
                    _buildSummaryRow('Punto de entrada', studentStatus.presenciaActual!.puntoEntrada),
                    if (studentStatus.presenciaActual!.puntoSalida != null)
                      _buildSummaryRow('Punto de salida', studentStatus.presenciaActual!.puntoSalida!),
                    _buildSummaryRow('Guardia entrada', studentStatus.presenciaActual!.guardiaEntrada),
                    if (studentStatus.presenciaActual!.guardiaSalida != null)
                      _buildSummaryRow('Guardia salida', studentStatus.presenciaActual!.guardiaSalida!),
                    if (studentStatus.estaEnCampus && studentStatus.tiempoEnCampus != null)
                      _buildSummaryRow('Tiempo en campus', studentStatus.tiempoEnCampusFormateado),
                  ] else ...[
                    Text('No hay registro de presencia actual'),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceTab(studentStatus) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resumen de asistencias
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resumen de Asistencias',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard('Entradas', '${studentStatus.totalEntradas}', Colors.green),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard('Salidas', '${studentStatus.totalSalidas}', Colors.red),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard('Manuales', '${studentStatus.totalAutorizacionesManuales}', Colors.orange),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),

          // Lista de asistencias recientes
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Asistencias Recientes',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  if (studentStatus.asistenciasRecientes.isEmpty) ...[
                    Text('No hay asistencias recientes'),
                  ] else ...[
                    ...studentStatus.asistenciasRecientes.take(10).map((asistencia) => 
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              asistencia.entradaTipo == 'entrada' ? Icons.login : Icons.logout,
                              color: asistencia.entradaTipo == 'entrada' ? Colors.green : Colors.red,
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text('${asistencia.fechaFormateada} - ${asistencia.puerta}'),
                            ),
                            if (asistencia.autorizacionManual == true)
                              Icon(Icons.verified_user, color: Colors.orange, size: 16),
                          ],
                        ),
                      ),
                    ).toList(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsTab(studentStatus) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Patrones de asistencia por día
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Asistencias por Día de la Semana',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  ...studentStatus.asistenciasPorDiaSemana.entries.map((entry) => 
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(entry.key),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                  ).toList(),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),

          // Decisiones manuales
          if (studentStatus.decisionesRecientes.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Decisiones Manuales Recientes',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    SizedBox(height: 12),
                    _buildSummaryRow('Total decisiones', '${studentStatus.totalDecisionesManuales}'),
                    _buildSummaryRow('Autorizadas', '${studentStatus.decisionesAutorizadas}'),
                    _buildSummaryRow('Rechazadas', '${studentStatus.decisionesRechazadas}'),
                    if (studentStatus.razonesDecisionesRechazadas.isNotEmpty) ...[
                      SizedBox(height: 8),
                      Text('Razones de rechazo:', style: TextStyle(fontWeight: FontWeight.w500)),
                      ...studentStatus.razonesDecisionesRechazadas.map((razon) => 
                        Padding(
                          padding: EdgeInsets.only(left: 16, top: 4),
                          child: Text('• $razon', style: TextStyle(fontSize: 12)),
                        ),
                      ).toList(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(color: Colors.grey[700])),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
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
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
