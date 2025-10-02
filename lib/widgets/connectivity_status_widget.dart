import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/offline_service.dart';

class ConnectivityStatusWidget extends StatelessWidget {
  final Widget child;

  const ConnectivityStatusWidget({Key? key, required this.child})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineService>(
      builder: (context, offlineService, _) {
        return Stack(
          children: [
            child,
            if (offlineService.connectionStatus != ConnectionStatus.online)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ConnectivityBanner(
                  status: offlineService.connectionStatus,
                  pendingEvents: offlineService.pendingEventCount,
                  onRetry: () => offlineService.forceSyncPendingEvents(),
                ),
              ),
          ],
        );
      },
    );
  }
}

class ConnectivityBanner extends StatelessWidget {
  final ConnectionStatus status;
  final int pendingEvents;
  final VoidCallback? onRetry;

  const ConnectivityBanner({
    Key? key,
    required this.status,
    required this.pendingEvents,
    this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    IconData icon;
    String message;

    switch (status) {
      case ConnectionStatus.offline:
        backgroundColor = Colors.red.shade600;
        icon = Icons.cloud_off;
        message = 'Sin conexión';
        if (pendingEvents > 0) {
          message += ' • $pendingEvents eventos pendientes';
        }
        break;
      case ConnectionStatus.connecting:
        backgroundColor = Colors.orange.shade600;
        icon = Icons.cloud_queue;
        message = 'Reconectando...';
        break;
      case ConnectionStatus.online:
        backgroundColor = Colors.green.shade600;
        icon = Icons.cloud_done;
        message = 'Conectado';
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (status != ConnectionStatus.online && onRetry != null)
              GestureDetector(
                onTap: status == ConnectionStatus.connecting ? null : onRetry,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(
                      status == ConnectionStatus.connecting ? 0.1 : 0.2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status == ConnectionStatus.connecting
                        ? 'Verificando...'
                        : 'Reintentar',
                    style: TextStyle(
                      color: Colors.white.withOpacity(
                        status == ConnectionStatus.connecting ? 0.7 : 1.0,
                      ),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class OfflineIndicator extends StatelessWidget {
  final double size;
  final Color? color;

  const OfflineIndicator({Key? key, this.size = 24, this.color})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineService>(
      builder: (context, offlineService, _) {
        if (offlineService.isOnline) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.red.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.shade300, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off,
                size: size,
                color: color ?? Colors.red.shade600,
              ),
              const SizedBox(width: 4),
              Text(
                'Offline',
                style: TextStyle(
                  color: color ?? Colors.red.shade600,
                  fontSize: size * 0.6,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class PendingEventsIndicator extends StatelessWidget {
  final VoidCallback? onTap;

  const PendingEventsIndicator({Key? key, this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineService>(
      builder: (context, offlineService, _) {
        final pendingCount = offlineService.pendingEventCount;

        if (pendingCount == 0) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color:
                  offlineService.isOnline
                      ? Colors.blue.shade100
                      : Colors.orange.shade100,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    offlineService.isOnline
                        ? Colors.blue.shade300
                        : Colors.orange.shade300,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  offlineService.isSyncing ? Icons.sync : Icons.cloud_upload,
                  size: 16,
                  color:
                      offlineService.isOnline
                          ? Colors.blue.shade600
                          : Colors.orange.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  '$pendingCount pendientes',
                  style: TextStyle(
                    color:
                        offlineService.isOnline
                            ? Colors.blue.shade600
                            : Colors.orange.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (offlineService.isSyncing)
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation(
                        offlineService.isOnline
                            ? Colors.blue.shade600
                            : Colors.orange.shade600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
