import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AlarmService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  AlarmService() {
    _initializeFirebaseMessaging();
    _startPeriodicCheck();
  }

  void _initializeFirebaseMessaging() {
    _firebaseMessaging.requestPermission();

    // Handle foreground notifications
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        print('Foreground notification: ${message.notification!.title}');
      }
    });

    // Handle background notifications
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (message.notification != null) {
        print('Background notification: ${message.notification!.title}');
      }
    });
  }

  void _startPeriodicCheck() {
    Timer.periodic(const Duration(minutes: 5), (timer) async {
      await _checkForUnrecordedExits();
    });
  }

  Future<void> _checkForUnrecordedExits() async {
    try {
      final snapshot = await _firestore.collection('asistencias')
          .where('tipo', isEqualTo: 'entrada')
          .where('estado', isEqualTo: 'activo')
          .get();

      if (snapshot.docs.isNotEmpty) {
        final individuals = snapshot.docs.map((doc) => doc.data()).toList();
        final names = individuals.map((data) => '${data['nombre']} ${data['apellido']}').join(', ');

        await _sendFirebaseNotification(
          'Alarma: Personas sin salida',
          'Las siguientes personas aún están dentro: $names',
        );
      }
    } catch (e) {
      print('Error checking for unrecorded exits: $e');
    }
  }

  Future<void> _sendFirebaseNotification(String title, String body) async {
    // Simulate sending a Firebase notification (replace with actual backend logic)
    print('Sending Firebase notification: $title - $body');
  }
}
