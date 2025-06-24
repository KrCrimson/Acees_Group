import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _user;
  User? get user => _user;
  bool _isSigningOut = false;
  bool get isSigningOut => _isSigningOut;

  Stream<User?> get userStream => _auth.authStateChanges();

  AuthService() {
    _auth.authStateChanges().listen((User? user) {
      print('AuthService: User state changed - ${user?.uid ?? 'null'}');
      _user = user;
      _isSigningOut = false;
      notifyListeners();
    });
  }

  Future<void> signIn(String email, String password) async {
    try {
      print('AuthService: Starting sign in for: $email');
      
      // PRIMERO: Intentar autenticación en Firebase Auth
      final userCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      print('AuthService: Firebase Auth successful for: ${userCredential.user?.uid}');
      
      // SEGUNDO: Verificar el estado en Firestore DESPUÉS de la autenticación exitosa
      final userData = await getUserData(userCredential.user!.uid);
      
      if (userData == null) {
        // Si no existe en Firestore, cerrar sesión y mostrar error
        await _auth.signOut();
        throw Exception('Usuario no encontrado en el sistema.');
      }
      
      if (userData['estado'] == 'inactivo') {
        // Si está inactivo, cerrar sesión inmediatamente
        await _auth.signOut();
        throw Exception('Su cuenta está inactiva. Comuníquese con su superior.');
      }
      
      print('AuthService: User is active, login successful');
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      print('AuthService: Sign in error: ${e.code} - ${e.message}');
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
      print('AuthService: General sign in error: $e');
      throw Exception(e.toString());
    }
  }

  Future<void> signOut() async {
    try {
      print('AuthService: Starting sign out process');
      _isSigningOut = true;
      notifyListeners();
      
      await Future.delayed(const Duration(milliseconds: 100));
      await _auth.signOut();
      
      _user = null;
      _isSigningOut = false;
      print('AuthService: Sign out completed');
      notifyListeners();
    } catch (e) {
      print('AuthService: Error during sign out: $e');
      _isSigningOut = false;
      notifyListeners();
      rethrow;
    }
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
        'email': email.trim().toLowerCase(), // Guardar email en lowercase
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
    try {
      print('AuthService: Looking for user data with UID: $uid');
      
      // Primero intentar buscar por UID como documento ID
      final doc = await _firestore.collection('usuarios').doc(uid).get();
      if (doc.exists) {
        print('AuthService: Found user by document ID');
        return doc.data();
      }
      
      // Si no encuentra por UID, buscar por campo 'uid'
      var querySnapshot = await _firestore
          .collection('usuarios')
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        print('AuthService: Found user by uid field');
        return querySnapshot.docs.first.data();
      }
      
      // Si no encuentra por 'uid', buscar por 'auth_uid' (para compatibilidad)
      querySnapshot = await _firestore
          .collection('usuarios')
          .where('auth_uid', isEqualTo: uid)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        print('AuthService: Found user by auth_uid field');
        return querySnapshot.docs.first.data();
      }
      
      print('AuthService: User not found in any search method');
      return null;
    } catch (e) {
      print('AuthService: Error getting user data: $e');
      return null;
    }
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