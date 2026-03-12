import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import '../../viewmodels/nfc_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../services/session_guard_service.dart';
import '../../services/photo_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/status_widgets.dart';
import '../../widgets/session_status_widget.dart';
import '../../widgets/connectivity_status_widget.dart';
import '../../widgets/conflict_alert_widget.dart';

import '../login_view.dart';
import '../student_verification_view.dart';
import '../admin/presencia_dashboard_view.dart';
import '../admin/registro_visita_view.dart';

class UserNfcView extends StatefulWidget {
  @override
  _UserNfcViewState createState() => _UserNfcViewState();
}

class _UserNfcViewState extends State<UserNfcView> with WidgetsBindingObserver {
  final SessionGuardService _sessionGuardService = SessionGuardService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkNfcAvailability();
    _configurarGuardia();
    _iniciarSesionGuardia();

    // Escuchar cambios en la sesión
    _sessionGuardService.addListener(_onSessionChanged);

    // Agregar log inicial
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nfcViewModel = Provider.of<NfcViewModel>(context, listen: false);
      nfcViewModel.addLog('🚀 Sistema de logs iniciado');
      nfcViewModel.addLog('📱 App de Control de Acceso NFC cargada');
    });
  }

  Future<void> _configurarGuardia() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final nfcViewModel = Provider.of<NfcViewModel>(context, listen: false);

    if (authViewModel.currentUser != null) {
      nfcViewModel.configurarGuardia(
        authViewModel.currentUser!.id,
        authViewModel.currentUser!.nombreCompleto,
        authViewModel.currentUser!.puertaACargo ?? 'Principal',
      );
    }
  }

  Future<void> _iniciarSesionGuardia() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);

    if (authViewModel.currentUser != null) {
      final resultado = await _sessionGuardService.iniciarSesion(
        guardiaId: authViewModel.currentUser!.id,
        guardiaNombre: authViewModel.currentUser!.nombreCompleto,
        puntoControl: authViewModel.currentUser!.puertaACargo ?? 'Principal',
      );

      if (!resultado.success) {
        debugPrint(
            '⚠️ Error al iniciar sesión de guardia: ${resultado.message}');
      } else {
        debugPrint('✅ Sesión de guardia iniciada correctamente');
      }
    }
  }

  void _onSessionChanged() {
    // Si la sesión ya no está activa, cerrar la app del guardia
    if (!_sessionGuardService.isSessionActive && mounted) {
      _cerrarSesionPorAdmin();
    }
  }

  void _cerrarSesionPorAdmin() {
    // Cuando es cierre forzado por admin, NO mostrar diálogo de confirmación
    // Cerrar directamente y mostrar solo una notificación breve
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Sesión Finalizada'),
          ],
        ),
        content: Text(
          'Su sesión ha sido finalizada por un administrador. La aplicación se cerrará automáticamente.',
        ),
        // NO botones - se cierra automáticamente
      ),
    );

    // Cerrar automáticamente después de 2 segundos
    Future.delayed(Duration(seconds: 2), () {
      if (mounted) {
        // Cerrar el diálogo
        Navigator.of(context).pop();
        
        // Realizar logout directo sin confirmación adicional
        final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
        authViewModel.logout();
        
        // Navegar al login
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginView()),
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionGuardService.removeListener(_onSessionChanged);
    // Detener cualquier escaneo en curso
    final nfcViewModel = Provider.of<NfcViewModel>(context, listen: false);
    nfcViewModel.stopNfcScan();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final nfcViewModel = Provider.of<NfcViewModel>(context, listen: false);

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // Detener escaneo cuando la app pasa a segundo plano
      nfcViewModel.stopNfcScan();
    } else if (state == AppLifecycleState.resumed) {
      // Cuando la app se reactiva, intentar leer NFC inmediatamente
      print('📱 App reactivada, intentando leer NFC...');
      Future.delayed(Duration(milliseconds: 500), () {
        nfcViewModel.readNfcImmediately();
      });
    }
  }

  Future<void> _checkNfcAvailability() async {
    final nfcViewModel = Provider.of<NfcViewModel>(context, listen: false);
    bool available = await nfcViewModel.checkNfcAvailability();

    if (!available && mounted) {
      _showNfcNotAvailableDialog();
    }
  }

  void _showNfcNotAvailableDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('NFC No Disponible'),
        content: Text(
          'Este dispositivo no tiene NFC disponible o está desactivado. '
          'Por favor active el NFC en la configuración del dispositivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cerrar Sesión'),
        content: Text('¿Está seguro de que desea cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              final authViewModel = Provider.of<AuthViewModel>(
                context,
                listen: false,
              );
              authViewModel.logout();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => LoginView()),
              );
            },
            child: Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Control de Acceso NFC'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          Consumer<AuthViewModel>(
            builder: (context, authViewModel, child) {
              return PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'logout') {
                    _handleLogout();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'profile',
                    child: ListTile(
                      leading: Icon(Icons.person),
                      title: Text('Usuario'),
                      subtitle: Text(
                        authViewModel.currentUser?.nombreCompleto ?? '',
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'logout',
                    child: ListTile(
                      leading: Icon(Icons.logout, color: Colors.red),
                      title: Text(
                        'Cerrar Sesión',
                        style: TextStyle(color: Colors.red),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: ConnectivityStatusWidget(
        child: Consumer<NfcViewModel>(
          builder: (context, nfcViewModel, child) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Estado de sesión del guardia
                    Consumer<AuthViewModel>(
                      builder: (context, authViewModel, child) {
                        return SessionStatusWidget(
                          guardiaId: authViewModel.currentUser?.id,
                          guardiaNombre:
                              authViewModel.currentUser?.nombreCompleto,
                          puntoControl:
                              authViewModel.currentUser?.puertaACargo ??
                                  'Principal',
                        );
                      },
                    ),

                    SizedBox(height: 8),

                    // Widget de alerta de conflictos
                    ConflictAlertWidget(),

                    SizedBox(height: 16),

                    // Estado del escaneo
                    _buildScanStatus(nfcViewModel),

                    SizedBox(height: 32),

                    // Mensaje de estado del alumno (ENTRADA/SALIDA) - PERSISTENTE
                    if (nfcViewModel.scannedAlumno != null)
                      _buildStudentStatusMessage(nfcViewModel),

                    SizedBox(height: 16),

                    // Botones de acción
                    _buildActionButtons(nfcViewModel),

                    SizedBox(height: 24),

                    // Sección de logs en tiempo real - DESHABILITADA POR SEGURIDAD
                    // _buildDebugLogsSection(nfcViewModel),

                    SizedBox(height: 32),

                    // Instrucciones
                    _buildInstructions(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildScanStatus(NfcViewModel nfcViewModel) {
    if (nfcViewModel.isScanning) {
      return LoadingWidget(
        message:
            '� ESCÁNER ACTIVO\n📱 Acerque las pulseras una tras otra...\n� Presione "Detener" para finalizar',
        size: 60,
      );
    }

    if (nfcViewModel.errorMessage != null) {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red[200]!),
        ),
        child: Column(
          children: [
            Icon(Icons.error_outline, color: Colors.red[600], size: 48),
            SizedBox(height: 12),
            Text(
              nfcViewModel.errorMessage!,
              style: TextStyle(
                color: Colors.red[700],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (nfcViewModel.successMessage != null) {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green[200]!),
        ),
        child: Column(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: Colors.green[600],
              size: 48,
            ),
            SizedBox(height: 12),
            Text(
              nfcViewModel.successMessage!,
              style: TextStyle(
                color: Colors.green[700],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        children: [
          Icon(Icons.nfc, color: Colors.blue[600], size: 64),
          SizedBox(height: 16),
          Text(
            'Listo para escanear',
            style: TextStyle(
              color: Colors.blue[700],
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Presione el botón para iniciar el escaneo NFC',
            style: TextStyle(color: Colors.blue[600], fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(NfcViewModel nfcViewModel) {
    return Column(
      children: [
        CustomButton(
          text:
              nfcViewModel.isScanning ? 'Detener Escaneo' : 'Escanear Pulsera',
          icon: nfcViewModel.isScanning ? Icons.stop : Icons.nfc,
          width: double.infinity,
          isLoading: nfcViewModel.isLoading,
          backgroundColor: nfcViewModel.isScanning ? Colors.red : null,
          onPressed: () {
            if (nfcViewModel.isScanning) {
              _showStopScannerDialog(nfcViewModel);
            } else {
              nfcViewModel.startNfcScan();
            }
          },
        ),

        // Botón de verificación manual si hay estudiante que requiere autorización
        if (nfcViewModel.scannedAlumno != null &&
            nfcViewModel.errorMessage != null &&
            nfcViewModel.errorMessage!.contains(
              'Requiere autorización manual',
            )) ...[
          SizedBox(height: 12),
          CustomButton(
            text: 'Verificación Manual',
            icon: Icons.person_search,
            width: double.infinity,
            backgroundColor: Colors.orange,
            onPressed: () => _mostrarVerificacionManual(nfcViewModel),
          ),
        ],

        // Botón de Dashboard de Presencia
        if (nfcViewModel.guardiaId != null) ...[
          SizedBox(height: 12),
          CustomButton(
            text: 'Control de Presencia',
            icon: Icons.dashboard,
            width: double.infinity,
            backgroundColor: Colors.indigo,
            onPressed: () => _mostrarDashboardPresencia(nfcViewModel),
          ),
        ],

        // Botón de Registro Visita Externa
        if (nfcViewModel.guardiaId != null) ...[
          SizedBox(height: 12),
          CustomButton(
            text: 'Registrar Visita Externa',
            icon: Icons.person_add_alt_1,
            width: double.infinity,
            backgroundColor: Colors.teal[700],
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RegistroVisitaView(),
                ),
              );
            },
          ),
        ],

        if (nfcViewModel.scannedAlumno != null ||
            nfcViewModel.errorMessage != null) ...[
          SizedBox(height: 12),
          CustomButton(
            text: 'Limpiar',
            icon: Icons.clear,
            width: double.infinity,
            backgroundColor: Colors.grey[600],
            onPressed: nfcViewModel.clearScan,
          ),
        ],
      ],
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
              SizedBox(width: 8),
              Text(
                'Instrucciones',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '1. Presione "Escanear Pulsera" para activar NFC\n'
            '2. Acerque la pulsera del estudiante al dispositivo\n'
            '3. El sistema validará automáticamente el acceso\n'
            '4. Se registrará la asistencia si es válida',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // Métodos para las nuevas funcionalidades US022-US030
  void _mostrarVerificacionManual(NfcViewModel nfcViewModel) async {
    if (nfcViewModel.scannedAlumno == null || nfcViewModel.guardiaId == null)
      return;

    // Determinar tipo de acceso primero
    final tipoAcceso = await nfcViewModel.determinarTipoAccesoInteligente(
      nfcViewModel.scannedAlumno!.dni,
    );

    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => StudentVerificationView(
          estudiante: nfcViewModel.scannedAlumno!,
          guardiaId: nfcViewModel.guardiaId!,
          guardiaNombre: nfcViewModel.guardiaNombre ?? 'Guardia',
          puntoControl: nfcViewModel.puntoControl ?? 'Principal',
          tipoAcceso: tipoAcceso,
          onDecisionTaken: (decision) {
            nfcViewModel.onDecisionManualTomada(decision);
          },
        ),
      ),
    );

    // Si se regresó de la verificación, limpiar el scan
    if (resultado == true) {
      nfcViewModel.clearScan();
    }
  }

  void _mostrarDashboardPresencia(NfcViewModel nfcViewModel) {
    if (nfcViewModel.guardiaId == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PresenciaDashboardView(
          guardiaId: nfcViewModel.guardiaId!,
          guardiaNombre: nfcViewModel.guardiaNombre ?? 'Guardia',
        ),
      ),
    );
  }

  // Widget para mostrar el mensaje de estado del alumno (ENTRADA/SALIDA)
  Widget _buildStudentStatusMessage(NfcViewModel nfcViewModel) {
    final alumno = nfcViewModel.scannedAlumno!;
    final lastAccessType = nfcViewModel.lastAccessType ?? 'entrada';

    // Determinar el tipo de acceso basándose en el tipo registrado
    bool isEntrada = lastAccessType == 'entrada';

    String tipoAcceso = 'ACCESO';
    Color backgroundColor = Colors.blue[50]!;
    Color borderColor = Colors.blue[200]!;
    Color textColor = Colors.blue[700]!;
    IconData iconData = Icons.person;

    if (isEntrada) {
      tipoAcceso = 'ENTRADA';
      backgroundColor = Colors.green[50]!;
      borderColor = Colors.green[200]!;
      textColor = Colors.green[700]!;
      iconData = Icons.login;
    } else {
      tipoAcceso = 'SALIDA';
      backgroundColor = Colors.red[50]!;
      borderColor = Colors.red[200]!;
      textColor = Colors.red[700]!;
      iconData = Icons.logout;
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Título del tipo de acceso
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(iconData, color: textColor, size: 28),
              SizedBox(width: 8),
              Text(
                tipoAcceso,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),

          SizedBox(height: 12),

          // Datos principales del alumno
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Foto del alumno centrada
                Center(
                  child: Container(
                    height: 100,
                    width: 100,
                    margin: EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: PhotoService.getAlumnoPhotoUrl(alumno.id),
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color.fromARGB(255, 11, 102, 35),
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) {
                          print(
                              '❌ Error cargando foto para DNI ${alumno.dni}: $error');
                          print('🔗 URL intentada: $url');
                          return Container(
                            color: const Color.fromARGB(255, 11, 102, 35),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  alumno.nombreCompleto.isNotEmpty
                                      ? alumno.nombreCompleto[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Sin foto',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                _buildStatusInfoRow(
                    'Nombre:', alumno.nombreCompleto, Icons.person),
                _buildStatusInfoRow(
                    'Código:', alumno.codigoUniversitario, Icons.badge),
                _buildStatusInfoRow(
                    'Facultad:',
                    '${alumno.facultad} (${alumno.siglasFacultad})',
                    Icons.school),
                _buildStatusInfoRow(
                    'Escuela:',
                    '${alumno.escuelaProfesional} (${alumno.siglasEscuela})',
                    Icons.class_),
                _buildStatusInfoRow(
                    'Hora:', _formatCurrentTime(), Icons.access_time),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrentTime() {
    final now = DateTime.now();
    return '${now.day}/${now.month}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  // Widget para mostrar logs de debugging en tiempo real - DESHABILITADO POR SEGURIDAD
  /*
  Widget _buildDebugLogsSection(NfcViewModel nfcViewModel) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera del panel de logs
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.bug_report, color: Colors.green[400], size: 20),
                SizedBox(width: 8),
                Text(
                  'LOGS DE DEBUGGING',
                  style: TextStyle(
                    color: Colors.green[400],
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
                Spacer(),
                GestureDetector(
                  onTap: () => nfcViewModel.clearLogs(),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red[700],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'LIMPIAR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Contenido de los logs
          Container(
            height: 200,
            padding: EdgeInsets.all(12),
            child: nfcViewModel.debugLogs.isEmpty
                ? Center(
                    child: Text(
                      'No hay logs aún...\nInicia un escaneo para ver los logs aquí.',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    reverse: false, // Los logs más recientes arriba
                    itemCount: nfcViewModel.debugLogs.length,
                    itemBuilder: (context, index) {
                      final log = nfcViewModel.debugLogs[index];
                      Color logColor = Colors.grey[300]!;

                      // Colorear logs según su tipo
                      if (log.contains('❌') || log.contains('ERROR')) {
                        logColor = Colors.red[400]!;
                      } else if (log.contains('✅') ||
                          log.contains('COMPLETADO')) {
                        logColor = Colors.green[400]!;
                      } else if (log.contains('🔍') || log.contains('📤')) {
                        logColor = Colors.blue[400]!;
                      } else if (log.contains('⚠️')) {
                        logColor = Colors.orange[400]!;
                      }

                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 1),
                        child: Text(
                          log,
                          style: TextStyle(
                            color: logColor,
                            fontSize: 11,
                            fontFamily: 'monospace',
                            height: 1.2,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
  */

  // Diálogo de confirmación para detener el escáner
  void _showStopScannerDialog(NfcViewModel nfcViewModel) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('Detener Escáner'),
            ],
          ),
          content: Text(
            '¿Está seguro de que desea detener el escáner NFC?\n\n'
            'Se interrumpirá la lectura continua de pulseras.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                nfcViewModel.stopNfcScan();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('Detener'),
            ),
          ],
        );
      },
    );
  }
}
