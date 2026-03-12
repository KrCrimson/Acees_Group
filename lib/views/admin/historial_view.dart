import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/historial_actividades_viewmodel.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../models/actividad_model.dart';
import '../../widgets/status_widgets.dart';

class HistorialView extends StatefulWidget {
  @override
  _HistorialViewState createState() => _HistorialViewState();
}

class _HistorialViewState extends State<HistorialView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late HistorialActividadesViewModel _historialViewModel;

  // Filtros
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  String? _guardiaSeleccionado;
  String? _tipoActividadSeleccionado;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _historialViewModel = HistorialActividadesViewModel();
    _cargarDatosIniciales();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosIniciales() async {
    await _historialViewModel.cargarHistorialActividades();
    await _historialViewModel.cargarEstadisticasComparativas();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _historialViewModel,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Historial de Actividades - Guardias'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.today), text: 'Hoy'),
              Tab(icon: Icon(Icons.timeline), text: 'Timeline'),
              Tab(icon: Icon(Icons.person), text: 'Por Guardia'),
              Tab(icon: Icon(Icons.analytics), text: 'Estadísticas'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildResumenHoy(),
            _buildTimelineView(),
            _buildPorGuardiaView(),
            _buildEstadisticasView(),
          ],
        ),
      ),
    );
  }

  // ==================== VISTA 1: RESUMEN DEL DÍA ====================

  Widget _buildResumenHoy() {
    return Consumer<HistorialActividadesViewModel>(builder: (context, viewModel, child) {
      if (viewModel.isLoading) {
        return LoadingWidget(message: 'Cargando actividades de hoy...');
      }

      return RefreshIndicator(
        onRefresh: () => viewModel.cargarEstadisticasComparativas(),
        child: Column(
          children: [
            _buildMetricasGeneralesCards(),
            SizedBox(height: 16),
            Expanded(
              child: _buildListaGuardiasHoy(),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildMetricasGeneralesCards() {
    return Consumer<HistorialActividadesViewModel>(builder: (context, viewModel, child) {
      final stats = viewModel.estadisticasRapidas;
      
      return Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _buildMetricaCard(
                title: 'Guardias Activos',
                value: '${viewModel.estadisticasComparativas.length}',
                icon: Icons.people,
                color: Colors.green,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildMetricaCard(
                title: 'Total Registros',
                value: '${stats['total'] ?? 0}',
                icon: Icons.assignment,
                color: Colors.blue,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildMetricaCard(
                title: 'Sesiones',
                value: '${stats['sesiones_iniciadas'] ?? 0}',
                icon: Icons.access_time,
                color: Colors.orange,
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildMetricaCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListaGuardiasHoy() {
    return Consumer<HistorialActividadesViewModel>(builder: (context, viewModel, child) {
      final guardias = viewModel.estadisticasComparativas;
      
      if (guardias.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
              SizedBox(height: 16),
              Text(
                'No hay actividad de guardias registrada',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 16),
        itemCount: guardias.length,
        itemBuilder: (context, index) {
          final guardia = guardias[index];
          return _buildGuardiaCard(guardia);
        },
      );
    });
  }

  Widget _buildGuardiaCard(EstadisticasGuardiaModel guardia) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.indigo[100],
          child: Text(
            guardia.guardiaNombre.split(' ').map((n) => n[0]).take(2).join(),
            style: TextStyle(color: Colors.indigo[700], fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(guardia.guardiaNombre),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${guardia.totalRegistros} registros • ${guardia.horasTrabajadas.toStringAsFixed(1)}h trabajadas'),
            Text('Productividad: ${guardia.registrosPorHora.toStringAsFixed(1)} reg/hora'),
          ],
        ),
        trailing: Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: guardia.registrosPorHora > 10 ? Colors.green[100] : Colors.orange[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            guardia.registrosPorHora > 10 ? 'Alto' : 'Normal',
            style: TextStyle(
              fontSize: 12,
              color: guardia.registrosPorHora > 10 ? Colors.green[800] : Colors.orange[800],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        onTap: () => _mostrarDetalleGuardia(guardia),
      ),
    );
  }

  // ==================== VISTA 2: TIMELINE ====================

  Widget _buildTimelineView() {
    return Consumer<HistorialActividadesViewModel>(builder: (context, viewModel, child) {
      return Column(
        children: [
          _buildFiltrosTimeline(),
          Expanded(
            child: _buildTimelineContent(viewModel),
          ),
        ],
      );
    });
  }

  Widget _buildFiltrosTimeline() {
    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.grey[50],
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: Icon(Icons.date_range),
                  label: Text(_fechaInicio != null && _fechaFin != null
                      ? '${_fechaInicio!.day}/${_fechaInicio!.month} - ${_fechaFin!.day}/${_fechaFin!.month}'
                      : 'Seleccionar fechas'),
                  onPressed: _seleccionarRangoFechas,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Consumer<AdminViewModel>(builder: (context, adminViewModel, child) {
                  final usuarios = adminViewModel.usuarios
                      .where((u) => u.rango == 'guardia')
                      .toList();
                  
                  return DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Guardia',
                      border: OutlineInputBorder(),
                    ),
                    value: _guardiaSeleccionado,
                    items: [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text('Todos los guardias'),
                      ),
                      ...usuarios.map((u) => DropdownMenuItem<String>(
                            value: u.id,
                            child: Text(u.nombreCompleto),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _guardiaSeleccionado = value;
                      });
                    },
                  );
                }),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Tipo de Actividad',
                    border: OutlineInputBorder(),
                  ),
                  value: _tipoActividadSeleccionado,
                  items: [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text('Todos los tipos'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'sesion_iniciada',
                      child: Text('Inicio de sesión'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'registro_entrada',
                      child: Text('Registros de entrada'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'registro_salida',
                      child: Text('Registros de salida'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'autorizacion_manual',
                      child: Text('Autorizaciones manuales'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _tipoActividadSeleccionado = value;
                    });
                  },
                ),
              ),
              SizedBox(width: 12),
              ElevatedButton.icon(
                icon: Icon(Icons.search),
                label: Text('Filtrar'),
                onPressed: _aplicarFiltros,
              ),
              SizedBox(width: 8),
              TextButton.icon(
                icon: Icon(Icons.clear),
                label: Text('Limpiar'),
                onPressed: _limpiarFiltros,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineContent(HistorialActividadesViewModel viewModel) {
    if (viewModel.isLoading) {
      return LoadingWidget(message: 'Cargando timeline...');
    }

    if (viewModel.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            SizedBox(height: 16),
            Text(
              viewModel.errorMessage!,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => viewModel.cargarHistorialActividades(),
              child: Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (viewModel.actividades.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timeline, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No hay actividades registradas',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            Text(
              'Ajusta los filtros o selecciona un rango de fechas diferente',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => viewModel.cargarHistorialActividades(),
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: viewModel.actividades.length,
        itemBuilder: (context, index) {
          final actividad = viewModel.actividades[index];
          return _buildTimelineItem(actividad, index == 0);
        },
      ),
    );
  }

  Widget _buildTimelineItem(ActividadModel actividad, bool isFirst) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline line and dot
        Column(
          children: [
            if (!isFirst)
              Container(
                width: 2,
                height: 20,
                color: Colors.grey[300],
              ),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _getColorForTipo(actividad.tipoActividad),
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 2,
              height: 40,
              color: Colors.grey[300],
            ),
          ],
        ),
        SizedBox(width: 16),
        // Content
        Expanded(
          child: Card(
            margin: EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Icon(
                _getIconForTipo(actividad.tipoActividad),
                color: _getColorForTipo(actividad.tipoActividad),
              ),
              title: Text(
                '${actividad.guardiaNombre} - ${actividad.puntoControl}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(actividad.tipoActividadDisplay),
                  Text(
                    actividad.horaFormateada,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  if (actividad.duracionSesion != null)
                    Text(
                      'Duración: ${actividad.duracionFormateada}',
                      style: TextStyle(fontSize: 12, color: Colors.blue[600]),
                    ),
                  if (actividad.estudianteDni != null)
                    Text(
                      'DNI: ${actividad.estudianteDni}',
                      style: TextStyle(fontSize: 12, color: Colors.green[600]),
                    ),
                ],
              ),
              trailing: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${actividad.contadores.totalRegistros}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    'registros',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getColorForTipo(String tipo) {
    switch (tipo) {
      case 'sesion_iniciada':
        return Colors.green;
      case 'sesion_finalizada':
        return Colors.blue;
      case 'sesion_forzada_cierre':
        return Colors.red;
      case 'registro_entrada':
        return Colors.purple;
      case 'registro_salida':
        return Colors.orange;
      case 'autorizacion_manual':
        return Colors.amber;
      case 'denegacion_acceso':
        return Colors.red[300]!;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconForTipo(String tipo) {
    switch (tipo) {
      case 'sesion_iniciada':
        return Icons.play_arrow;
      case 'sesion_finalizada':
        return Icons.stop;
      case 'sesion_forzada_cierre':
        return Icons.block;
      case 'registro_entrada':
        return Icons.login;
      case 'registro_salida':
        return Icons.logout;
      case 'autorizacion_manual':
        return Icons.check_circle;
      case 'denegacion_acceso':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  // ==================== VISTA 3: POR GUARDIA ====================

  Widget _buildPorGuardiaView() {
    return Consumer<HistorialActividadesViewModel>(builder: (context, viewModel, child) {
      if (viewModel.isLoading) {
        return LoadingWidget(message: 'Cargando datos por guardia...');
      }

      final guardias = viewModel.estadisticasComparativas;
      
      if (guardias.isEmpty) {
        return Center(
          child: Text('No hay datos de guardias disponibles'),
        );
      }

      return ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: guardias.length,
        itemBuilder: (context, index) {
          final guardia = guardias[index];
          return _buildGuardiaDetalleCard(guardia);
        },
      );
    });
  }

  Widget _buildGuardiaDetalleCard(EstadisticasGuardiaModel guardia) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.indigo[100],
          child: Text(
            guardia.guardiaNombre.split(' ').map((n) => n[0]).take(2).join(),
            style: TextStyle(color: Colors.indigo[700], fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(guardia.guardiaNombre),
        subtitle: Text('${guardia.totalRegistros} registros • ${guardia.horasTrabajadas.toStringAsFixed(1)}h'),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMetricaRow('Total de Sesiones:', '${guardia.totalSesiones}'),
                _buildMetricaRow('Horas Trabajadas:', '${guardia.horasTrabajadas.toStringAsFixed(1)}h'),
                _buildMetricaRow('Total Registros:', '${guardia.totalRegistros}'),
                _buildMetricaRow('Registros por Hora:', '${guardia.registrosPorHora.toStringAsFixed(1)}'),
                _buildMetricaRow('Autorizaciones Manuales:', '${guardia.autorizacionesManuales}'),
                _buildMetricaRow('Denegaciones:', '${guardia.denegaciones}'),
                _buildMetricaRow('Días Activos:', '${guardia.diasActivos}'),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        child: Text('Ver Actividades de Hoy'),
                        onPressed: () => _verActividadesHoy(guardia.guardiaId, guardia.guardiaNombre),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        child: Text('Ver Semana'),
                        onPressed: () => _verActividadesSemana(guardia.guardiaId, guardia.guardiaNombre),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricaRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ==================== VISTA 4: ESTADÍSTICAS ====================

  Widget _buildEstadisticasView() {
    return Consumer<HistorialActividadesViewModel>(builder: (context, viewModel, child) {
      if (viewModel.isLoading) {
        return LoadingWidget(message: 'Cargando estadísticas...');
      }

      return RefreshIndicator(
        onRefresh: () => viewModel.cargarEstadisticasComparativas(),
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            _buildRankingCard(viewModel),
            SizedBox(height: 16),
            _buildResumenGeneralCard(viewModel),
          ],
        ),
      );
    });
  }

  Widget _buildRankingCard(HistorialActividadesViewModel viewModel) {
    final guardias = viewModel.estadisticasComparativas;
    
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🏆 Ranking de Productividad',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            ...guardias.take(5).map((guardia) {
              final index = guardias.indexOf(guardia);
              return _buildRankingItem(guardia, index + 1);
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildRankingItem(EstadisticasGuardiaModel guardia, int posicion) {
    Color color = posicion == 1
        ? Colors.amber
        : posicion == 2
            ? Colors.grey
            : posicion == 3
                ? Colors.brown
                : Colors.blue;

    return ListTile(
      leading: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '$posicion',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      title: Text(guardia.guardiaNombre),
      subtitle: Text('${guardia.registrosPorHora.toStringAsFixed(1)} registros/hora'),
      trailing: Text(
        '${guardia.totalRegistros} registros',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildResumenGeneralCard(HistorialActividadesViewModel viewModel) {
    final guardias = viewModel.estadisticasComparativas;
    
    if (guardias.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No hay datos disponibles'),
        ),
      );
    }

    final totalRegistros = guardias.fold(0, (sum, g) => sum + g.totalRegistros);
    final totalHoras = guardias.fold(0.0, (sum, g) => sum + g.horasTrabajadas);
    final promedioProductividad = guardias.fold(0.0, (sum, g) => sum + g.registrosPorHora) / guardias.length;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📊 Resumen General',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            _buildMetricaRow('Total Guardias:', '${guardias.length}'),
            _buildMetricaRow('Total Registros:', '$totalRegistros'),
            _buildMetricaRow('Total Horas:', '${totalHoras.toStringAsFixed(1)}h'),
            _buildMetricaRow('Promedio Productividad:', '${promedioProductividad.toStringAsFixed(1)} reg/h'),
            SizedBox(height: 16),
            Text(
              'Mejor Guardia: ${guardias.isNotEmpty ? guardias.first.guardiaNombre : "N/A"}',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700]),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== MÉTODOS DE NAVEGACIÓN Y ACCIONES ====================

  Future<void> _seleccionarRangoFechas() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _fechaInicio != null && _fechaFin != null
          ? DateTimeRange(start: _fechaInicio!, end: _fechaFin!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _fechaInicio = picked.start;
        _fechaFin = picked.end;
      });
    }
  }

  Future<void> _aplicarFiltros() async {
    await _historialViewModel.aplicarFiltros(
      fechaInicio: _fechaInicio,
      fechaFin: _fechaFin,
      guardiaId: _guardiaSeleccionado,
      tipoActividad: _tipoActividadSeleccionado,
    );
  }

  void _limpiarFiltros() {
    setState(() {
      _fechaInicio = null;
      _fechaFin = null;
      _guardiaSeleccionado = null;
      _tipoActividadSeleccionado = null;
    });
    _historialViewModel.limpiarFiltros();
    _historialViewModel.cargarHistorialActividades();
  }

  void _mostrarDetalleGuardia(EstadisticasGuardiaModel guardia) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Detalles - ${guardia.guardiaNombre}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMetricaRow('ID Guardia:', guardia.guardiaId),
            _buildMetricaRow('Total Sesiones:', '${guardia.totalSesiones}'),
            _buildMetricaRow('Horas Trabajadas:', '${guardia.horasTrabajadas.toStringAsFixed(1)}h'),
            _buildMetricaRow('Total Registros:', '${guardia.totalRegistros}'),
            _buildMetricaRow('Registros/Hora:', '${guardia.registrosPorHora.toStringAsFixed(1)}'),
            _buildMetricaRow('Autorizaciones:', '${guardia.autorizacionesManuales}'),
            _buildMetricaRow('Denegaciones:', '${guardia.denegaciones}'),
            _buildMetricaRow('Días Activos:', '${guardia.diasActivos}'),
          ],
        ),
        actions: [
          TextButton(
            child: Text('Cerrar'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _verActividadesHoy(String guardiaId, String nombreGuardia) async {
    await _historialViewModel.cargarActividadesHoy(guardiaId);
    _mostrarActividades(nombreGuardia, _historialViewModel.actividadesHoy);
  }

  Future<void> _verActividadesSemana(String guardiaId, String nombreGuardia) async {
    await _historialViewModel.cargarActividadesSemana(guardiaId);
    _mostrarActividades(nombreGuardia, _historialViewModel.actividadesSemana);
  }

  void _mostrarActividades(String nombreGuardia, List<ActividadModel> actividades) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Actividades - $nombreGuardia'),
        content: Container(
          width: double.maxFinite,
          height: 300,
          child: actividades.isEmpty
              ? Center(child: Text('No hay actividades registradas'))
              : ListView.builder(
                  itemCount: actividades.length,
                  itemBuilder: (context, index) {
                    final actividad = actividades[index];
                    return ListTile(
                      leading: Icon(_getIconForTipo(actividad.tipoActividad)),
                      title: Text(actividad.tipoActividadDisplay),
                      subtitle: Text(actividad.fechaFormateada),
                      trailing: actividad.duracionSesion != null
                          ? Text(actividad.duracionFormateada)
                          : null,
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            child: Text('Cerrar'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
