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

  Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      // Throw specific exceptions based on the error code
      switch (e.code) {
        case 'user-not-found':
          throw Exception('Usuario no encontrado.');
        case 'wrong-password':
          throw Exception('Contraseña incorrecta.');
        case 'invalid-email':
          throw Exception('Correo electrónico inválido.');
        case 'user-disabled':
          throw Exception('Este usuario ha sido deshabilitado.');
        default:
          throw Exception('Error al iniciar sesión: ${e.message}');
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    notifyListeners();
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

  Future<void> updateUserEmail({
    required String newEmail,
    required String currentPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      // 1. Reautenticación requerida
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // 2. Actualizar email
      await user.verifyBeforeUpdateEmail(newEmail);
    } on FirebaseAuthException catch (e) {
      throw FirebaseAuthException(code: e.code, message: e.message);
    }
  }

  // Método para actualizar la contraseña
  Future<void> updateUserPassword({
    required String newPassword,
    required String currentPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      // Reautenticación
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // Actualizar contraseña
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw FirebaseAuthException(code: e.code, message: e.message);
    }
  }

  // Obtener datos del usuario actual
  User? get currentUser => _auth.currentUser;
}