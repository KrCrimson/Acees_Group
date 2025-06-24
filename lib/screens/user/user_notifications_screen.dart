import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class UserNotificationsScreen extends StatelessWidget {
  const UserNotificationsScreen({Key? key}) : super(key: key);

  Stream<QuerySnapshot> _getNotificationsStream() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('notificaciones')
        .where('guardia_uid', isEqualTo: currentUser.uid)
        .orderBy('fecha_hora', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getNotificationsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay notificaciones.'));
          }

          final notifications = snapshot.data!.docs;

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index].data() as Map<String, dynamic>;
              final mensaje = notification['mensaje'] ?? 'Sin mensaje';
              final info = notification['info'] ?? {};

              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  leading: const Icon(Icons.notifications, color: Colors.blue),
                  title: Text(mensaje),
                  subtitle: Text(
                    'DNI: ${info['dni'] ?? 'Sin DNI'}\n'
                    'Nombre: ${info['nombre'] ?? 'Sin Nombre'}\n'
                    'Asunto: ${info['asunto'] ?? 'Sin Asunto'}\n'
                    'Facultad: ${info['facultad'] ?? 'Sin Facultad'}\n'
                    'Fecha: ${info['fecha_hora'] != null ? DateFormat('dd/MM/yyyy HH:mm').format((info['fecha_hora'] as Timestamp).toDate()) : 'Sin Fecha'}',
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
