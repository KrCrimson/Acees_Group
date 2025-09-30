import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/session_guard_service.dart';

class ConflictAlertWidget extends StatefulWidget {
  @override
  _ConflictAlertWidgetState createState() => _ConflictAlertWidgetState();
}

class _ConflictAlertWidgetState extends State<ConflictAlertWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _colorAnimation = ColorTween(
      begin: Colors.orange[300],
      end: Colors.red[400],
    ).animate(_animationController);

    // Animación pulsante para llamar la atención
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionGuardService>(
      builder: (context, sessionService, child) {
        if (!sessionService.hasConflict) {
          return SizedBox.shrink();
        }

        return AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: GestureDetector(
                onTap: () => _showConflictDialog(context, sessionService),
                child: Container(
                  margin: EdgeInsets.all(8),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _colorAnimation.value,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.4),
                        spreadRadius: 2,
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '¡Conflicto de Guardia Detectado!',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.touch_app, color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showConflictDialog(
    BuildContext context,
    SessionGuardService sessionService,
  ) {
    final conflictData = sessionService.conflictData;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 28,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Conflicto de Sesión',
                    style: TextStyle(
                      color: Colors.red[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Otro guardia está activo en este punto:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '📍 Punto: ${conflictData?['active_guard']?['punto_control'] ?? 'Desconocido'}',
                      ),
                      Text(
                        '👤 Guardia: ${conflictData?['active_guard']?['guardia_nombre'] ?? 'Desconocido'}',
                      ),
                      if (conflictData?['active_guard']?['session_start'] !=
                          null)
                        Text(
                          '⏰ Sesión iniciada: ${_formatDateTime(conflictData!['active_guard']['session_start'])}',
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  '¿Qué desea hacer?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  sessionService.cancelSession();
                },
                child: Text(
                  'Cancelar mi Sesión',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _handleTakeControl(context, sessionService);
                },
                icon: Icon(Icons.swap_horiz, size: 18),
                label: Text('Tomar Control'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
    );
  }

  void _handleTakeControl(
    BuildContext context,
    SessionGuardService sessionService,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.security, color: Colors.orange),
                SizedBox(width: 8),
                Text('Confirmar Acción'),
              ],
            ),
            content: Text(
              '¿Está seguro de que desea tomar control de este punto? '
              'Esto finalizará la sesión del otro guardia.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await sessionService.forceSessionTakeover();

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✅ Sesión tomada exitosamente'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text('Tomar Control'),
              ),
            ],
          ),
    );
  }

  String _formatDateTime(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString);
      return '${dateTime.day}/${dateTime.month} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Fecha inválida';
    }
  }
}

/// Widget flotante que se puede usar en cualquier pantalla
class FloatingConflictAlert extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: kToolbarHeight + 20,
      left: 16,
      right: 16,
      child: ConflictAlertWidget(),
    );
  }
}

/// Widget para mostrar en AppBar
class AppBarConflictIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<SessionGuardService>(
      builder: (context, sessionService, child) {
        if (!sessionService.hasConflict) {
          return SizedBox.shrink();
        }

        return IconButton(
          onPressed: () {
            // Mostrar detalles del conflicto
            _showConflictBottomSheet(context, sessionService);
          },
          icon: Container(
            padding: EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.warning, color: Colors.white, size: 20),
          ),
          tooltip: 'Conflicto de sesión detectado',
        );
      },
    );
  }

  void _showConflictBottomSheet(
    BuildContext context,
    SessionGuardService sessionService,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.4,
            maxChildSize: 0.7,
            minChildSize: 0.3,
            expand: false,
            builder: (context, scrollController) {
              return Container(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber,
                          color: Colors.orange,
                          size: 28,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Conflicto de Sesión Detectado',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        children: [
                          _buildConflictDetailCard(sessionService),
                          SizedBox(height: 20),
                          _buildActionButtons(context, sessionService),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }

  Widget _buildConflictDetailCard(SessionGuardService sessionService) {
    final conflictData = sessionService.conflictData;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detalles del Conflicto',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 12),
            _buildDetailRow(
              'Punto de Control',
              conflictData?['active_guard']?['punto_control'] ?? '-',
            ),
            _buildDetailRow(
              'Guardia Activo',
              conflictData?['active_guard']?['guardia_nombre'] ?? '-',
            ),
            _buildDetailRow(
              'Sesión Iniciada',
              _formatDateTime(
                conflictData?['active_guard']?['session_start'] ?? '',
              ),
            ),
            _buildDetailRow(
              'Última Actividad',
              _formatDateTime(
                conflictData?['active_guard']?['last_activity'] ?? '',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    SessionGuardService sessionService,
  ) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              sessionService.forceSessionTakeover();
            },
            icon: Icon(Icons.swap_horiz),
            label: Text('Tomar Control del Punto'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              sessionService.cancelSession();
            },
            icon: Icon(Icons.cancel),
            label: Text('Cancelar mi Sesión'),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(String isoString) {
    if (isoString.isEmpty) return 'No disponible';

    try {
      final dateTime = DateTime.parse(isoString);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Fecha inválida';
    }
  }
}
