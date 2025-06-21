import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PendingExitScreen extends StatelessWidget {
  const PendingExitScreen({Key? key}) : super(key: key);

  Future<List<Map<String, dynamic>>> _getPendingVisitors() async {
    // Suponiendo que en la colección 'visitas' hay un campo 'salida_registrada' (bool)
    final snapshot = await FirebaseFirestore.instance
        .collection('visitas')
        .where('salida_registrada', isEqualTo: false)
        .get();
    return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Personas sin salida')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _getPendingVisitors(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay personas pendientes de salida.'));
          }
          final visitors = snapshot.data!;
          return ListView.builder(
            itemCount: visitors.length,
            itemBuilder: (context, index) {
              final v = visitors[index];
              return ListTile(
                leading: const Icon(Icons.person, color: Colors.red),
                title: Text(v['nombre'] ?? 'Desconocido'),
                subtitle: Text('DNI: ${v['dni'] ?? '-'}'),
              );
            },
          );
        },
      ),
    );
  }
}
