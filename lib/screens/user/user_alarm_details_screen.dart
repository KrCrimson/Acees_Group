import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

enum FiltroVisitas { dia, semana, mes, anio }

class UserAlarmDetailsScreen extends StatefulWidget {
  const UserAlarmDetailsScreen({super.key});

  @override
  State<UserAlarmDetailsScreen> createState() => _UserAlarmDetailsScreenState();
}

class _UserAlarmDetailsScreenState extends State<UserAlarmDetailsScreen> {
  FiltroVisitas _filtro = FiltroVisitas.dia;

  DateTime get _now => DateTime.now();

  DateTime get _startDate {
    switch (_filtro) {
      case FiltroVisitas.dia:
        return DateTime(_now.year, _now.month, _now.day);
      case FiltroVisitas.semana:
        final weekday = _now.weekday;
        return _now.subtract(Duration(days: weekday - 1));
      case FiltroVisitas.mes:
        return DateTime(_now.year, _now.month, 1);
      case FiltroVisitas.anio:
        return DateTime(_now.year, 1, 1);
    }
  }

  DateTime get _endDate {
    switch (_filtro) {
      case FiltroVisitas.dia:
        return DateTime(_now.year, _now.month, _now.day, 23, 59, 59, 999);
      case FiltroVisitas.semana:
        final weekday = _now.weekday;
        return _now.add(Duration(days: 7 - weekday, hours: 23, minutes: 59, seconds: 59, milliseconds: 999));
      case FiltroVisitas.mes:
        final nextMonth = DateTime(_now.year, _now.month + 1, 1);
        return nextMonth.subtract(const Duration(milliseconds: 1));
      case FiltroVisitas.anio:
        return DateTime(_now.year, 12, 31, 23, 59, 59, 999);
    }
  }

  Stream<QuerySnapshot> _getVisitasStream() {
    return FirebaseFirestore.instance
        .collection('visitas')
        .where('fecha_hora', isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate))
        .where('fecha_hora', isLessThanOrEqualTo: Timestamp.fromDate(_endDate))
        .snapshots();
  }

  Color _getColorByCount(int count) {
    if (count <= 2) return Colors.green;
    if (count <= 4) return Colors.amber;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visitas de Externos'),
        actions: [
          PopupMenuButton<FiltroVisitas>(
            icon: const Icon(Icons.filter_alt),
            tooltip: 'Filtrar',
            onSelected: (f) => setState(() => _filtro = f),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: FiltroVisitas.dia,
                child: Text('Hoy'),
              ),
              const PopupMenuItem(
                value: FiltroVisitas.semana,
                child: Text('Esta semana'),
              ),
              const PopupMenuItem(
                value: FiltroVisitas.mes,
                child: Text('Este mes'),
              ),
              const PopupMenuItem(
                value: FiltroVisitas.anio,
                child: Text('Este año'),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getVisitasStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay visitas registradas.'));
          }

          // Agrupa por DNI y cuenta visitas
          final visitas = snapshot.data!.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
          final Map<String, List<Map<String, dynamic>>> visitasPorDni = {};
          for (var visita in visitas) {
            final dni = visita['dni'] ?? '';
            if (!visitasPorDni.containsKey(dni)) {
              visitasPorDni[dni] = [];
            }
            visitasPorDni[dni]!.add(visita);
          }

          final List<Map<String, dynamic>> resumenVisitas = visitasPorDni.entries.map((entry) {
            final dni = entry.key;
            final lista = entry.value;
            final ultimaVisita = lista.last;
            return {
              'dni': dni,
              'nombre': ultimaVisita['nombre'] ?? '',
              'asunto': ultimaVisita['asunto'] ?? '',
              'facultad': ultimaVisita['facultad'] ?? '',
              'fecha_hora': ultimaVisita['fecha_hora'],
              'guardia_nombre': ultimaVisita['guardia_nombre'] ?? '',
              'puerta': ultimaVisita['puerta'] ?? '',
              'cantidad': lista.length,
            };
          }).toList();

          return ListView.builder(
            itemCount: resumenVisitas.length,
            itemBuilder: (context, index) {
              final visita = resumenVisitas[index];
              final color = _getColorByCount(visita['cantidad']);
              final fecha = visita['fecha_hora'] is Timestamp
                  ? (visita['fecha_hora'] as Timestamp).toDate()
                  : DateTime.tryParse(visita['fecha_hora'].toString());
              return Card(
                color: color.withOpacity(0.2),
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color,
                    child: Text(
                      visita['cantidad'].toString(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text('${visita['nombre']}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('DNI: ${visita['dni']}'),
                      Text('Asunto: ${visita['asunto']}'),
                      Text('Facultad: ${visita['facultad']}'),
                      Text('Guardia: ${visita['guardia_nombre']}'),
                      Text('Puerta: ${visita['puerta']}'),
                      if (fecha != null)
                        Text('Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(fecha)}'),
                    ],
                  ),
                  trailing: Icon(
                    Icons.person,
                    color: color,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
