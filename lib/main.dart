import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/nfc_viewmodel.dart';
import 'viewmodels/admin_viewmodel.dart';
import 'viewmodels/reports_viewmodel.dart';
import 'viewmodels/guard_reports_viewmodel.dart';
import 'services/connectivity_service.dart';
import 'services/offline_sync_service.dart';
import 'services/hybrid_api_service.dart';
import 'views/login_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar Hive para almacenamiento local
  await Hive.initFlutter();
  
  // Inicializar servicios offline
  await _initializeOfflineServices();
  
  runApp(const MyApp());
}

Future<void> _initializeOfflineServices() async {
  try {
    // Inicializar servicios en orden
    await ConnectivityService().initialize();
    await OfflineSyncService().initialize();
    await HybridApiService().initialize();
  } catch (e) {
    print('Error inicializando servicios offline: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Servicios offline
        ChangeNotifierProvider(create: (_) => ConnectivityService()),
        ChangeNotifierProvider(create: (_) => OfflineSyncService()),
        ChangeNotifierProvider(create: (_) => HybridApiService()),
        
        // ViewModels
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => NfcViewModel()),
        ChangeNotifierProvider(create: (_) => AdminViewModel()),
        ChangeNotifierProvider(create: (_) => ReportsViewModel()),
        ChangeNotifierProvider(create: (_) => GuardReportsViewModel()),
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
