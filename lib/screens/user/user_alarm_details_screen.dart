import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class UserAlarmDetailsScreen extends StatefulWidget {
  const UserAlarmDetailsScreen({super.key});

  @override
  State<UserAlarmDetailsScreen> createState() => _UserAlarmDetailsScreenState();
}

class _UserAlarmDetailsScreenState extends State<UserAlarmDetailsScreen> {
  String selectedFilter = 'day';

  Stream<QuerySnapshot> _getVisitorRequestsStream(String filter) {
    final now = DateTime.now();
    DateTime startDate;

    switch (filter) {
      case 'day':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'week':
        startDate = now.subtract(Duration(days: now.weekday - 1));
        break;
      case 'month':
        startDate = DateTime(now.year, now.month);
        break;
      case 'year':
        startDate = DateTime(now.year);
        break;
      default:
        startDate = DateTime(2000);
    }

    return FirebaseFirestore.instance
        .collection('visitas')
        .where('fecha_hora', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .snapshots();
  }

  Color _getRequestColor(int requestCount) {
    if (requestCount <= 2) {
      return Colors.green;
    } else if (requestCount <= 4) {
      return Colors.yellow;
    } else {
      return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitudes de Externos'),
      ),
      body: Column(
        children: [
          DropdownButton<String>(
            value: selectedFilter,
            items: const [
              DropdownMenuItem(value: 'day', child: Text('Día')),
              DropdownMenuItem(value: 'week', child: Text('Semana')),
              DropdownMenuItem(value: 'month', child: Text('Mes')),
              DropdownMenuItem(value: 'year', child: Text('Año')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  selectedFilter = value;
                });
              }
            },
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getVisitorRequestsStream(selectedFilter),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No hay solicitudes de visitantes.'));
                }

                final requests = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final data = requests[index].data() as Map<String, dynamic>;
                    final nombre = data['nombre'] ?? 'Sin nombre';
                    final dni = data['dni'] ?? 'Sin DNI';
                    final asunto = data['asunto'] ?? 'Sin asunto';
                    final facultad = data['facultad'] ?? 'Sin facultad';
                    final guardia = data['guardia'] ?? 'Sin guardia';
                    final puerta = data['puerta'] ?? 'Sin puerta';
                    final fecha = (data['fecha_hora'] as Timestamp?)?.toDate();
                    final formattedDate = fecha != null ? DateFormat('dd/MM/yyyy HH:mm').format(fecha) : 'Sin fecha';

                    return Card(
                      child: ListTile(
                        title: Text('$nombre ($dni)', style: TextStyle(color: _getRequestColor(requests.length))),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Asunto: $asunto'),
                            Text('Facultad: $facultad'),
                            Text('Guardia: $guardia'),
                            Text('Puerta: $puerta'),
                            Text('Fecha: $formattedDate'),
                          ],
                        ),
                        trailing: Icon(Icons.info, color: _getRequestColor(requests.length)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
