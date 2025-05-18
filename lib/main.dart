import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';
import 'login_screen.dart';
import 'admin_screen.dart';
import 'user_screen.dart';
import 'register_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    print('Inicializando Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 10));
    print('Firebase inicializado correctamente');
  } catch (e) {
    print('Error inicializando Firebase: $e');
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Error al conectar con Firebase. Revisa tu conexión.'),
          ),
        ),
      ),
    );
    return;
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
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/admin': (context) => const AdminScreen(),
        '/user': (context) => const UserScreen(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    
    return StreamBuilder<User?>(
      stream: authService.userStream,
      builder: (context, AsyncSnapshot<User?> snapshot) {
        // Debug: Mostrar estado de la autenticación
        debugPrint('Estado de autenticación: ${snapshot.connectionState}');
        if (snapshot.hasError) {
          debugPrint('Error en auth stream: ${snapshot.error}');
          return _buildErrorScreen('Error de autenticación');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScreen('Verificando sesión...');
        }

        if (snapshot.connectionState == ConnectionState.active) {
          final user = snapshot.data;
          if (user == null) {
            debugPrint('No hay usuario autenticado, redirigiendo a login');
            return const LoginScreen();
          }
          
          return FutureBuilder<Map<String, dynamic>?>(
            future: authService.getUserData(user.uid),
            builder: (context, AsyncSnapshot<Map<String, dynamic>?> userDataSnapshot) {
              // Debug: Mostrar estado de los datos de usuario
              debugPrint('Estado de datos de usuario: ${userDataSnapshot.connectionState}');
              if (userDataSnapshot.hasError) {
                debugPrint('Error obteniendo user data: ${userDataSnapshot.error}');
                return _buildErrorScreen('Error cargando datos de usuario');
              }

              if (userDataSnapshot.connectionState == ConnectionState.done) {
                final userData = userDataSnapshot.data;
                if (userData == null) {
                  debugPrint('Datos de usuario vacíos');
                  return _buildErrorScreen('Datos de usuario no encontrados');
                }

                debugPrint('Usuario autenticado: ${userData['email']} - Rango: ${userData['rango']}');
                return userData['rango'] == 'admin' 
                    ? const AdminScreen() 
                    : const UserScreen();
              }

              return _buildLoadingScreen('Cargando datos de usuario...');
            },
          );
        }

        return _buildLoadingScreen('Inicializando...');
      },
    );
  }

  Widget _buildLoadingScreen(String message) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(message),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(String error) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 50),
            const SizedBox(height: 20),
            Text(error, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Intentar reiniciar el flujo
                FirebaseAuth.instance.signOut();
              },
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}