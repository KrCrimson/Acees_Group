import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'login_screen.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/user/user_scanner_screen.dart';
import 'screens/user/user_history_screen.dart';
import 'screens/admin/admin_view.dart';

// Nombre para la instancia secundaria de Firebase
const String secondaryAppName = 'secondaryAuthApp';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inicializar la app de Firebase por defecto
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Inicializar una segunda app de Firebase con un nombre diferente
  // Esto es crucial para aislar el flujo de creación de usuarios.
  try {
    await Firebase.initializeApp(
      name: secondaryAppName,
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("Firebase secondary app '$secondaryAppName' initialized.");
  } catch (e) {
    debugPrint("Error initializing Firebase secondary app '$secondaryAppName': $e");
    // Si ya está inicializada (ej. por hot reload), Firebase.app() la retornará.
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistema de Autenticación',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/admin': (context) => const AdminView(),
        '/user': (context) => const UserScannerScreen(), // Actualizado a UserScannerScreen
        '/user/history': (context) => const UserHistoryScreen(), // Agregado para historial
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    
    // Escucha los cambios de estado de autenticación de Firebase
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(), // Usar directamente authStateChanges()
      builder: (_, AsyncSnapshot<User?> authSnapshot) { // Renombrado para claridad
        
        debugPrint("AuthWrapper - authStateChanges emitió: ${authSnapshot.data?.uid} (Email: ${authSnapshot.data?.email})");
        debugPrint("AuthWrapper - FirebaseAuth.instance.currentUser es: ${FirebaseAuth.instance.currentUser?.uid} (Email: ${FirebaseAuth.instance.currentUser?.email})");

        if (authSnapshot.connectionState == ConnectionState.waiting) {
          // Mientras se determina el estado inicial de autenticación
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.orange)));
        }

        // Usar FirebaseAuth.instance.currentUser como la fuente principal de verdad
        final User? currentUser = FirebaseAuth.instance.currentUser;

        if (currentUser == null) {
          // No hay ningún usuario logueado según Firebase.
          debugPrint("AuthWrapper - currentUser es NULL. Redirigiendo a LoginScreen.");
          return const LoginScreen();
        }
        
        // Si currentUser NO es null, significa que un usuario está logueado.
        // Ahora, verificamos su rol para decidir a dónde ir.
        // La ValueKey asegura que el FutureBuilder se reconstruya si el UID cambia (lo cual no debería si el admin sigue logueado).
        return FutureBuilder<Map<String, dynamic>?>(
          key: ValueKey(currentUser.uid), 
          future: authService.getUserData(currentUser.uid), // Obtener datos del currentUser
          builder: (context, AsyncSnapshot<Map<String, dynamic>?> userDataSnapshot) {
            
            if (userDataSnapshot.connectionState == ConnectionState.waiting) {
              // Mientras se cargan los datos del usuario desde Firestore
              return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.blue)));
            }

            if (userDataSnapshot.hasError) {
              debugPrint("AuthWrapper - Error al cargar datos para ${currentUser.uid}: ${userDataSnapshot.error}. Redirigiendo a Login.");
              // Error al cargar datos, es más seguro cerrar sesión y redirigir.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                authService.signOut(); 
              });
              return const LoginScreen(); // Muestra Login mientras se procesa el signOut
            }

            final userData = userDataSnapshot.data;
            if (userData == null) {
              // No se encontraron datos en Firestore para este currentUser.
              debugPrint("AuthWrapper - No se encontraron datos en Firestore para ${currentUser.uid}. Redirigiendo a Login.");
              WidgetsBinding.instance.addPostFrameCallback((_) {
                authService.signOut();
              });
              return const LoginScreen();
            }
            
            final rango = userData['rango'];
            debugPrint("AuthWrapper - Usuario ${currentUser.uid} tiene rango: '$rango'.");

            if (rango == 'admin') {
              // El usuario es admin, mostrar AdminView.
              debugPrint("AuthWrapper - Rango es 'admin'. Mostrando AdminView.");
              return const AdminView();
            } else if (rango == 'guardia') {
              // El usuario es guardia, mostrar UserScannerScreen.
              debugPrint("AuthWrapper - Rango es 'guardia'. Mostrando UserScannerScreen.");
              return const UserScannerScreen();
            } else {
              // Rango desconocido o no es ni admin ni guardia.
              debugPrint("AuthWrapper - Rango '$rango' no reconocido para ${currentUser.uid}. Redirigiendo a Login.");
              WidgetsBinding.instance.addPostFrameCallback((_) {
                authService.signOut();
              });
              return const LoginScreen();
            }
          },
        );
      },
    );
  }
}