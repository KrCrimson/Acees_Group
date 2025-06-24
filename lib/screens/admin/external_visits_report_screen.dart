import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class ExternalVisitsReportScreen extends StatefulWidget {
  const ExternalVisitsReportScreen({Key? key}) : super(key: key);

  @override
  State<ExternalVisitsReportScreen> createState() => _ExternalVisitsReportScreenState();
}

class _ExternalVisitsReportScreenState extends State<ExternalVisitsReportScreen> {
  String _selectedTimeRange = 'day'; // Default time range
  String _selectedChartType = 'pie'; // Default chart type
  List<Map<String, dynamic>> _visitData = [];
  bool _isLoading = false;
  bool _showList = true; // Default view is list

  @override
  void initState() {
    super.initState();
    _loadVisitData();
  }

  Future<void> _loadVisitData() async {
    setState(() {
      _isLoading = true;
      _visitData = [];
    });

    try {
      Query query = FirebaseFirestore.instance.collection('visitas');

      final now = DateTime.now();
      if (_selectedTimeRange == 'day') {
        query = query.where('fecha_hora', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(now.year, now.month, now.day)));
      } else if (_selectedTimeRange == 'week') {
        query = query.where('fecha_hora', isGreaterThanOrEqualTo: Timestamp.fromDate(now.subtract(const Duration(days: 7))));
      } else if (_selectedTimeRange == 'month') {
        query = query.where('fecha_hora', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(now.year, now.month, 1)));
      } else if (_selectedTimeRange == 'year') {
        query = query.where('fecha_hora', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(now.year, 1, 1)));
      }

      final snapshot = await query.get();

      setState(() {
        _visitData = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _visitData = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: ${e.toString()}')),
      );
    }
  }

  Widget _buildChart() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_visitData.isEmpty) {
      return const Center(child: Text('No visit data available.'));
    }

    Map<String, int> visitCounts = {};
    for (var visit in _visitData) {
      final name = visit['nombre'] ?? 'Desconocido';
      visitCounts[name] = (visitCounts[name] ?? 0) + 1;
    }

    if (_selectedChartType == 'pie') {
      List<PieChartSectionData> sections = [];
      int totalVisits = visitCounts.values.fold(0, (sum, count) => sum + count);
      visitCounts.forEach((name, count) {
        final percentage = (count / totalVisits) * 100;
        sections.add(
          PieChartSectionData(
            value: percentage,
            title: '$name ($count)',
            color: _getChartColor(visitCounts.keys.toList().indexOf(name)),
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
          ),
        );
      });

      return SizedBox(
        height: 400,
        child: PieChart(
          PieChartData(
            sections: sections,
            centerSpaceRadius: 60,
            borderData: FlBorderData(show: false),
          ),
        ),
      );
    } else if (_selectedChartType == 'bar') {
      List<BarChartGroupData> barGroups = [];
      visitCounts.forEach((name, count) {
        barGroups.add(
          BarChartGroupData(
            x: visitCounts.keys.toList().indexOf(name),
            barRods: [
              BarChartRodData(
                toY: count.toDouble(),
                color: _getChartColor(visitCounts.keys.toList().indexOf(name)),
                width: 16,
              ),
            ],
          ),
        );
      });

      return SizedBox(
        height: 400,
        child: BarChart(
          BarChartData(
            barGroups: barGroups,
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index >= 0 && index < visitCounts.keys.toList().length) {
                      return Text(
                        '${visitCounts.keys.toList()[index]} (${visitCounts.values.toList()[index]})',
                        style: const TextStyle(fontSize: 10, color: Colors.black),
                      );
                    }
                    return const Text('');
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) => Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10, color: Colors.black),
                  ),
                ),
              ),
              topTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
          ),
        ),
      );
    }

    return const Center(child: Text('Invalid chart type.'));
  }

  Widget _buildExternalVisitorsList() {
    Map<String, int> visitCounts = {};
    for (var visit in _visitData) {
      final name = visit['nombre'] ?? 'Desconocido';
      visitCounts[name] = (visitCounts[name] ?? 0) + 1;
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('externos').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No hay registros de externos.'));
        }

        final externalVisitors = snapshot.data!.docs;

        return ListView.builder(
          itemCount: externalVisitors.length,
          itemBuilder: (context, index) {
            final visitor = externalVisitors[index].data() as Map<String, dynamic>;
            final name = visitor['nombre'] ?? 'Desconocido';
            final visitCount = visitCounts[name] ?? 0;

            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.0),
              ),
              elevation: 5,
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.indigo,
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                title: Text(
                  '$name ($visitCount visitas)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  'DNI: ${visitor['dni'] ?? 'Sin DNI'}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
            );
          },
        );
      },
    );
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
      Colors.cyan,
      Colors.pink,
    ];
    return colorPalette[index % colorPalette.length];
  }

  Widget _buildToggleButton() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
              onPressed: () {
                setState(() {
                  _selectedTimeRange = 'day';
                  _loadVisitData();
                });
              },
              child: const Text('Hoy', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
              onPressed: () {
                setState(() {
                  _selectedTimeRange = 'week';
                  _loadVisitData();
                });
              },
              child: const Text('Semana', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
              onPressed: () {
                setState(() {
                  _selectedTimeRange = 'month';
                  _loadVisitData();
                });
              },
              child: const Text('Mes', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
              onPressed: () {
                setState(() {
                  _selectedTimeRange = 'year';
                  _loadVisitData();
                });
              },
              child: const Text('Año', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
              onPressed: () {
                setState(() {
                  _showList = true;
                });
              },
              child: const Text('Ver Listado', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 2),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50.0),
                ),
              ),
              onPressed: () {
                setState(() {
                  _showList = false;
                });
              },
              child: const Text('Ver Gráficos', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.indigo[700],
        title: Text(
          'Reporte de Visitas Externas',
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
            _buildToggleButton(),
            const SizedBox(height: 20),
            Expanded(
              child: _showList ? _buildExternalVisitorsList() : _buildChart(),
            ),
          ],
        ),
      ),
    );
  }
}
