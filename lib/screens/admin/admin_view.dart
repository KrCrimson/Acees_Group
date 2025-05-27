import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'add_edit_user_dialog.dart';
import 'user_card.dart';

class AdminView extends StatefulWidget {
  const AdminView({super.key});

  @override
  State<AdminView> createState() => _AdminViewState();
}

class _AdminViewState extends State<AdminView> {
  // Controladores para la búsqueda de guardias en la pestaña Guardias
  final _searchGuardiaController = TextEditingController();
  String _searchGuardiaQuery = '';
  int _currentTabIndex = 0;

  // Controladores y variables para los filtros de historial
  final _searchDniHistorialController = TextEditingController();
  final _searchCodigoUniHistorialController = TextEditingController();
  String? _selectedEntradaTipoHistorial;
  String? _selectedTipoRegistroHistorial;
  String? _selectedGuardiaHistorialId; // Nuevo: ID del guardia para filtro de historial

  // Variables para los filtros de reportes
  DateTime? _startDateReport;
  DateTime? _endDateReport;
  String? _selectedGuardiaReportesId; // Nuevo: ID del guardia para filtro de reportes
  String _selectedReportType = 'asistencias_por_puerta';

  // Lista de guardias para los Dropdowns
  List<DocumentSnapshot> _listaDeGuardias = [];

  // Lista de tipos de reportes disponibles
  final List<Map<String, String>> _reportTypes = [
    {'value': 'asistencias_por_puerta', 'label': 'Asistencias por Tipo de Puerta'},
    {'value': 'asistencias_por_tipo_registro', 'label': 'Asistencias por Entrada/Salida'},
    {'value': 'asistencias_por_dia_semana', 'label': 'Asistencias por Día de la Semana'},
    {'value': 'asistencias_por_guardia', 'label': 'Asistencias por Guardia'},
    {'value': 'actividad_guardia_hora', 'label': 'Actividad de Guardias por Hora'},
  ];


  @override
  void initState() {
    super.initState();
    _searchDniHistorialController.addListener(() => setState(() {}));
    _searchCodigoUniHistorialController.addListener(() => setState(() {}));
    // Inicializar fechas para reportes (opcional, ej. última semana)
    _endDateReport = DateTime.now();
    _startDateReport = _endDateReport!.subtract(const Duration(days: 7));
    _cargarGuardias(); // Cargar la lista de guardias al iniciar
  }

