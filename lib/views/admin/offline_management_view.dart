import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../services/offline_service.dart';
import '../../widgets/connectivity_status_widget.dart';

class OfflineManagementView extends StatefulWidget {
  const OfflineManagementView({Key? key}) : super(key: key);

  @override
  State<OfflineManagementView> createState() => _OfflineManagementViewState();
}

class _OfflineManagementViewState extends State<OfflineManagementView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gestión Offline',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
      ),
      body: ConnectivityStatusWidget(
        child: Consumer<OfflineService>(
          builder: (context, offlineService, _) {
            return RefreshIndicator(
              onRefresh: () => _refreshData(offlineService),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildConnectionStatusCard(offlineService),
                    const SizedBox(height: 16),
                    _buildStatisticsCard(offlineService),
                    const SizedBox(height: 16),
                    _buildPendingEventsCard(offlineService),
                    const SizedBox(height: 16),
                    _buildActionsCard(offlineService),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _refreshData(OfflineService offlineService) async {
    // Simular refresh de datos
    await Future.delayed(const Duration(seconds: 1));
    setState(() {});
  }

  Widget _buildConnectionStatusCard(OfflineService offlineService) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (offlineService.connectionStatus) {
      case ConnectionStatus.online:
        statusColor = Colors.green;
        statusIcon = Icons.cloud_done;
        statusText = 'En línea';
        break;
      case ConnectionStatus.offline:
        statusColor = Colors.red;
        statusIcon = Icons.cloud_off;
        statusText = 'Sin conexión';
        break;
      case ConnectionStatus.connecting:
        statusColor = Colors.orange;
        statusIcon = Icons.cloud_queue;
        statusText = 'Conectando...';
        break;
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estado de Conexión',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 16,
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (offlineService.isSyncing)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            if (offlineService.connectionStatus == ConnectionStatus.offline)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.red.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'La aplicación está funcionando en modo offline. Los datos se sincronizarán automáticamente al restaurar la conexión.',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 14,
                        ),
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

  Widget _buildStatisticsCard(OfflineService offlineService) {
    final stats = offlineService.getEventStatistics();

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estadísticas de Eventos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Pendientes',
                    stats['pending'] ?? 0,
                    Colors.orange,
                    Icons.pending_actions,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Sincronizando',
                    stats['syncing'] ?? 0,
                    Colors.blue,
                    Icons.sync,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Completados',
                    stats['completed'] ?? 0,
                    Colors.green,
                    Icons.check_circle,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Fallidos',
                    stats['failed'] ?? 0,
                    Colors.red,
                    Icons.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPendingEventsCard(OfflineService offlineService) {
    final pendingEvents = offlineService.pendingEvents;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Eventos Pendientes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                if (pendingEvents.isNotEmpty)
                  Text(
                    '${pendingEvents.length} eventos',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (pendingEvents.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 48,
                      color: Colors.green.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No hay eventos pendientes',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: pendingEvents.length > 5 ? 5 : pendingEvents.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final event = pendingEvents[index];
                  return _buildEventTile(event);
                },
              ),
            if (pendingEvents.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '... y ${pendingEvents.length - 5} eventos más',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventTile(OfflineEvent event) {
    Color statusColor;
    IconData statusIcon;

    switch (event.status) {
      case EventStatus.pending:
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        break;
      case EventStatus.syncing:
        statusColor = Colors.blue;
        statusIcon = Icons.sync;
        break;
      case EventStatus.completed:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case EventStatus.failed:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
    }

    return ListTile(
      dense: true,
      leading: Icon(statusIcon, color: statusColor, size: 20),
      title: Text(
        _getEventTypeLabel(event.type),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        DateFormat('dd/MM/yyyy HH:mm').format(event.timestamp),
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      trailing:
          event.retryCount > 0
              ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Reintento ${event.retryCount}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
              : null,
    );
  }

  String _getEventTypeLabel(EventType type) {
    switch (type) {
      case EventType.asistencia:
        return 'Registro de Asistencia';
      case EventType.sesionInicio:
        return 'Inicio de Sesión';
      case EventType.sesionFin:
        return 'Fin de Sesión';
      case EventType.actualizacionPerfil:
        return 'Actualización de Perfil';
    }
  }

  Widget _buildActionsCard(OfflineService offlineService) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Acciones',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    offlineService.isOnline && !offlineService.isSyncing
                        ? () => _forceSyncEvents(offlineService)
                        : null,
                icon:
                    offlineService.isSyncing
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.sync),
                label: Text(
                  offlineService.isSyncing
                      ? 'Sincronizando...'
                      : 'Forzar Sincronización',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                    offlineService.getEventStatistics()['failed'] != 0
                        ? () => _clearFailedEvents(offlineService)
                        : null,
                icon: const Icon(Icons.clear_all),
                label: const Text('Limpiar Eventos Fallidos'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade600,
                  side: BorderSide(color: Colors.red.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _forceSyncEvents(OfflineService offlineService) async {
    try {
      await offlineService.forceSyncPendingEvents();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sincronización completada'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error en sincronización: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _clearFailedEvents(OfflineService offlineService) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmar Acción'),
            content: const Text(
              '¿Está seguro de que desea eliminar todos los eventos fallidos? Esta acción no se puede deshacer.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Eliminar'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      await offlineService.clearFailedEvents();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Eventos fallidos eliminados'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}
