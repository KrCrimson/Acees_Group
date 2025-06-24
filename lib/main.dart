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
import 'package:cloud_firestore/cloud_firestore.dart';
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
        print('AuthWrapper: Connection state: ${snapshot.connectionState}');
        print('AuthWrapper: Has data: ${snapshot.hasData}');
        print('AuthWrapper: User: ${snapshot.data?.uid ?? 'null'}');
        
        if (snapshot.connectionState == ConnectionState.active) {
          final user = snapshot.data;
          if (user == null) {
            print('AuthWrapper: No user, showing LoginScreen');
            return const LoginScreen();
          }

          print('AuthWrapper: User found, fetching user data');
          return FutureBuilder<Map<String, dynamic>?>(
            future: authService.getUserData(user.uid),
            builder: (context, AsyncSnapshot<Map<String, dynamic>?> userDataSnapshot) {
              print('UserData: Connection state: ${userDataSnapshot.connectionState}');
              print('UserData: Has data: ${userDataSnapshot.hasData}');
              
              if (userDataSnapshot.connectionState == ConnectionState.done) {
                final userData = userDataSnapshot.data;
                if (userData != null) {
                  final rango = userData['rango'];
                  print('UserData: Rango found: $rango');
                  if (rango == 'admin') {
                    return const AdminView();
                  } else {
                    return const UserScannerScreen();
                  }
                } else {
                  print('UserData: No data found');
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
