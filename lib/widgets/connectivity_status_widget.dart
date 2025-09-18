import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connectivity_service.dart';
import '../services/offline_sync_service.dart';

class ConnectivityStatusWidget extends StatelessWidget {
  final bool showDetails;
  final VoidCallback? onTap;

  const ConnectivityStatusWidget({
    Key? key,
    this.showDetails = false,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer2<ConnectivityService, OfflineSyncService>(
      builder: (context, connectivityService, syncService, child) {
        final isOnline = connectivityService.isOnline;
        final pendingCount = syncService.pendingSyncCount;
        final isSyncing = syncService.isSyncing;

        return GestureDetector(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _getStatusColor(isOnline, pendingCount, isSyncing),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStatusIcon(isOnline, isSyncing),
                SizedBox(width: 8),
                if (showDetails) ...[
                  _buildStatusText(connectivityService, syncService),
                  SizedBox(width: 8),
                ],
                _buildPendingBadge(pendingCount),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusIcon(bool isOnline, bool isSyncing) {
    if (isSyncing) {
      return SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    return Icon(
      isOnline ? Icons.wifi : Icons.wifi_off,
      size: 16,
      color: Colors.white,
    );
  }

  Widget _buildStatusText(ConnectivityService connectivity, OfflineSyncService sync) {
    if (sync.isSyncing) {
      return Text(
        'Sincronizando...',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          connectivity.isOnline ? 'En línea' : 'Sin conexión',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (connectivity.isOnline)
          Text(
            connectivity.connectionDescription,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 10,
            ),
          ),
      ],
    );
  }

  Widget _buildPendingBadge(int pendingCount) {
    if (pendingCount == 0) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$pendingCount',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getStatusColor(bool isOnline, int pendingCount, bool isSyncing) {
    if (isSyncing) return Colors.blue;
    if (isOnline) {
      if (pendingCount > 0) return Colors.orange;
      return Colors.green;
    }
    return Colors.red;
  }
}

class ConnectivityStatusBanner extends StatelessWidget {
  const ConnectivityStatusBanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityService>(
      builder: (context, connectivityService, child) {
        if (connectivityService.isOnline) return SizedBox.shrink();

        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.red[600],
          child: Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Sin conexión a internet',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Los datos se guardarán localmente y se sincronizarán cuando se restaure la conexión',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class SyncProgressDialog extends StatelessWidget {
  const SyncProgressDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineSyncService>(
      builder: (context, syncService, child) {
        return AlertDialog(
          title: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: syncService.isSyncing
                    ? CircularProgressIndicator(strokeWidth: 2)
                    : Icon(Icons.sync),
              ),
              SizedBox(width: 12),
              Text('Sincronización'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                syncService.isSyncing
                    ? 'Sincronizando datos...'
                    : 'Sincronización completada',
              ),
              SizedBox(height: 16),
              if (syncService.pendingSyncCount > 0) ...[
                Text('Elementos pendientes: ${syncService.pendingSyncCount}'),
                SizedBox(height: 8),
              ],
              if (syncService.lastSyncTime != null) ...[
                Text(
                  'Última sincronización: ${_formatDateTime(syncService.lastSyncTime!)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
              if (syncService.lastSyncError != null) ...[
                SizedBox(height: 8),
                Text(
                  'Error: ${syncService.lastSyncError}',
                  style: TextStyle(fontSize: 12, color: Colors.red[600]),
                ),
              ],
            ],
          ),
          actions: [
            if (syncService.isSyncing)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cerrar'),
              )
            else ...[
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cerrar'),
              ),
              ElevatedButton(
                onPressed: () {
                  syncService.performSync();
                },
                child: Text('Sincronizar'),
              ),
            ],
          ],
        );
      },
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

class OfflineModeIndicator extends StatelessWidget {
  final Widget child;

  const OfflineModeIndicator({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityService>(
      builder: (context, connectivityService, child) {
        return Stack(
          children: [
            this.child,
            if (!connectivityService.isOnline)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ConnectivityStatusBanner(),
              ),
          ],
        );
      },
    );
  }
}
