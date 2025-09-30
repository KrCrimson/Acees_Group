import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/nfc_viewmodel.dart';
import 'viewmodels/admin_viewmodel.dart';
import 'viewmodels/reports_viewmodel.dart';
import 'services/offline_service.dart';
import 'services/sync_service.dart';
import 'services/session_guard_service.dart';
import 'views/login_view.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeServices();
    });
  }

  void _initializeServices() async {
    final offlineService = Provider.of<OfflineService>(context, listen: false);
    await offlineService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => NfcViewModel()),
        ChangeNotifierProvider(create: (_) => AdminViewModel()),
        ChangeNotifierProvider(create: (_) => ReportsViewModel()),
        ChangeNotifierProvider(create: (_) => OfflineService()),
        ChangeNotifierProvider(create: (_) => SyncService()),
        ChangeNotifierProvider(create: (_) => SessionGuardService()),
      ],
      child: MaterialApp(
        title: 'Control de Acceso NFC - MVVM',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            elevation: 2,
          ),
        ),
        home: LoginView(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
