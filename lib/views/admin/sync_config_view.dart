import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/sync_service.dart';
import '../../widgets/custom_button.dart';

class SyncConfigView extends StatefulWidget {
  @override
  _SyncConfigViewState createState() => _SyncConfigViewState();
}

class _SyncConfigViewState extends State<SyncConfigView> {
  @override
  void initState() {
    super.initState();
    // Inicializar sincronización automática
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SyncService().initAutoSync();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sincronización de Datos'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () async {
              await SyncService().performSync();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Sincronización manual iniciada')),
              );
            },
          ),
        ],
      ),
      body: ChangeNotifierProvider.value(
        value: SyncService(),
        child: Consumer<SyncService>(
          builder: (context, syncService, child) {
            return SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Estado actual
                  _buildStatusCard(syncService),
                  SizedBox(height: 16),

                  // Configuración
                  _buildConfigCard(syncService),
                  SizedBox(height: 16),

                  // Acciones rápidas
                  _buildQuickActions(syncService),
                  SizedBox(height: 16),

                  // Log de sincronización
                  _buildSyncLog(syncService),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusCard(SyncService syncService) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  syncService.isSyncing
                      ? Icons.sync
                      : syncService.autoSyncEnabled
                      ? Icons.sync_alt
                      : Icons.sync_disabled,
                  color:
                      syncService.isSyncing
                          ? Colors.blue
                          : syncService.autoSyncEnabled
                          ? Colors.green
                          : Colors.red,
                ),
                SizedBox(width: 8),
                Text(
                  'Estado de Sincronización',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 12),

            _buildStatusRow(
              'Estado actual',
              syncService.isSyncing ? 'Sincronizando...' : 'En reposo',
              syncService.isSyncing ? Colors.blue : Colors.green,
            ),

            _buildStatusRow(
              'Sincronización automática',
              syncService.autoSyncEnabled ? 'Activada' : 'Desactivada',
              syncService.autoSyncEnabled ? Colors.green : Colors.red,
            ),

            _buildStatusRow(
              'Última sincronización',
              syncService.getLastSyncStatus(),
              Colors.grey[700]!,
            ),

            if (syncService.autoSyncEnabled &&
                syncService.getTimeToNextSync() != null)
              _buildStatusRow(
                'Próxima sincronización',
                _formatDuration(syncService.getTimeToNextSync()!),
                Colors.blue,
              ),

            if (syncService.syncError != null)
              Container(
                width: double.infinity,
                margin: EdgeInsets.only(top: 8),
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: Border.all(color: Colors.red[200]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[600], size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Error: ${syncService.syncError}',
                        style: TextStyle(color: Colors.red[700], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigCard(SyncService syncService) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configuración',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),

            // Toggle sincronización automática
            SwitchListTile(
              title: Text('Sincronización automática'),
              subtitle: Text('Sincronizar datos automáticamente'),
              value: syncService.autoSyncEnabled,
              onChanged: (value) {
                syncService.toggleAutoSync(value);
              },
            ),

            Divider(),

            // Intervalo de sincronización
            ListTile(
              title: Text('Intervalo de sincronización'),
              subtitle: Text('${syncService.syncIntervalMinutes} minutos'),
              trailing: PopupMenuButton<int>(
                onSelected: (minutes) {
                  syncService.configureSyncInterval(minutes);
                },
                itemBuilder:
                    (context) => [
                      PopupMenuItem(value: 15, child: Text('15 minutos')),
                      PopupMenuItem(value: 30, child: Text('30 minutos')),
                      PopupMenuItem(value: 60, child: Text('1 hora')),
                      PopupMenuItem(value: 120, child: Text('2 horas')),
                      PopupMenuItem(value: 240, child: Text('4 horas')),
                    ],
                child: Icon(Icons.more_vert),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(SyncService syncService) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Acciones Rápidas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'Sincronizar Ahora',
                    icon: Icons.sync,
                    isLoading: syncService.isSyncing,
                    onPressed:
                        syncService.isSyncing
                            ? null
                            : () async {
                              bool success = await syncService.performSync();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    success
                                        ? '✅ Sincronización completada'
                                        : '❌ Error en la sincronización',
                                  ),
                                  backgroundColor:
                                      success ? Colors.green : Colors.red,
                                ),
                              );
                            },
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: CustomButton(
                    text: 'Limpiar Log',
                    icon: Icons.clear_all,
                    backgroundColor: Colors.grey[600],
                    onPressed: () {
                      syncService.clearSyncLog();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Log de sincronización limpiado'),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncLog(SyncService syncService) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.list_alt, size: 20),
                SizedBox(width: 8),
                Text(
                  'Log de Sincronización',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 12),

            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(4),
              ),
              child:
                  syncService.syncLog.isEmpty
                      ? Center(
                        child: Text(
                          'Sin entradas en el log',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                      : ListView.builder(
                        padding: EdgeInsets.all(8),
                        itemCount: syncService.syncLog.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              syncService.syncLog[index],
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                                color: Colors.grey[800],
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

  Widget _buildStatusRow(String label, String value, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w500, color: color),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inMinutes < 1) {
      return '${duration.inSeconds} segundos';
    } else if (duration.inHours < 1) {
      return '${duration.inMinutes} minutos';
    } else {
      return '${duration.inHours} horas';
    }
  }
}
