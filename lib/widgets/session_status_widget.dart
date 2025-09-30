import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/session_guard_service.dart';

class SessionStatusWidget extends StatefulWidget {
  final String? guardiaId;
  final String? guardiaNombre;
  final String? puntoControl;

  const SessionStatusWidget({
    Key? key,
    this.guardiaId,
    this.guardiaNombre,
    this.puntoControl,
  }) : super(key: key);

  @override
  State<SessionStatusWidget> createState() => _SessionStatusWidgetState();
}

class _SessionStatusWidgetState extends State<SessionStatusWidget> {
  final SessionGuardService _sessionService = SessionGuardService();

  @override
  void initState() {
    super.initState();
    _initializeSession();
  }

  Future<void> _initializeSession() async {
    if (widget.guardiaId != null &&
        widget.guardiaNombre != null &&
        widget.puntoControl != null) {
      await _iniciarSesion();
    }
  }

  Future<void> _iniciarSesion() async {
    final result = await _sessionService.iniciarSesion(
      guardiaId: widget.guardiaId!,
      guardiaNombre: widget.guardiaNombre!,
      puntoControl: widget.puntoControl!,
    );

    if (result.isConflict && mounted) {
      _mostrarDialogConflicto(result);
    } else if (!result.isSuccess && mounted) {
      _mostrarError(result.message);
    }
  }

  void _mostrarDialogConflicto(SessionResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => ConflictResolutionDialog(
            conflictData: result.conflictData!,
            onResolve: _resolverConflicto,
            onCancel: () => Navigator.of(context).pop(),
          ),
    );
  }

  Future<void> _resolverConflicto(bool forzarControl) async {
    Navigator.of(context).pop(); // Cerrar diálogo

    if (forzarControl) {
      final result = await _sessionService.resolverConflicto(
        forzarControl: true,
      );

      if (result.isSuccess) {
        _mostrarMensaje('Sesión iniciada exitosamente', Colors.green);
      } else {
        _mostrarError(result.message);
      }
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _mostrarMensaje(String mensaje, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _sessionService,
      child: Consumer<SessionGuardService>(
        builder: (context, sessionService, child) {
          return Column(
            children: [
              // Indicador de estado de sesión
              _buildSessionIndicator(sessionService),

              // Indicador de conflicto si existe
              if (sessionService.hasConflict)
                _buildConflictIndicator(sessionService),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSessionIndicator(SessionGuardService sessionService) {
    if (!sessionService.isSessionActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.orange[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange),
        ),
        child: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange[700]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sesión no iniciada',
                style: GoogleFonts.lato(
                  color: Colors.orange[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (widget.guardiaId != null)
              TextButton(onPressed: _iniciarSesion, child: Text('Reintentar')),
          ],
        ),
      );
    }

    // Sesión activa
    final tiempoSesion = sessionService.tiempoSesion;
    final tiempoTexto =
        tiempoSesion != null ? _formatearTiempo(tiempoSesion) : 'Calculando...';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[700]),
              const SizedBox(width: 8),
              Text(
                'Sesión Activa',
                style: GoogleFonts.lato(
                  color: Colors.green[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tiempoTexto,
                  style: GoogleFonts.lato(
                    color: Colors.green[800],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Guardia: ${sessionService.guardiaNombre ?? 'N/A'}',
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    Text(
                      'Punto: ${sessionService.puntoControl ?? 'N/A'}',
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _mostrarDetallesSesion(sessionService),
                icon: Icon(Icons.info_outline, color: Colors.green[700]),
                tooltip: 'Detalles de sesión',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConflictIndicator(SessionGuardService sessionService) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error, color: Colors.red[700]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Conflicto Detectado',
                  style: GoogleFonts.lato(
                    color: Colors.red[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Otro guardia está activo en este punto de control',
            style: GoogleFonts.lato(fontSize: 14, color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => sessionService.verificarEstadoSesion(),
                child: Text('Verificar'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _resolverConflicto(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text('Tomar Control'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _mostrarDetallesSesion(SessionGuardService sessionService) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Detalles de Sesión'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetalle('Token', sessionService.sessionToken ?? 'N/A'),
                _buildDetalle('Guardia', sessionService.guardiaNombre ?? 'N/A'),
                _buildDetalle(
                  'Punto Control',
                  sessionService.puntoControl ?? 'N/A',
                ),
                _buildDetalle(
                  'Inicio',
                  sessionService.sessionStartTime?.toString() ?? 'N/A',
                ),
                _buildDetalle(
                  'Duración',
                  sessionService.tiempoSesion != null
                      ? _formatearTiempo(sessionService.tiempoSesion!)
                      : 'N/A',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cerrar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  final success = await sessionService.finalizarSesion();
                  if (success) {
                    _mostrarMensaje('Sesión finalizada', Colors.blue);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text('Finalizar Sesión'),
              ),
            ],
          ),
    );
  }

  Widget _buildDetalle(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: GoogleFonts.lato(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value, style: GoogleFonts.lato())),
        ],
      ),
    );
  }

  String _formatearTiempo(Duration duration) {
    final horas = duration.inHours;
    final minutos = duration.inMinutes % 60;
    final segundos = duration.inSeconds % 60;

    if (horas > 0) {
      return '${horas}h ${minutos}m ${segundos}s';
    } else if (minutos > 0) {
      return '${minutos}m ${segundos}s';
    } else {
      return '${segundos}s';
    }
  }
}

class ConflictResolutionDialog extends StatelessWidget {
  final Map<String, dynamic> conflictData;
  final Function(bool) onResolve;
  final VoidCallback onCancel;

  const ConflictResolutionDialog({
    Key? key,
    required this.conflictData,
    required this.onResolve,
    required this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning, color: Colors.orange),
          const SizedBox(width: 8),
          Text('Conflicto Detectado'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Otro guardia ya está activo en este punto de control:',
            style: GoogleFonts.lato(fontSize: 16),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Guardia: ${conflictData['guardia_nombre'] ?? 'N/A'}',
                  style: GoogleFonts.lato(fontWeight: FontWeight.bold),
                ),
                Text(
                  'ID: ${conflictData['guardia_id'] ?? 'N/A'}',
                  style: GoogleFonts.lato(color: Colors.grey[600]),
                ),
                if (conflictData['session_start'] != null)
                  Text(
                    'Inicio: ${DateTime.parse(conflictData['session_start']).toString()}',
                    style: GoogleFonts.lato(color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '¿Desea tomar control del punto de control?',
            style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: onCancel, child: Text('Cancelar')),
        ElevatedButton(
          onPressed: () => onResolve(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          child: Text('Tomar Control'),
        ),
      ],
    );
  }
}
