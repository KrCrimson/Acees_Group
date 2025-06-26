import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Asegura que la clase esté exportada correctamente
class PendingAllExitScreen extends StatefulWidget {
  const PendingAllExitScreen({Key? key}) : super(key: key);

  @override
  State<PendingAllExitScreen> createState() => _PendingAllExitScreenState();
}

class _PendingAllExitScreenState extends State<PendingAllExitScreen> {
  // Obtiene alumnos cuyo último registro es una entrada sin salida
  Stream<List<Map<String, dynamic>>> _getAlumnosSinSalida() async* {
    final snapshot = await FirebaseFirestore.instance
        .collection('asistencias')
        .orderBy('fecha_hora', descending: true)
        .get();
    final Map<String, Map<String, dynamic>> ultimoRegistroPorDni = {};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final dni = data['dni'] ?? '';
      if (dni.isEmpty) continue;
      if (!ultimoRegistroPorDni.containsKey(dni)) {
        ultimoRegistroPorDni[dni] = data;
      }
    }
    // Solo los que su último registro es 'entrada'
    final pendientes = ultimoRegistroPorDni.values.where((e) => e['tipo'] == 'entrada').toList();
    yield pendientes;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alumnos sin salida registrada'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _getAlumnosSinSalida(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay alumnos pendientes de salida.'));
          }
          final alumnos = snapshot.data!;
          return ListView.builder(
            itemCount: alumnos.length,
            itemBuilder: (context, index) {
              final data = alumnos[index];
              final fecha = (data['fecha_hora'] as Timestamp?)?.toDate();
              return Card(
                color: Colors.red[100],
                child: ListTile(
                  leading: const Icon(Icons.warning, color: Colors.red),
                  title: Text(data['nombre'] ?? 'Desconocido', style: const TextStyle(color: Colors.red)),
                  subtitle: Text(
                    'DNI: ${data['dni'] ?? '-'}\n'
                    'Fecha: ${fecha != null ? DateFormat('dd/MM/yyyy HH:mm').format(fecha) : '-'}\n'
                    'Facultad: ${data['facultad'] ?? '-'} | Puerta: ${data['puerta'] ?? '-'}',
                  ),
                  trailing: const Text('¡Sin salida!', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
