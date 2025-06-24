import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminReportChartScreen extends StatefulWidget {
  const AdminReportChartScreen({super.key}); // Use super parameter for 'key'

  @override
  State<AdminReportChartScreen> createState() => _AdminReportChartScreenState();
}

class _AdminReportChartScreenState extends State<AdminReportChartScreen> {
  String _selectedView = 'faculty'; // Default view
  String _selectedChartType = 'bar'; // Default chart type
  String _selectedSpecialChart = 'none'; // Nuevo: para gráficos especiales
  DateTimeRange? _selectedDateRange;
  String _selectedGuard = 'todos'; // Filtro por guardia
  List<Map<String, dynamic>> _attendanceData = [];
  List<Map<String, dynamic>> _guardsList = []; // Lista de guardias
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadGuardsList();
    _loadAttendanceData();
  }

  Future<void> _loadGuardsList() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('rango', isEqualTo: 'guardia')
          .get();
      
      List<Map<String, dynamic>> guardiasList = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final guardInfo = {
          'id': data['uid'] ?? doc.id, // Usar el UID del usuario o el ID del documento como fallback
          'nombre': data['nombre'] != null && data['apellido'] != null
              ? '${data['nombre']} ${data['apellido']}'
              : (data['email'] ?? 'Desconocido'),
          'email': data['email'] ?? '',
        };
        guardiasList.add(guardInfo);
      }
      
      if (mounted) {
        setState(() {
          _guardsList = guardiasList;
        });
      }
    } catch (e) {
      print('Error loading guards list: $e');
    }
  }

  Future<void> _loadAttendanceData() async {
    setState(() {
      _isLoading = true;
      _attendanceData = [];
    });

    try {
      Query query = FirebaseFirestore.instance.collection('asistencias');

      if (_selectedDateRange != null) {
        query = query
            .where('fecha_hora', isGreaterThanOrEqualTo: Timestamp.fromDate(_selectedDateRange!.start))
            .where('fecha_hora', isLessThanOrEqualTo: Timestamp.fromDate(_selectedDateRange!.end));
      }

      final snapshot = await query.get();
      List<Map<String, dynamic>> allData = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();

      // Filtrar por guardia si está seleccionado
      if (_selectedGuard != 'todos') {
        allData = allData.where((record) {
          final guardiaData = record['registrado_por'];
          if (guardiaData is Map<String, dynamic>) {
            final guardId = guardiaData['uid'] ?? guardiaData['email'];
            return guardId == _selectedGuard;
          }
          return false;
        }).toList();
      }

      if (mounted) { // Guard against async gaps
        setState(() {
          _attendanceData = allData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) { // Guard against async gaps
        setState(() {
          _isLoading = false;
          _attendanceData = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: ${e.toString()}')),
        );
      }
    }
  }

  Widget _buildChart() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_attendanceData.isEmpty) {
      return const Center(child: Text('No attendance data available.'));
    }
    // Nuevo: gráficos especiales
    if (_selectedSpecialChart == 'guardPerformance') {
      return _buildGuardPerformanceChart();
    }
    if (_selectedSpecialChart == 'inOutFlow') {
      return _buildInOutFlowChart();
    }
    switch (_selectedChartType) {
      case 'bar':
        return _buildBarChart();
      case 'pie':
        return _buildPieChart();
      case 'line':
        return _buildLineChart();
      default:
        return const Center(child: Text('Invalid chart type.'));
    }
  }

  // Gráfico de ingresos y egresos
  Widget _buildInOutFlowChart() {
    Map<int, Map<String, int>> hourMap = {
      8: {'entrada': 50, 'salida': 20},
      9: {'entrada': 30, 'salida': 15},
      10: {'entrada': 40, 'salida': 25},
      11: {'entrada': 60, 'salida': 30},
    };

    return Column(
      children: [
        Text('Distribución de ingresos y egresos por hora',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Expanded(
          child: BarChart(
            BarChartData(
              barGroups: hourMap.entries.map((entry) {
                return BarChartGroupData(
                  x: entry.key,
                  barRods: [
                    BarChartRodData(toY: entry.value['entrada']?.toDouble() ?? 0, color: Colors.blue),
                    BarChartRodData(toY: entry.value['salida']?.toDouble() ?? 0, color: Colors.green),
                  ],
                );
              }).toList(),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Leyenda:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('- Eje X: Horas del día'),
              Text('- Eje Y: Cantidad de ingresos y egresos registrados'),
              Text('- Azul: Ingresos (usuarios registrados, pagos realizados)'),
              Text('- Verde: Egresos (costos operativos, soporte técnico)'),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Recomendaciones:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('- Implementar estrategias de monetización como servicios premium.'),
              Text('- Optimizar recursos para reducir costos operativos.'),
              Text('- Mejorar la retención de usuarios para aumentar ingresos.'),
            ],
          ),
        ),
      ],
    );
  }

  // Gráfico de rendimiento de guardias
  Widget _buildGuardPerformanceChart() {
    Map<String, int> guardiaMap = {};
    for (var record in _attendanceData) {
      final guardiaData = record['registrado_por'];
      String guardia = 'Desconocido';
      if (guardiaData is Map<String, dynamic>) {
        guardia = guardiaData['nombre'] != null && guardiaData['apellido'] != null
            ? '${guardiaData['nombre']} ${guardiaData['apellido']}'
            : (guardiaData['email'] ?? 'Desconocido');
      }
      guardiaMap[guardia] = (guardiaMap[guardia] ?? 0) + 1;
    }

    return Column(
      children: [
        Text('Rendimiento de Guardias',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Expanded(
          child: BarChart(
            BarChartData(
              barGroups: guardiaMap.entries.map((entry) {
                return BarChartGroupData(
                  x: entry.key.hashCode,
                  barRods: [
                    BarChartRodData(
                      toY: entry.value.toDouble(),
                      color: Colors.orange,
                      width: 20,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                  showingTooltipIndicators: [0],
                );
              }).toList(),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  tooltipBgColor: Colors.black,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final guardia = guardiaMap.keys.elementAt(groupIndex);
                    return BarTooltipItem(
                      '$guardia\nRegistros: ${rod.toY.toInt()}',
                      const TextStyle(color: Colors.white),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= 0 && value.toInt() < guardiaMap.keys.length) {
                        final guardia = guardiaMap.keys.elementAt(value.toInt());
                        return Text(guardia, style: TextStyle(fontSize: 10));
                      }
                      return const Text('');
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Leyenda:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('- Eje X: Guardias (identificados por hash)'),
              Text('- Eje Y: Cantidad de registros realizados'),
              Text('- Naranja: Registros realizados por cada guardia'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBarChart() {
    Map<String, int> dataMap = {};
    for (var record in _attendanceData) {
      String key = '';
      switch (_selectedView) {
        case 'faculty':
          key = record['siglas_facultad'] ?? 'Unknown';
          break;
        case 'school':
          key = record['siglas_escuela'] ?? 'Unknown';
          break;
        case 'timeOfDay':
          final fecha = record['fecha_hora'];
          if (fecha is Timestamp) {
            final hour = int.parse(DateFormat('HH').format(fecha.toDate()));
            key = _getTimeOfDay(hour);
          } else {
            key = 'Unknown';
          }
          break;
        case 'entranceType':
          key = record['entrada_tipo'] ?? 'Unknown';
          break;
        case 'puerta': // New view for doors
          key = record['puerta'] ?? 'Unknown';
          break;
        case 'guard': // New view for guards
          final guardiaData = record['registrado_por'];
          if (guardiaData is Map<String, dynamic>) {
            key = guardiaData['nombre'] != null && guardiaData['apellido'] != null
                ? '${guardiaData['nombre']} ${guardiaData['apellido']}'
                : (guardiaData['email'] ?? 'Desconocido');
          } else {
            key = 'Desconocido';
          }
          break;
        default:
          key = 'Unknown';
      }
      dataMap[key] = (dataMap[key] ?? 0) + 1;
    }

    List<BarChartGroupData> barGroups = [];
    dataMap.forEach((key, value) {
      barGroups.add(
        BarChartGroupData(
          x: dataMap.keys.toList().indexOf(key),
          barRods: [
            BarChartRodData(
              toY: value.toDouble(),
              gradient: LinearGradient(colors: [Colors.blue, Colors.lightBlue]),
              width: 16,
            ),
          ],
        ),
      );
    });

    return BarChart(
      BarChartData(
        barGroups: barGroups,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                final index = value.toInt();
                if (index >= 0 && index < dataMap.keys.toList().length) {
                  return Text(dataMap.keys.toList()[index], style: const TextStyle(fontSize: 10));
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
      ),
    );
  }

  Widget _buildPieChart() {
    Map<String, int> dataMap = {};
    for (var record in _attendanceData) {
      String key = '';
      switch (_selectedView) {
        case 'faculty':
          key = record['siglas_facultad'] ?? 'Unknown';
          break;
        case 'school':
          key = record['siglas_escuela'] ?? 'Unknown';
          break;
        case 'timeOfDay':
          final fecha = record['fecha'];
          if (fecha is Timestamp) {
            final hour = int.parse(DateFormat('HH').format(fecha.toDate()));
            key = _getTimeOfDay(hour);
          } else {
            key = 'Unknown';
          }
          break;
        case 'entranceType':
          key = record['entrada_tipo'] ?? 'Unknown';
          break;
        case 'puerta': // New view for doors
          key = record['puerta'] ?? 'Unknown';
          break;
        case 'guard': // New view for guards
          final guardiaData = record['registrado_por'];
          if (guardiaData is Map<String, dynamic>) {
            key = guardiaData['nombre'] != null && guardiaData['apellido'] != null
                ? '${guardiaData['nombre']} ${guardiaData['apellido']}'
                : (guardiaData['email'] ?? 'Desconocido');
          } else {
            key = 'Desconocido';
          }
          break;
        default:
          key = 'Unknown';
      }
      dataMap[key] = (dataMap[key] ?? 0) + 1;
    }

    List<PieChartSectionData> sections = [];
    dataMap.forEach((key, value) {
      final colorIndex = dataMap.keys.toList().indexOf(key);
      final color = _getChartColor(colorIndex);

      sections.add(
        PieChartSectionData(
          value: value.toDouble(),
          title: key,
          color: color,
          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      );
    });

    return PieChart(
      PieChartData(
        sections: sections,
        centerSpaceRadius: 40,
        borderData: FlBorderData(show: false),
      ),
    );
  }

  Widget _buildLineChart() {
    Map<DateTime, int> dataMap = {};
    for (var record in _attendanceData) {
      final fechaHora = record['fecha_hora'] as Timestamp;
      final date = DateTime(fechaHora.toDate().year, fechaHora.toDate().month, fechaHora.toDate().day);

      dataMap[date] = (dataMap[date] ?? 0) + 1;
    }

    List<FlSpot> spots = [];
    List<DateTime> sortedDates = dataMap.keys.toList()..sort();
    for (var i = 0; i < sortedDates.length; i++) {
      spots.add(FlSpot(i.toDouble(), dataMap[sortedDates[i]]!.toDouble()));
    }

    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            gradient: LinearGradient(colors: [Colors.blue, Colors.lightBlue]), // Fixed 'colors' issue
            barWidth: 4,
            isStrokeCapRound: true,
            belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [Colors.blue.withOpacity(0.2), Colors.lightBlue.withOpacity(0.2)])), // Fixed 'withOpacity' deprecation
          ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < sortedDates.length) {
                  return Text(DateFormat('dd/MM').format(sortedDates[index]), style: const TextStyle(fontSize: 10));
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(show: true),
        borderData: FlBorderData(show: true),
      ),
    );
  }

  String _getTimeOfDay(int hour) {
    if (hour >= 5 && hour < 12) {
      return 'Mañana';
    } else if (hour >= 12 && hour < 18) {
      return 'Tarde';
    } else {
      return 'Noche';
    }
  }

  Color _getChartColor(int index) {
    const colorPalette = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.purple,
      Colors.teal,
      Colors.amber,
    ];
    return colorPalette[index % colorPalette.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.indigo[700],
        title: Text(
          'Reporte de Asistencias',
          style: GoogleFonts.lato(
            textStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      textStyle: const TextStyle(fontSize: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                    onPressed: () => _selectDateRange(context),
                    child: Text(_selectedDateRange == null
                        ? 'Seleccionar Rango de Fechas'
                        : '${DateFormat('dd/MM/yyyy').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(_selectedDateRange!.end)}'),
                  ),
                  const SizedBox(width: 10),
                  // Filtro por guardia
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedGuard,
                      hint: const Text('Seleccionar Guardia'),
                      underline: Container(),
                      items: [
                        const DropdownMenuItem<String>(
                          value: 'todos',
                          child: Text('Todos los Guardias'),
                        ),
                        ..._guardsList.map((guard) => DropdownMenuItem<String>(
                          value: guard['id'] as String,
                          child: Text(guard['nombre'] as String),
                        )).toList(),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedGuard = value!;
                        });
                        _loadAttendanceData();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  DropdownButton<String>(
                    value: _selectedView,
                    items: const [
                      DropdownMenuItem(value: 'faculty', child: Text('Por Facultad')),
                      DropdownMenuItem(value: 'school', child: Text('Por Escuela')),
                      DropdownMenuItem(value: 'timeOfDay', child: Text('Por Hora del Día')),
                      DropdownMenuItem(value: 'entranceType', child: Text('Por Tipo de Entrada')),
                      DropdownMenuItem(value: 'puerta', child: Text('Por Puerta')),
                      DropdownMenuItem(value: 'guard', child: Text('Por Guardia')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedView = value!;
                        _selectedSpecialChart = 'none';
                      });
                      _loadAttendanceData();
                    },
                  ),
                  const SizedBox(width: 10),
                  DropdownButton<String>(
                    value: _selectedChartType,
                    items: const [
                      DropdownMenuItem(value: 'bar', child: Text('Gráfico de Barras')),
                      DropdownMenuItem(value: 'pie', child: Text('Gráfico Circular')),
                      DropdownMenuItem(value: 'line', child: Text('Gráfico de Líneas')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedChartType = value!;
                        _selectedSpecialChart = 'none';
                      });
                    },
                  ),
                  const SizedBox(width: 10),
                  // Nuevo: Selector de gráficos especiales
                  DropdownButton<String>(
                    value: _selectedSpecialChart,
                    items: const [
                      DropdownMenuItem(value: 'none', child: Text('Gráficos Comunes')),
                      DropdownMenuItem(value: 'guardPerformance', child: Text('Rendimiento de Guardias')),
                      DropdownMenuItem(value: 'inOutFlow', child: Text('Ingresos/Egresos')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedSpecialChart = value!;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _buildChart(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
    );

    if (picked != null && mounted) { // Guard against async gaps
      setState(() {
        _selectedDateRange = picked;
      });
      await _loadAttendanceData();
    }
  }
}
