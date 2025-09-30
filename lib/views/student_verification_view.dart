import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/alumno_model.dart';
import '../models/decision_manual_model.dart';
import '../services/api_service.dart';

class StudentVerificationView extends StatefulWidget {
  final AlumnoModel estudiante;
  final String guardiaId;
  final String guardiaNombre;
  final String puntoControl;
  final String tipoAcceso; // 'entrada' o 'salida'
  final Function(DecisionManualModel) onDecisionTaken;

  const StudentVerificationView({
    Key? key,
    required this.estudiante,
    required this.guardiaId,
    required this.guardiaNombre,
    required this.puntoControl,
    required this.tipoAcceso,
    required this.onDecisionTaken,
  }) : super(key: key);

  @override
  State<StudentVerificationView> createState() =>
      _StudentVerificationViewState();
}

class _StudentVerificationViewState extends State<StudentVerificationView>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  bool _isProcessing = false;
  final TextEditingController _razonController = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _colorAnimation = ColorTween(
      begin: Colors.grey[100],
      end: Colors.white,
    ).animate(_animationController);

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _razonController.dispose();
    super.dispose();
  }

  Future<void> _tomarDecision(bool autorizado) async {
    if (_isProcessing) return;

    String razon = '';
    if (!autorizado) {
      // Mostrar dialog para ingresar razón
      razon = await _mostrarDialogRazon() ?? '';
      if (razon.isEmpty) return;
    }

    setState(() => _isProcessing = true);

    try {
      final decision = DecisionManualModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        estudianteId: widget.estudiante.id,
        estudianteDni: widget.estudiante.dni,
        estudianteNombre: widget.estudiante.nombreCompleto,
        guardiaId: widget.guardiaId,
        guardiaNombre: widget.guardiaNombre,
        autorizado: autorizado,
        razon: razon.isNotEmpty ? razon : 'Autorización normal',
        timestamp: DateTime.now(),
        puntoControl: widget.puntoControl,
        tipoAcceso: widget.tipoAcceso,
        datosEstudiante: widget.estudiante.toJson(),
      );

      // Registrar decisión en backend
      await _apiService.registrarDecisionManual(decision);

      // Llamar callback
      widget.onDecisionTaken(decision);

      // Mostrar confirmación
      _mostrarConfirmacion(autorizado);
    } catch (e) {
      _mostrarError('Error al registrar decisión: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<String?> _mostrarDialogRazon() async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange[700]),
              const SizedBox(width: 8),
              Text(
                'Razón del rechazo',
                style: GoogleFonts.lato(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '¿Por qué denegar el acceso a ${widget.estudiante.nombreCompleto}?',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _razonController,
                decoration: const InputDecoration(
                  hintText: 'Ingrese la razón...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed:
                  () => Navigator.pop(context, _razonController.text.trim()),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                'Denegar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _mostrarConfirmacion(bool autorizado) {
    final color = autorizado ? Colors.green : Colors.red;
    final icono = autorizado ? Icons.check_circle : Icons.cancel;
    final mensaje = autorizado ? 'ACCESO AUTORIZADO' : 'ACCESO DENEGADO';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icono, size: 64, color: color),
                const SizedBox(height: 16),
                Text(
                  mensaje,
                  style: GoogleFonts.lato(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 8),
                Text(widget.estudiante.nombreCompleto),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Cerrar diálogo
                  Navigator.pop(context); // Volver a scanner
                },
                child: const Text('Continuar'),
              ),
            ],
          ),
    );
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Verificación de Estudiante',
          style: GoogleFonts.lato(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              decoration: BoxDecoration(color: _colorAnimation.value),
              child: _buildContent(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header con tipo de acceso
          _buildHeader(),
          const SizedBox(height: 20),

          // Tarjeta principal del estudiante
          _buildStudentCard(),
          const SizedBox(height: 20),

          // Información adicional
          _buildAdditionalInfo(),
          const SizedBox(height: 30),

          // Botones de acción
          _buildActionButtons(),

          const SizedBox(height: 20),

          // Info del guardia y punto de control
          _buildControlInfo(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final isEntrada = widget.tipoAcceso == 'entrada';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isEntrada ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEntrada ? Colors.green[300]! : Colors.orange[300]!,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isEntrada ? Icons.login : Icons.logout,
            size: 32,
            color: isEntrada ? Colors.green[700] : Colors.orange[700],
          ),
          const SizedBox(width: 12),
          Text(
            isEntrada ? 'SOLICITUD DE ENTRADA' : 'SOLICITUD DE SALIDA',
            style: GoogleFonts.lato(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isEntrada ? Colors.green[700] : Colors.orange[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Foto placeholder y estado
            Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.indigo[100],
                  child: Icon(
                    Icons.person,
                    size: 50,
                    color: Colors.indigo[700],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.estudiante.nombreCompleto,
                        style: GoogleFonts.lato(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            widget.estudiante.isActive
                                ? Icons.check_circle
                                : Icons.cancel,
                            size: 16,
                            color:
                                widget.estudiante.isActive
                                    ? Colors.green
                                    : Colors.red,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.estudiante.isActive ? 'ACTIVO' : 'INACTIVO',
                            style: GoogleFonts.lato(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color:
                                  widget.estudiante.isActive
                                      ? Colors.green
                                      : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Información del estudiante
            _buildInfoRow('DNI:', widget.estudiante.dni),
            _buildInfoRow('Código:', widget.estudiante.codigoUniversitario),
            _buildInfoRow('Facultad:', widget.estudiante.facultad),
            _buildInfoRow('Escuela:', widget.estudiante.escuelaProfesional),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: GoogleFonts.lato(
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.lato(fontSize: 16, color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalInfo() {
    if (!widget.estudiante.isActive) {
      return Card(
        color: Colors.red[50],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.warning, color: Colors.red[700]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ATENCIÓN: Este estudiante está marcado como INACTIVO en el sistema.',
                  style: GoogleFonts.lato(
                    color: Colors.red[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Container();
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isProcessing ? null : () => _tomarDecision(false),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
            icon:
                _isProcessing
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.cancel, size: 24),
            label: Text(
              'DENEGAR',
              style: GoogleFonts.lato(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isProcessing ? null : () => _tomarDecision(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
            icon:
                _isProcessing
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.check_circle, size: 24),
            label: Text(
              'AUTORIZAR',
              style: GoogleFonts.lato(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControlInfo() {
    return Card(
      color: Colors.grey[100],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.person_outline, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text('Guardia: ${widget.guardiaNombre}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text('Punto de Control: ${widget.puntoControl}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  'Hora: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
