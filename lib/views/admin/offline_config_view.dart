import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/connectivity_service.dart';
import '../../services/offline_sync_service.dart';
import '../../widgets/connectivity_status_widget.dart';

class OfflineConfigView extends StatefulWidget {
  @override
  _OfflineConfigViewState createState() => _OfflineConfigViewState();
}

class _OfflineConfigViewState extends State<OfflineConfigView> {
  int _syncInterval = 5;
  bool _autoSyncEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  void _loadCurrentSettings() {
    final syncService = Provider.of<OfflineSyncService>(context, listen: false);
    setState(() {
      _syncInterval = syncService.syncIntervalMinutes;
      _autoSyncEnabled = syncService.autoSyncEnabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Configuración Offline'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          ConnectivityStatusWidget(showDetails: true),
          SizedBox(width: 16),
        ],
      ),
      body: Consumer2<ConnectivityService, OfflineSyncService>(
        builder: (context, connectivityService, syncService, child) {
          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Estado de conectividad
                _buildConnectivityStatusCard(connectivityService),
                SizedBox(height: 16),

                // Configuración de sincronización
                _buildSyncConfigCard(syncService),
                SizedBox(height: 16),

                // Estadísticas de sincronización
                _buildSyncStatsCard(syncService),
                SizedBox(height: 16),

                // Log de sincronización
                _buildSyncLogCard(syncService),
                SizedBox(height: 16),

                // Acciones
                _buildActionButtons(syncService),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildConnectivityStatusCard(ConnectivityService connectivityService) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  connectivityService.isOnline ? Icons.wifi : Icons.wifi_off,
                  color: connectivityService.isOnline ? Colors.green : Colors.red,
                ),
                SizedBox(width: 8),
                Text(
                  'Estado de Conectividad',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 12),
            _buildStatusRow('Estado', connectivityService.isOnline ? 'En línea' : 'Sin conexión'),
            _buildStatusRow('Tipo de conexión', connectivityService.connectionDescription),
            if (connectivityService.lastOnlineTime != null)
              _buildStatusRow('Última conexión', _formatDateTime(connectivityService.lastOnlineTime!)),
            if (connectivityService.lastOfflineTime != null)
              _buildStatusRow('Última desconexión', _formatDateTime(connectivityService.lastOfflineTime!)),
            if (connectivityService.timeOffline != null)
              _buildStatusRow('Tiempo offline', _formatDuration(connectivityService.timeOffline!)),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncConfigCard(OfflineSyncService syncService) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configuración de Sincronización',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            
            // Auto-sincronización
            SwitchListTile(
              title: Text('Sincronización automática'),
              subtitle: Text('Sincronizar automáticamente cuando esté en línea'),
              value: _autoSyncEnabled,
              onChanged: (value) {
                setState(() {
                  _autoSyncEnabled = value;
                });
                syncService.toggleAutoSync(value);
              },
            ),
            
            // Intervalo de sincronización
            ListTile(
              title: Text('Intervalo de sincronización'),
              subtitle: Text('Cada $_syncInterval minutos'),
              trailing: DropdownButton<int>(
                value: _syncInterval,
                items: [1, 2, 5, 10, 15, 30, 60].map((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text('$value min'),
                  );
                }).toList(),
                onChanged: _autoSyncEnabled ? (int? value) {
                  if (value != null) {
                    setState(() {
                      _syncInterval = value;
                    });
                    syncService.configureSyncInterval(value);
                  }
                } : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStatsCard(OfflineSyncService syncService) {
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
            _buildStatusRow('Elementos pendientes', '${syncService.pendingSyncCount}'),
            _buildStatusRow('Sincronizando', syncService.isSyncing ? 'Sí' : 'No'),
            if (syncService.lastSyncTime != null)
              _buildStatusRow('Última sincronización', _formatDateTime(syncService.lastSyncTime!)),
            if (syncService.lastSyncError != null) ...[
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red[600], size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Error: ${syncService.lastSyncError}',
                        style: TextStyle(color: Colors.red[700], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSyncLogCard(OfflineSyncService syncService) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Log de Sincronización',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    // TODO: Implementar limpieza de logs
                  },
                  child: Text('Limpiar'),
                ),
              ],
            ),
            SizedBox(height: 12),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ListView.builder(
                padding: EdgeInsets.all(8),
                itemCount: syncService.syncLog.length,
                itemBuilder: (context, index) {
                  final logEntry = syncService.syncLog[index];
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      logEntry,
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
    );
  }

  Widget _buildActionButtons(OfflineSyncService syncService) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Acciones',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: syncService.isSyncing ? null : () {
                      syncService.performSync();
                    },
                    icon: syncService.isSyncing 
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.sync),
                    label: Text(syncService.isSyncing ? 'Sincronizando...' : 'Sincronizar Ahora'),
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
                      _showSyncDialog(syncService);
                    },
                    icon: Icon(Icons.info),
                    label: Text('Ver Detalles'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
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

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }

  void _showSyncDialog(OfflineSyncService syncService) {
    showDialog(
      context: context,
      builder: (context) => SyncProgressDialog(),
    );
  }
}