  Future<void> _cargarGuardias() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('rango', isEqualTo: 'guardia')
          .orderBy('nombre')
          .get();
      setState(() {
        _listaDeGuardias = querySnapshot.docs;
      });
    } catch (e) {
      debugPrint("Error cargando guardias: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar lista de guardias: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchGuardiaController.dispose();
    _searchDniHistorialController.dispose();
    _searchCodigoUniHistorialController.dispose();
    super.dispose();
  }

  void _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login'); // Asegúrate que esta ruta esté definida
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Panel de Administrador'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Cerrar sesión',
              onPressed: _signOut,
            ),
          ],
          bottom: TabBar(
            tabs: const [
              Tab(icon: Icon(Icons.security), text: 'Guardias'), // Pestaña de Guardias
              Tab(icon: Icon(Icons.history), text: 'Historial'), // Nueva pestaña de Historial
              Tab(icon: Icon(Icons.bar_chart), text: 'Reportes'), // Pestaña de Reportes
            ],
            onTap: (index) => setState(() => _currentTabIndex = index),
          ),
        ),
        body: Column(
          children: [
            // Mostrar la barra de búsqueda solo si la pestaña de Guardias está activa
            if (_currentTabIndex == 0)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _searchGuardiaController, // Cambiado a _searchGuardiaController
                  decoration: InputDecoration(
                    labelText: 'Buscar Guardia (Nombre o DNI)',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchGuardiaController.clear(); // Cambiado
                        setState(() => _searchGuardiaQuery = ''); // Cambiado
                      },
                    ),
                  ),
                  onChanged: (value) =>
                      setState(() => _searchGuardiaQuery = value.toLowerCase()), // Cambiado
                ),
              ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildUserList('guardia'),
                  _buildHistoryView(),
                  _buildReportsView(), // Vista de Reportes
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: _currentTabIndex == 0 // Mostrar solo en la pestaña de Guardias (índice 0)
            ? FloatingActionButton(
                onPressed: () => showAddEditUserDialog(
                  context,
                  userRole: 'guardia',
                ),
                child: const Icon(Icons.add),
              )
            : null,
      ),
    );
  }

  Widget _buildUserList(String role) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('usuarios')
          .where('rango', isEqualTo: role)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data!.docs.where((user) {
          final nombre = user['nombre'].toString().toLowerCase();
          final dni = user['dni'].toString().toLowerCase();
          // Usar _searchGuardiaQuery para filtrar guardias
          return nombre.contains(_searchGuardiaQuery) ||
              dni.contains(_searchGuardiaQuery);
        }).toList();

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) => UserCard(
            user: users[index],
            onEdit: () => showAddEditUserDialog(
              context,
              user: users[index],
              userRole: role,
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchDniHistorialController,
                      decoration: const InputDecoration(
                        labelText: 'Buscar por DNI Alumno',
                        suffixIcon: Icon(Icons.search),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchCodigoUniHistorialController,
                      decoration: const InputDecoration(
                        labelText: 'Buscar por Código Univ.',
                        suffixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Tipo de Entrada'),
                      value: _selectedEntradaTipoHistorial,
                      hint: const Text('Todos'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Todos')),
                        const DropdownMenuItem(value: 'principal', child: Text('Principal')),
                        const DropdownMenuItem(value: 'cochera', child: Text('Cochera')),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedEntradaTipoHistorial = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Tipo de Registro'),
                      value: _selectedTipoRegistroHistorial,
                      hint: const Text('Todos'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Todos')),
                        const DropdownMenuItem(value: 'entrada', child: Text('Entrada')),
                        const DropdownMenuItem(value: 'salida', child: Text('Salida')),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedTipoRegistroHistorial = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Nuevo Dropdown para filtrar por guardia en Historial
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Registrado por Guardia'),
                value: _selectedGuardiaHistorialId,
                hint: const Text('Todos los Guardias'),
                isExpanded: true,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todos los Guardias')),
                  ..._listaDeGuardias.map((guardiaDoc) {
                    final nombre = guardiaDoc['nombre'] ?? 'Sin nombre';
                    final apellido = guardiaDoc['apellido'] ?? '';
                    return DropdownMenuItem(
                      value: guardiaDoc.id,
                      child: Text('$nombre $apellido'),
                    );
                  }).toList(),
                ],
                onChanged: (value) {
                  setState(() => _selectedGuardiaHistorialId = value);
                },
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.clear_all),
                label: const Text('Limpiar Filtros'),
                onPressed: () {
                  _searchDniHistorialController.clear();
                  _searchCodigoUniHistorialController.clear();
                  setState(() {
                    _selectedEntradaTipoHistorial = null;
                    _selectedTipoRegistroHistorial = null;
                    _selectedGuardiaHistorialId = null; // Limpiar filtro de guardia
                  });
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('asistencias')
                .orderBy('fecha_hora', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final asistencias = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final dniQuery = _searchDniHistorialController.text.toLowerCase();
                final codigoUniQuery = _searchCodigoUniHistorialController.text.toLowerCase();
                final registradoPorData = data['registrado_por'] as Map<String, dynamic>?;

                bool matchesDni = dniQuery.isEmpty ||
                    (data['dni']?.toString().toLowerCase() ?? '').contains(dniQuery);
                bool matchesCodigoUni = codigoUniQuery.isEmpty ||
                    (data['codigo_universitario']?.toString().toLowerCase() ?? '').contains(codigoUniQuery);
                bool matchesEntradaTipo = _selectedEntradaTipoHistorial == null ||
                    data['entrada_tipo'] == _selectedEntradaTipoHistorial;
                bool matchesTipoRegistro = _selectedTipoRegistroHistorial == null ||
                    data['tipo'] == _selectedTipoRegistroHistorial;
                // Nuevo filtro por guardia
                bool matchesGuardia = _selectedGuardiaHistorialId == null ||
                    (registradoPorData != null && registradoPorData['uid'] == _selectedGuardiaHistorialId);
                
                return matchesDni && matchesCodigoUni && matchesEntradaTipo && matchesTipoRegistro && matchesGuardia;
              }).toList();

              if (asistencias.isEmpty) {
                return const Center(child: Text('No hay registros de asistencia que coincidan con los filtros.'));
              }

              return ListView.builder(
                itemCount: asistencias.length,
                itemBuilder: (context, index) {
                  final asistencia = asistencias[index].data() as Map<String, dynamic>;
                  final fechaHora = (asistencia['fecha_hora'] as Timestamp?)?.toDate();
                  final registradoPor = asistencia['registrado_por'] as Map<String, dynamic>? ?? {};

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: ListTile(
                      title: Text('${asistencia['nombre']} ${asistencia['apellido']}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('DNI: ${asistencia['dni'] ?? 'N/A'} - Cód. Univ: ${asistencia['codigo_universitario'] ?? 'N/A'}'),
                          Text('Fecha: ${fechaHora != null ? DateFormat('dd/MM/yyyy HH:mm:ss').format(fechaHora) : 'N/A'}'),
                          Text('Tipo: ${(asistencia['tipo'] as String?)?.toUpperCase() ?? 'N/A'} - Puerta: ${(asistencia['entrada_tipo'] as String?)?.toUpperCase() ?? 'N/A'}'),
                          Text('Facultad: ${asistencia['siglas_facultad'] ?? 'N/A'} - Escuela: ${asistencia['siglas_escuela'] ?? 'N/A'}'),
                          if (registradoPor.isNotEmpty)
                             Text('Registrado por: ${registradoPor['nombre'] ?? ''} ${registradoPor['apellido'] ?? ''} (${registradoPor['rango'] ?? 'N/A'})'),
                        ],
                      ),
                      isThreeLine: true, // Ajustar según el contenido
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // Nueva función para construir la vista de reportes
  Widget _buildReportsView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Seleccionar Tipo de Reporte'),
                value: _selectedReportType,
                items: _reportTypes.map((report) {
                  return DropdownMenuItem<String>(
                    value: report['value'],
                    child: Text(report['label']!),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedReportType = value);
                  }
                },
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_startDateReport != null
                        ? DateFormat('dd/MM/yyyy').format(_startDateReport!)
                        : 'Fecha Inicio'),
                    onPressed: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _startDateReport ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: _endDateReport ?? DateTime.now(),
                      );
                      if (pickedDate != null) {
                        setState(() => _startDateReport = pickedDate);
                      }
                    },
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_endDateReport != null
                        ? DateFormat('dd/MM/yyyy').format(_endDateReport!)
                        : 'Fecha Fin'),
                    onPressed: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _endDateReport ?? DateTime.now(),
                        firstDate: _startDateReport ?? DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (pickedDate != null) {
                        // Asegurar que la fecha final no sea anterior a la inicial
                        if(_startDateReport != null && pickedDate.isBefore(_startDateReport!)){
                           ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('La fecha final no puede ser anterior a la fecha inicial.'))
                           );
                           return;
                        }
                        setState(() => _endDateReport = pickedDate);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Nuevo Dropdown para filtrar por guardia en Reportes
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Filtrar por Guardia'),
                value: _selectedGuardiaReportesId,
                hint: const Text('Todos los Guardias'),
                isExpanded: true,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todos los Guardias')),
                  ..._listaDeGuardias.map((guardiaDoc) {
                     final nombre = guardiaDoc['nombre'] ?? 'Sin nombre';
                    final apellido = guardiaDoc['apellido'] ?? '';
                    return DropdownMenuItem(
                      value: guardiaDoc.id,
                      child: Text('$nombre $apellido'),
                    );
                  }).toList(),
                ],
                onChanged: (value) {
                  setState(() => _selectedGuardiaReportesId = value);
                },
              ),
               const SizedBox(height: 8),
              ElevatedButton.icon( // Botón para limpiar filtros de reportes
                icon: const Icon(Icons.clear_all),
                label: const Text('Limpiar Filtros de Reporte'),
                onPressed: () {
                  setState(() {
                    _endDateReport = DateTime.now();
                    _startDateReport = _endDateReport!.subtract(const Duration(days: 7));
                    _selectedGuardiaReportesId = null;
                    // _selectedReportType se mantiene o se resetea según preferencia
                  });
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('asistencias').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final allAsistencias = snapshot.data!.docs;
              List<DocumentSnapshot> filteredAsistencias = allAsistencias.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final fechaHora = (data['fecha_hora'] as Timestamp?)?.toDate();
                if (fechaHora == null) return false;

                bool inDateRange = true;
                if (_startDateReport != null && _endDateReport != null) {
                  DateTime endDateEndOfDay = DateTime(_endDateReport!.year, _endDateReport!.month, _endDateReport!.day, 23, 59, 59);
                  inDateRange = fechaHora.isAfter(_startDateReport!.subtract(const Duration(microseconds: 1))) &&
                                fechaHora.isBefore(endDateEndOfDay.add(const Duration(microseconds: 1)));
                }
                
                // Aplicar filtro de guardia si está seleccionado
                bool matchesGuardia = _selectedGuardiaReportesId == null ||
                    (data['registrado_por'] as Map<String,dynamic>?)?['uid'] == _selectedGuardiaReportesId;

                return inDateRange && matchesGuardia;
              }).toList();

              if (filteredAsistencias.isEmpty) {
                return const Center(child: Text('No hay datos de asistencia para el rango de fechas y filtros seleccionados.'));
              }
              
              Widget chartWidget;
              switch (_selectedReportType) {
                case 'asistencias_por_puerta':
                  chartWidget = _buildAsistenciasPorPuertaChart(filteredAsistencias);
                  break;
                case 'asistencias_por_tipo_registro':
                  chartWidget = _buildAsistenciasPorTipoRegistroChart(filteredAsistencias);
                  break;
                case 'asistencias_por_dia_semana':
                  chartWidget = _buildAsistenciasPorDiaSemanaChart(filteredAsistencias);
                  break;
                case 'asistencias_por_guardia':
                  chartWidget = _buildAsistenciasPorGuardiaChart(filteredAsistencias, _listaDeGuardias);
                  break;
                case 'actividad_guardia_hora':
                  chartWidget = _buildActividadGuardiaPorHoraChart(filteredAsistencias);
                  break;
                default:
                  chartWidget = const Center(child: Text('Seleccione un tipo de reporte para visualizar.'));
              }
              
              // El chartWidget devuelto por cada _build...Chart ya debería tener un SizedBox con altura.
              // El SingleChildScrollView permite el scroll si el contenido (filtros + gráfico) es muy alto.
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(child: chartWidget),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAsistenciasPorPuertaChart(List<DocumentSnapshot> asistencias) {
    Map<String, int> counts = {'principal': 0, 'cochera': 0};
    for (var doc in asistencias) {
      final data = doc.data() as Map<String, dynamic>;
      final tipoPuerta = data['entrada_tipo'] as String?;
      if (tipoPuerta != null && counts.containsKey(tipoPuerta)) {
        counts[tipoPuerta] = counts[tipoPuerta]! + 1;
      }
    }

    List<PieChartSectionData> sections = [];
    int total = counts.values.fold(0, (sum, item) => sum + item);
    if (total == 0) return const Center(child: Text('No hay datos para este gráfico.'));

    counts.forEach((key, value) {
      final percentage = (value / total * 100).toStringAsFixed(1);
      sections.add(PieChartSectionData(
        color: key == 'principal' ? Colors.blueAccent : Colors.orangeAccent,
        value: value.toDouble(),
        title: '${key.toUpperCase()}\n$value ($percentage%)',
        radius: 100,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ));
    });

    return SizedBox( // Añadir SizedBox con altura
      height: 300,
      child: PieChart(
        PieChartData(
          sections: sections,
          sectionsSpace: 2,
          centerSpaceRadius: 40,
          pieTouchData: PieTouchData(
            touchCallback: (FlTouchEvent event, pieTouchResponse) {
              // Se puede añadir interactividad aquí
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAsistenciasPorTipoRegistroChart(List<DocumentSnapshot> asistencias) {
    Map<String, int> counts = {'entrada': 0, 'salida': 0};
    for (var doc in asistencias) {
      final data = doc.data() as Map<String, dynamic>;
      final tipoRegistro = data['tipo'] as String?;
      if (tipoRegistro != null && counts.containsKey(tipoRegistro)) {
        counts[tipoRegistro] = counts[tipoRegistro]! + 1;
      }
    }

    List<PieChartSectionData> sections = [];
    int total = counts.values.fold(0, (sum, item) => sum + item);
    if (total == 0) return const Center(child: Text('No hay datos para este gráfico.'));
    
    counts.forEach((key, value) {
      final percentage = (value / total * 100).toStringAsFixed(1);
      sections.add(PieChartSectionData(
        color: key == 'entrada' ? Colors.greenAccent : Colors.redAccent,
        value: value.toDouble(),
        title: '${key.toUpperCase()}\n$value ($percentage%)',
        radius: 100,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ));
    });

    return SizedBox( // Añadir SizedBox con altura
      height: 300,
      child: PieChart(
        PieChartData(
          sections: sections,
          sectionsSpace: 2,
          centerSpaceRadius: 40,
        ),
      ),
    );
  }

  Widget _buildAsistenciasPorDiaSemanaChart(List<DocumentSnapshot> asistencias) {
    // Lunes (1) a Domingo (7)
    Map<int, int> counts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};
    List<String> diasSemana = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

    for (var doc in asistencias) {
      final data = doc.data() as Map<String, dynamic>;
      final fechaHora = (data['fecha_hora'] as Timestamp?)?.toDate();
      if (fechaHora != null) {
        counts[fechaHora.weekday] = (counts[fechaHora.weekday] ?? 0) + 1;
      }
    }

    List<BarChartGroupData> barGroups = [];
    int maxY = 0;
    counts.forEach((key, value) {
      if (value > maxY) maxY = value;
      barGroups.add(
        BarChartGroupData(
          x: key,
          barRods: [
            BarChartRodData(
              toY: value.toDouble(),
              color: Colors.teal,
              width: 16,
            ),
          ],
        ),
      );
    });
    
    if (maxY == 0) return const Center(child: Text('No hay datos para este gráfico.'));

    return SizedBox( // Añadir SizedBox con altura
      height: 300,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY.toDouble() + (maxY * 0.1), // Un poco de espacio arriba
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (BarChartGroupData group) => Colors.blueGrey, // Corregido
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                String weekDay = diasSemana[group.x.toInt() - 1];
                return BarTooltipItem(
                  '$weekDay\n',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  children: <TextSpan>[
                    TextSpan(
                      text: (rod.toY.toInt()).toString(),
                      style: const TextStyle(
                        color: Colors.yellow, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Text(diasSemana[value.toInt() - 1], style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
                  );
                },
                reservedSize: 38,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: maxY > 10 ? (maxY/5).roundToDouble() : 1),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barGroups: barGroups,
          gridData: const FlGridData(show: true, drawVerticalLine: false),
        ),
      ),
    );
  }

  // Nuevo gráfico: Asistencias por Guardia
  Widget _buildAsistenciasPorGuardiaChart(List<DocumentSnapshot> asistencias, List<DocumentSnapshot> guardias) {
    if (asistencias.isEmpty) return const Center(child: Text('No hay datos para este gráfico.'));

    Map<String, int> countsByGuardiaId = {};
    for (var doc in asistencias) {
      final data = doc.data() as Map<String, dynamic>;
      final registradoPor = data['registrado_por'] as Map<String, dynamic>?;
      if (registradoPor != null && registradoPor['uid'] != null) {
        final guardiaId = registradoPor['uid'] as String;
        countsByGuardiaId[guardiaId] = (countsByGuardiaId[guardiaId] ?? 0) + 1;
      }
    }

    if (countsByGuardiaId.isEmpty) return const Center(child: Text('No hay asistencias registradas por guardias para el periodo seleccionado.'));
    
    List<BarChartGroupData> barGroups = [];
    int i = 0;
    int maxY = 0;

    // Crear un mapa de ID de guardia a nombre para fácil acceso
    Map<String, String> nombresGuardias = {};
    for (var guardiaDoc in guardias) {
      nombresGuardias[guardiaDoc.id] = "${guardiaDoc['nombre'] ?? ''} ${guardiaDoc['apellido'] ?? ''}".trim();
    }

    countsByGuardiaId.forEach((guardiaId, count) {
      if (count > maxY) maxY = count;
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(toY: count.toDouble(), color: Colors.deepPurpleAccent, width: 22),
          ],
        ),
      );
      i++;
    });
     if (maxY == 0) return const Center(child: Text('No hay datos para este gráfico.'));

    return SizedBox( // Envolver en SizedBox para controlar altura
      height: 300,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY.toDouble() + (maxY * 0.1),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (BarChartGroupData group) => Colors.blueGrey,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                // Encontrar el guardiaId basado en el groupIndex (x)
                String guardiaId = countsByGuardiaId.keys.elementAt(group.x.toInt());
                String nombreGuardia = nombresGuardias[guardiaId] ?? 'Desconocido';
                return BarTooltipItem(
                  '$nombreGuardia\n',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  children: <TextSpan>[
                    TextSpan(
                      text: rod.toY.toInt().toString(),
                      style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.w500),
                    ),
                  ],
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  if (value.toInt() >= countsByGuardiaId.keys.length) return const Text('');
                  String guardiaId = countsByGuardiaId.keys.elementAt(value.toInt());
                  String nombreCorto = (nombresGuardias[guardiaId] ?? 'ID: ${guardiaId.substring(0,5)}');
                  // Acortar nombres largos si es necesario
                  if (nombreCorto.length > 10) nombreCorto = '${nombreCorto.substring(0,8)}...';
                  return Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Text(nombreCorto, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  );
                },
                reservedSize: 42, // Aumentar si los nombres son largos
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 30, interval: maxY > 10 ? (maxY/5).roundToDouble() : 1),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barGroups: barGroups,
          gridData: const FlGridData(show: true, drawVerticalLine: false),
        ),
      ),
    );
  }

  // Nuevo gráfico: Actividad de Guardias por Hora del Día
  Widget _buildActividadGuardiaPorHoraChart(List<DocumentSnapshot> asistencias) {
    if (asistencias.isEmpty) return const Center(child: Text('No hay datos para este gráfico.'));

    Map<int, int> countsByHour = {}; // Hora (0-23) -> Cantidad
    for (int i = 0; i < 24; i++) {
      countsByHour[i] = 0; // Inicializar todas las horas
    }

    for (var doc in asistencias) {
      final data = doc.data() as Map<String, dynamic>;
      final fechaHora = (data['fecha_hora'] as Timestamp?)?.toDate();
      if (fechaHora != null) {
        countsByHour[fechaHora.hour] = (countsByHour[fechaHora.hour] ?? 0) + 1;
      }
    }
    
    List<BarChartGroupData> barGroups = [];
    int maxY = 0;
    countsByHour.forEach((hour, count) {
      if (count > maxY) maxY = count;
      barGroups.add(
        BarChartGroupData(
          x: hour,
          barRods: [
            BarChartRodData(toY: count.toDouble(), color: Colors.lightGreen, width: 14),
          ],
        ),
      );
    });

    if (maxY == 0) return const Center(child: Text('No hay datos de actividad por hora.'));

    return SizedBox( // Envolver en SizedBox para controlar altura
      height: 300,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY.toDouble() + (maxY * 0.1),
           barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (BarChartGroupData group) => Colors.blueGrey,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${group.x.toInt()}:00-${group.x.toInt() + 1}:00\n',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  children: <TextSpan>[
                    TextSpan(
                      text: rod.toY.toInt().toString(),
                      style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.w500),
                    ),
                  ],
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Text('${value.toInt()}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  );
                },
                reservedSize: 28,
                interval: 2, // Mostrar cada 2 horas
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 30, interval: maxY > 10 ? (maxY/5).roundToDouble() : 1),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barGroups: barGroups,
          gridData: const FlGridData(show: true, drawVerticalLine: false),
        ),
      ),
    );
  }
}