import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/guard_reports_viewmodel.dart';
import 'guard_reports_view.dart';

/// Ejemplo de uso de la funcionalidad de reportes de guardias
/// Este archivo muestra cómo integrar los reportes de guardias en una aplicación
class GuardReportsExample extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reportes de Guardias - Ejemplo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: ChangeNotifierProvider(
        create: (context) => GuardReportsViewModel(),
        child: GuardReportsExampleHome(),
      ),
    );
  }
}

class GuardReportsExampleHome extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reportes de Guardias'),
        backgroundColor: Colors.blue[700],
        elevation: 0,
      ),
      body: GuardReportsView(),
    );
  }
}

/// Widget de demostración que muestra las capacidades de los reportes de guardias
class GuardReportsDemo extends StatefulWidget {
  @override
  _GuardReportsDemoState createState() => _GuardReportsDemoState();
}

class _GuardReportsDemoState extends State<GuardReportsDemo> {
  late GuardReportsViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = GuardReportsViewModel();
    _loadDemoData();
  }

  Future<void> _loadDemoData() async {
    // Simular carga de datos de demostración
    await _viewModel.loadAllGuardReports();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Demo - Reportes de Guardias'),
        backgroundColor: Colors.green[700],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Funcionalidades de Reportes de Guardias',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 20),
            
            // Tarjetas de funcionalidades
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildFeatureCard(
                    'Resumen General',
                    'Estadísticas generales de actividad de guardias',
                    Icons.dashboard,
                    Colors.blue,
                    () => _showGeneralSummary(),
                  ),
                  _buildFeatureCard(
                    'Ranking Guardias',
                    'Lista de guardias ordenada por actividad',
                    Icons.leaderboard,
                    Colors.orange,
                    () => _showRanking(),
                  ),
                  _buildFeatureCard(
                    'Actividad Diaria',
                    'Análisis de actividad por día de la semana',
                    Icons.calendar_today,
                    Colors.green,
                    () => _showDailyActivity(),
                  ),
                  _buildFeatureCard(
                    'Autorizaciones',
                    'Análisis de autorizaciones manuales',
                    Icons.verified_user,
                    Colors.red,
                    () => _showAuthorizations(),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 20),
            
            // Botón para abrir vista completa
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChangeNotifierProvider.value(
                        value: _viewModel,
                        child: GuardReportsView(),
                      ),
                    ),
                  );
                },
                icon: Icon(Icons.analytics),
                label: Text('Abrir Vista Completa'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: color,
              ),
              SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGeneralSummary() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Resumen General'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Total de asistencias en el período'),
            Text('• Número de guardias activos'),
            Text('• Cantidad de autorizaciones manuales'),
            Text('• Puerta más utilizada'),
            Text('• Facultad más atendida'),
            Text('• Promedio diario de actividad'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showRanking() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ranking de Guardias'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Lista ordenada por actividad'),
            Text('• Estadísticas individuales'),
            Text('• Entradas vs salidas'),
            Text('• Autorizaciones manuales'),
            Text('• Promedio diario de asistencias'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showDailyActivity() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Actividad Diaria'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Gráfico de actividad por día'),
            Text('• Análisis de patrones de trabajo'),
            Text('• Detalle por día de la semana'),
            Text('• Identificación de días pico'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showAuthorizations() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Autorizaciones'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Lista de guardias con más autorizaciones'),
            Text('• Análisis de casos manuales'),
            Text('• Estadísticas de autorizaciones'),
            Text('• Identificación de patrones'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
