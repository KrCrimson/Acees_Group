import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Asegura que la clase esté exportada correctamente
class PendingExitScreen extends StatefulWidget {
  const PendingExitScreen({Key? key}) : super(key: key);

  @override
  State<PendingExitScreen> createState() => _PendingAllExitScreenState();
}

class _PendingAllExitScreenState extends State<PendingExitScreen> {
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
    final pendientes = ultimoRegistroPorDni.values.where((e) => e['tipo'] == 'entrada').toList();
    yield pendientes;
  }

  Color _getColorBasedOnTime(DateTime fechaHora) {
    final now = DateTime.now();
    final difference = now.difference(fechaHora);
    return difference.inHours > 12 ? Colors.red : Colors.black;
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
              final nombre = data['nombre'] ?? 'Sin nombre';
              final dni = data['dni'] ?? 'Sin DNI';
              final fechaHora = (data['fecha_hora'] as Timestamp?)?.toDate();
              final color = fechaHora != null ? _getColorBasedOnTime(fechaHora) : Colors.black;

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0),
                ),
                elevation: 5,
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color,
                    child: const Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(
                    '$nombre ($dni)',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: fechaHora != null
                      ? Text(
                          'Última entrada: ${DateFormat('dd/MM/yyyy HH:mm').format(fechaHora)}',
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                        )
                      : const Text('Sin fecha registrada', style: TextStyle(fontSize: 14, color: Colors.grey)),
                  trailing: IconButton(
                    icon: const Icon(Icons.exit_to_app, color: Colors.blue),
                    onPressed: () {
                      // Acción para registrar salida
                    },
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
