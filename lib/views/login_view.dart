import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_button.dart';
import 'admin/admin_view.dart';
import 'user/user_nfc_view.dart';

class LoginView extends StatefulWidget {
  @override
  _LoginViewState createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);

    bool success = await authViewModel.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (success && mounted) {
      // Navegar según el rol del usuario
      if (authViewModel.isAdmin) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => AdminView()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => UserNfcView()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Consumer<AuthViewModel>(
          builder: (context, authViewModel, child) {
            return SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: 60),

                    // Logo y título
                    Icon(
                      Icons.nfc,
                      size: 80,
                      color: Theme.of(context).primaryColor,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Control de Acceso NFC',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Sistema de control de asistencias',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 48),

                    // Formulario de login
                    CustomTextField(
                      label: 'Email',
                      hint: 'Ingrese su email',
                      controller: _emailController,
                      isEmail: true,
                      prefixIcon: Icons.email_outlined,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingrese su email';
                        }
                        if (!RegExp(
                          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                        ).hasMatch(value)) {
                          return 'Por favor ingrese un email válido';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),

                    CustomTextField(
                      label: 'Contraseña',
                      hint: 'Ingrese su contraseña',
                      controller: _passwordController,
                      isPassword: !_showPassword,
                      prefixIcon: Icons.lock_outline,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed:
                            () =>
                                setState(() => _showPassword = !_showPassword),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingrese su contraseña';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 24),

                    // Mensaje de error
                    if (authViewModel.errorMessage != null)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12),
                        margin: EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          border: Border.all(color: Colors.red[200]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red[600],
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                authViewModel.errorMessage!,
                                style: TextStyle(color: Colors.red[700]),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Botón de login
                    CustomButton(
                      text: 'Iniciar Sesión',
                      width: double.infinity,
                      isLoading: authViewModel.isLoading,
                      icon: Icons.login,
                      onPressed: _handleLogin,
                    ),
                    SizedBox(height: 32),

                    // Información adicional
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue[600]),
                          SizedBox(height: 8),
                          Text(
                            'Sistema de Control de Acceso',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Use sus credenciales para acceder al sistema',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
