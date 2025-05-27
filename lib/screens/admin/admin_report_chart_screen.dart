import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class AdminReportChartScreen extends StatefulWidget {
  const AdminReportChartScreen({super.key});

  @override
  State<AdminReportChartScreen> createState() => _AdminReportChartScreenState();
}

class _AdminReportChartScreenState extends State<AdminReportChartScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, int> _asistenciasPorDia = {};

  @override
  void initState() {
    super.initState();
    _loadChartData();
  }

  Future<void> _loadChartData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final now = DateTime.now();
      final last7Days = now.subtract(const Duration(days: 6));
      final snapshot = await _firestore
          .collection('asistencias')
          .where('fecha_hora', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(last7Days.year, last7Days.month, last7Days.day)))
          .get();

      final Map<String, int> counts = {};
      for (var i = 0; i < 7; i++) {
        final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
        final key = DateFormat('dd/MM').format(date);
        counts[key] = 0;
      }

      for (var doc in snapshot.docs) {
        final fecha = (doc['fecha_hora'] as Timestamp).toDate();
        final key = DateFormat('dd/MM').format(fecha);
        if (counts.containsKey(key)) {
          counts[key] = counts[key]! + 1;
        }
      }

      setState(() {
        _asistenciasPorDia = Map.fromEntries(counts.entries.toList().reversed);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gráfico de Asistencias')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: true),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= _asistenciasPorDia.keys.length) return const SizedBox();
                              return Text(_asistenciasPorDia.keys.elementAt(idx), style: const TextStyle(fontSize: 10));
                            },
                          ),
                        ),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(_asistenciasPorDia.length, (i) {
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: _asistenciasPorDia.values.elementAt(i).toDouble(),
                              color: Colors.blue,
                              width: 18,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
    );
  }
}
