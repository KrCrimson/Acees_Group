import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _user;
  User? get user => _user;

  Stream<User?> get userStream => _auth.authStateChanges();

  AuthService() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> registerUser({
    required String dni,
    required String nombre,
    required String apellido,
    required String rango,
    required String estado,
    required String email,
    required String telefono,
    required String usuario,
    required String password,
  }) async {
    try {
      // Crear usuario en Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Guardar datos adicionales en Firestore
      await _firestore.collection('usuarios').doc(userCredential.user?.uid).set({
        'dni': dni,
        'nombre': nombre,
        'apellido': apellido,
        'rango': rango,
        'estado': estado,
        'email': email,
        'telefono': telefono,
        'usuario': usuario,
        'uid': userCredential.user?.uid,
        'fecha_registro': FieldValue.serverTimestamp(),
      });
    } on FirebaseAuthException catch (e) {
      throw FirebaseAuthException(code: e.code, message: e.message);
    }
  }

  Future<Map<String, dynamic>?> getUserData(String uid) async {
    final doc = await _firestore.collection('usuarios').doc(uid).get();
    return doc.data();
  }
}