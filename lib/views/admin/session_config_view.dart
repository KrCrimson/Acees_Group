import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class SessionConfigView extends StatefulWidget {
  @override
  _SessionConfigViewState createState() => _SessionConfigViewState();
}

class _SessionConfigViewState extends State<SessionConfigView> {
  final _formKey = GlobalKey<FormState>();
  final _timeoutController = TextEditingController();
  final _warningController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  void _loadCurrentConfig() {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final sessionService = authViewModel.sessionService;

    _timeoutController.text = sessionService.sessionTimeoutMinutes.toString();
    _warningController.text = sessionService.warningTimeMinutes.toString();
  }

  @override
  void dispose() {
    _timeoutController.dispose();
    _warningController.dispose();
    super.dispose();
  }

  void _saveConfiguration() async {
    if (!_formKey.currentState!.validate()) return;

    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);

    final timeoutMinutes = int.parse(_timeoutController.text);
    final warningMinutes = int.parse(_warningController.text);

    final success = await authViewModel.configureSessionTimeout(
      timeoutMinutes,
      warningMinutes,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Configuración de sesión actualizada'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al guardar configuración'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Configuración de Sesión'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Consumer<AuthViewModel>(
        builder: (context, authViewModel, child) {
          if (!authViewModel.isAdmin) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Acceso denegado',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text('Solo administradores pueden acceder'),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Información actual
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue),
                              SizedBox(width: 8),
                              Text(
                                'Configuración Actual',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Tiempo de sesión: ${authViewModel.sessionService.sessionTimeoutMinutes} minutos',
                          ),
                          Text(
                            'Advertencia previa: ${authViewModel.sessionService.warningTimeMinutes} minutos',
                          ),
                          if (authViewModel.sessionService.hasActiveSession)
                            Text(
                              '🟢 Sesión activa',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          else
                            Text(
                              '🔴 Sin sesión activa',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),

                  // Formulario de configuración
                  Text(
                    'Nueva Configuración',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),

                  CustomTextField(
                    label: 'Tiempo de sesión (minutos)',
                    hint: 'Ejemplo: 30',
                    controller: _timeoutController,
                    keyboardType: TextInputType.number,
                    prefixIcon: Icons.timer,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingrese el tiempo de sesión';
                      }
                      final minutes = int.tryParse(value);
                      if (minutes == null || minutes < 5 || minutes > 480) {
                        return 'Ingrese un valor entre 5 y 480 minutos';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),

                  CustomTextField(
                    label: 'Advertencia previa (minutos)',
                    hint: 'Ejemplo: 5',
                    controller: _warningController,
                    keyboardType: TextInputType.number,
                    prefixIcon: Icons.warning,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingrese el tiempo de advertencia';
                      }
                      final warningMinutes = int.tryParse(value);
                      final timeoutMinutes = int.tryParse(
                        _timeoutController.text,
                      );

                      if (warningMinutes == null || warningMinutes < 1) {
                        return 'Ingrese un valor mayor a 0';
                      }

                      if (timeoutMinutes != null &&
                          warningMinutes >= timeoutMinutes) {
                        return 'La advertencia debe ser menor al tiempo total';
                      }

                      return null;
                    },
                  ),
                  SizedBox(height: 24),

                  // Información de ayuda
                  Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.help_outline, color: Colors.blue),
                              SizedBox(width: 8),
                              Text(
                                'Información',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            '• El tiempo de sesión define cuándo se cierra automáticamente',
                          ),
                          Text(
                            '• La advertencia previa notifica al usuario antes del cierre',
                          ),
                          Text(
                            '• Valores recomendados: 30 min sesión, 5 min advertencia',
                          ),
                          Text(
                            '• La configuración se aplica a todas las nuevas sesiones',
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 32),

                  // Botones de acción
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 15),
                            side: BorderSide(
                              color: Theme.of(context).primaryColor,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Cancelar',
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: CustomButton(
                          text: 'Guardar',
                          onPressed:
                              authViewModel.isLoading
                                  ? null
                                  : _saveConfiguration,
                          isLoading: authViewModel.isLoading,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
