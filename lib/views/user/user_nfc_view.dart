import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/nfc_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/status_widgets.dart';
import '../login_view.dart';
import '../student_verification_view.dart';
import '../admin/presencia_dashboard_view.dart';
import '../student_status_view.dart';

class UserNfcView extends StatefulWidget {
  @override
  _UserNfcViewState createState() => _UserNfcViewState();
}

class _UserNfcViewState extends State<UserNfcView> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkNfcAvailability();
    _configurarGuardia();
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Detener cualquier escaneo en curso
    final nfcViewModel = Provider.of<NfcViewModel>(context, listen: false);
    nfcViewModel.stopNfcScan();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // Detener escaneo cuando la app pasa a segundo plano
      final nfcViewModel = Provider.of<NfcViewModel>(context, listen: false);
      nfcViewModel.stopNfcScan();
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
      builder:
          (context) => AlertDialog(
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
      builder:
          (context) => AlertDialog(
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
                itemBuilder:
                    (context) => [
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
      body: Consumer<NfcViewModel>(
        builder: (context, nfcViewModel, child) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Estado del escaneo
                  _buildScanStatus(nfcViewModel),

                  SizedBox(height: 32),

                  // Información del estudiante escaneado
                  if (nfcViewModel.scannedAlumno != null)
                    _buildStudentInfo(nfcViewModel),

                  SizedBox(height: 32),

                  // Botones de acción
                  _buildActionButtons(nfcViewModel),

                  SizedBox(height: 32),

                  // Instrucciones
                  _buildInstructions(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildScanStatus(NfcViewModel nfcViewModel) {
    if (nfcViewModel.isScanning) {
      return LoadingWidget(
        message: 'Acerque la pulsera al dispositivo...',
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

  Widget _buildStudentInfo(NfcViewModel nfcViewModel) {
    final alumno = nfcViewModel.scannedAlumno!;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Información del Estudiante',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 12),
          _buildInfoRow('Nombre', alumno.nombreCompleto),
          _buildInfoRow('Código', alumno.codigoUniversitario),
          _buildInfoRow(
            'Facultad',
            '${alumno.facultad} (${alumno.siglasFacultad})',
          ),
          _buildInfoRow(
            'Escuela',
            '${alumno.escuelaProfesional} (${alumno.siglasEscuela})',
          ),
          _buildInfoRow('Estado', alumno.isActive ? 'Activo' : 'Inactivo'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.grey[800])),
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
              nfcViewModel.stopNfcScan();
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
        
        // Botón de consulta de estado del estudiante
        SizedBox(height: 12),
        CustomButton(
          text: 'Consultar Estado Estudiante',
          icon: Icons.search,
          width: double.infinity,
          backgroundColor: Colors.purple,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StudentStatusView(),
              ),
            );
          },
        ),

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
        builder:
            (context) => StudentVerificationView(
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
        builder:
            (context) => PresenciaDashboardView(
              guardiaId: nfcViewModel.guardiaId!,
              guardiaNombre: nfcViewModel.guardiaNombre ?? 'Guardia',
            ),
      ),
    );
  }
}
