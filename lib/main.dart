import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'login_screen.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/user/user_scanner_screen.dart';
import 'screens/admin/admin_view.dart';
import 'screens/admin/admin_report_chart_screen.dart';
import 'screens/admin/admin_report_screen.dart';
import 'screens/admin/alarm_details_screen.dart'; // Import the alarm details screen
import 'screens/user/user_alarm_details_screen.dart'; // Import the user alarm details screen
import 'registro_alumno.dart';

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
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/admin': (context) => const AdminView(),
        '/user': (context) => const UserScannerScreen(),
        '/admin/report_chart': (context) => const AdminReportChartScreen(),
        '/admin/report_general': (context) => const AdminReportScreen(),
        '/admin/alarm_details': (context) => const AlarmDetailsScreen(),
        '/user/alarm_details': (context) => const UserAlarmDetailsScreen(),
        '/student_register': (context) => const StudentRegisterScreen(),
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

          return FutureBuilder<Map<String, dynamic>?>(
            future: authService.getUserData(user.uid),
            builder: (context, AsyncSnapshot<Map<String, dynamic>?> userDataSnapshot) {
              if (userDataSnapshot.connectionState == ConnectionState.done) {
                final userData = userDataSnapshot.data;
                if (userData != null) {
                  final rango = userData['rango'];
                  if (rango == 'admin') {
                    return const AdminView();
                  } else {
                    return const UserScannerScreen();
                  }
                } else {
                  return const Scaffold(body: Center(child: Text('Error: No user data found')));
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
