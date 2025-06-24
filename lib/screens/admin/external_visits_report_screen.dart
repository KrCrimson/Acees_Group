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

    if (_selectedChartType == 'pie') {
      return _buildPieChart();
    } else if (_selectedChartType == 'bar') {
      return _buildBarChart();
    }

    return const Center(child: Text('Invalid chart type.'));
  }

  Widget _buildPieChart() {
    Map<String, int> visitCounts = {};
    for (var visit in _visitData) {
      final name = visit['nombre'] ?? 'Desconocido';
      visitCounts[name] = (visitCounts[name] ?? 0) + 1;
    }

    List<PieChartSectionData> sections = [];
    int totalVisits = visitCounts.values.fold(0, (sum, count) => sum + count);
    visitCounts.forEach((name, count) {
      final percentage = (count / totalVisits) * 100;
      sections.add(
        PieChartSectionData(
          value: percentage,
          title: '${name.split(' ')[0]} (${percentage.toStringAsFixed(1)}%)',
          color: _getChartColor(visitCounts.keys.toList().indexOf(name)),
          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black), // Text color set to black
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

  Widget _buildBarChart() {
    Map<String, int> visitCounts = {};
    for (var visit in _visitData) {
      final name = visit['nombre'] ?? 'Desconocido';
      visitCounts[name] = (visitCounts[name] ?? 0) + 1;
    }

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

    return BarChart(
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
                    visitCounts.keys.toList()[index],
                    style: const TextStyle(fontSize: 10, color: Colors.black), // Text color set to black
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
                style: const TextStyle(fontSize: 10, color: Colors.black), // Text color set to black
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
    );
  }

  Widget _buildExternalVisitorsList() {
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
            return ListTile(
              leading: const Icon(Icons.person, color: Colors.blue),
              title: Text(visitor['nombre'] ?? 'Desconocido'),
              subtitle: Text('DNI: ${visitor['dni'] ?? 'Sin DNI'}'),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: () {
            setState(() {
              _showList = true;
            });
          },
          child: const Text('Ver Listado'),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _showList = false;
            });
          },
          child: const Text('Ver Gráficos'),
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
