import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class UserAlarmDetailsScreen extends StatelessWidget {
  const UserAlarmDetailsScreen({super.key});

  Stream<QuerySnapshot> _getUnrecordedExitsStream() {
    return FirebaseFirestore.instance
        .collection('asistencias')
        .where('tipo', isEqualTo: 'entrada')
        .where('estado', isEqualTo: 'activo')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personas sin salida'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getUnrecordedExitsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay personas sin salida.'));
          }

          final individuals = snapshot.data!.docs;

          return ListView.builder(
            itemCount: individuals.length,
            itemBuilder: (context, index) {
              final data = individuals[index].data() as Map<String, dynamic>;
              final nombre = data['nombre'] ?? 'Desconocido';
              final apellido = data['apellido'] ?? 'Desconocido';
              final dni = data['dni'] ?? 'Sin DNI';
              final fechaHora = data['fecha_hora'] != null
                  ? (data['fecha_hora'] as Timestamp).toDate()
                  : null;

              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  leading: const Icon(Icons.warning, color: Colors.red),
                  title: Text('$nombre $apellido'),
                  subtitle: Text(
                    'DNI: $dni\n'
                    'Fecha de entrada: ${fechaHora != null ? DateFormat('dd/MM/yyyy HH:mm').format(fechaHora) : 'Sin fecha'}',
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
