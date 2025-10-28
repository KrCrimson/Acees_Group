import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/connectivity_service.dart';
import '../../services/offline_sync_service.dart';
import '../../services/hybrid_api_service.dart';
import '../../widgets/connectivity_status_widget.dart';

class OfflineDemoView extends StatefulWidget {
  @override
  _OfflineDemoViewState createState() => _OfflineDemoViewState();
}

class _OfflineDemoViewState extends State<OfflineDemoView> {
  String _demoStatus = 'Iniciando demo...';
  List<String> _demoLog = [];

  @override
  void initState() {
    super.initState();
    _startDemo();
  }

  Future<void> _startDemo() async {
    _addLog('🚀 Iniciando demo de funcionalidad offline');
    
    // Simular operaciones offline
    await _simulateOfflineOperations();
  }

  Future<void> _simulateOfflineOperations() async {
    final connectivityService = Provider.of<ConnectivityService>(context, listen: false);
    final syncService = Provider.of<OfflineSyncService>(context, listen: false);
    final hybridService = Provider.of<HybridApiService>(context, listen: false);

    _addLog('📊 Estado actual: ${connectivityService.isOnline ? "En línea" : "Sin conexión"}');
    _addLog('📦 Elementos pendientes: ${syncService.pendingSyncCount}');

    // Simular pérdida de conexión
    _addLog('🔴 Simulando pérdida de conexión...');
    await Future.delayed(Duration(seconds: 2));

    _addLog('📝 Registrando asistencias en modo offline...');
    await _simulateOfflineAttendance();

    _addLog('⏳ Esperando restauración de conexión...');
    await Future.delayed(Duration(seconds: 3));

    _addLog('🟢 Conexión restaurada - iniciando sincronización...');
    await syncService.performSync();

    _addLog('✅ Demo completado');
    setState(() {
      _demoStatus = 'Demo completado exitosamente';
    });
  }

  Future<void> _simulateOfflineAttendance() async {
    // Simular registro de asistencias offline
    for (int i = 1; i <= 3; i++) {
      _addLog('👤 Registrando asistencia $i...');
      await Future.delayed(Duration(milliseconds: 500));
    }
  }

  void _addLog(String message) {
    setState(() {
      _demoLog.add('${DateTime.now().toIso8601String().substring(11, 19)} - $message');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Demo Funcionalidad Offline'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          ConnectivityStatusWidget(showDetails: true),
          SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Estado del demo
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.play_circle, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Estado del Demo',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(_demoStatus),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Información de conectividad
            Consumer<ConnectivityService>(
              builder: (context, connectivityService, child) {
                return Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estado de Conectividad',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 12),
                        _buildInfoRow('Estado', connectivityService.isOnline ? 'En línea' : 'Sin conexión'),
                        _buildInfoRow('Tipo', connectivityService.connectionDescription),
                        _buildInfoRow('Tiempo offline', connectivityService.timeOffline?.inMinutes.toString() ?? 'N/A'),
                      ],
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 16),

            // Estadísticas de sincronización
            Consumer<OfflineSyncService>(
              builder: (context, syncService, child) {
                return Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estadísticas de Sincronización',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 12),
                        _buildInfoRow('Elementos pendientes', '${syncService.pendingSyncCount}'),
                        _buildInfoRow('Sincronizando', syncService.isSyncing ? 'Sí' : 'No'),
                        _buildInfoRow('Auto-sync', syncService.autoSyncEnabled ? 'Activado' : 'Desactivado'),
                        if (syncService.lastSyncTime != null)
                          _buildInfoRow('Última sync', _formatDateTime(syncService.lastSyncTime!)),
                      ],
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 16),

            // Log del demo
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Log del Demo',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _demoLog.clear();
                              _demoStatus = 'Demo reiniciado';
                            });
                            _startDemo();
                          },
                          child: Text('Reiniciar'),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Container(
                      height: 300,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: ListView.builder(
                        padding: EdgeInsets.all(8),
                        itemCount: _demoLog.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              _demoLog[index],
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                                color: Colors.grey[700],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Botones de acción
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OfflineConfigView(),
                        ),
                      );
                    },
                    icon: Icon(Icons.settings),
                    label: Text('Configuración'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final syncService = Provider.of<OfflineSyncService>(context, listen: false);
                      syncService.performSync();
                    },
                    icon: Icon(Icons.sync),
                    label: Text('Sincronizar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(color: Colors.grey[700])),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
