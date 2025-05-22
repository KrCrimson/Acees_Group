import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/user/user_scanner_screen.dart'; // Importa la nueva pantalla
import 'screens/user/user_history_screen.dart'; // Importa la pantalla de historial
import 'screens/admin/admin_view.dart'; // Importa la pantalla de perfil de usuario
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
        '/register': (context) => const RegisterScreen(),
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
    
    return StreamBuilder<User?>(
      stream: authService.userStream,
      builder: (_, AsyncSnapshot<User?> snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final user = snapshot.data;
          if (user == null) {
            return const LoginScreen();
          }
          
          // Verificar el rango del usuario
          return FutureBuilder<Map<String, dynamic>?>(
            future: authService.getUserData(user.uid),
            builder: (context, AsyncSnapshot<Map<String, dynamic>?> userDataSnapshot) {
              if (userDataSnapshot.connectionState == ConnectionState.done) {
                final userData = userDataSnapshot.data;
                if (userData != null) {
                  if (userData['rango'] == 'admin') {
                    return const AdminView();
                  } else {
                    return const UserScannerScreen(); // Redirige directamente al escáner
                  }
                }
              }
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            },
          );
        }
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}