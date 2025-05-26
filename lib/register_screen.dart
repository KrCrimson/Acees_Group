import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserFormDialog extends StatefulWidget {
  final DocumentSnapshot? user; // Null = modo creación
  final String defaultRole;

  const UserFormDialog({
    super.key,
    this.user,
    required this.defaultRole,
  });

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreController;
  late TextEditingController _apellidoController;
  late TextEditingController _dniController;
  late TextEditingController _emailController;
  late TextEditingController _telefonoController;
  late TextEditingController _passwordController;
  String? _selectedRole;
  String? _selectedEstado;

  @override
  void initState() {
    super.initState();
    // Inicializar controladores con datos existentes (si hay)
    _nombreController = TextEditingController(text: widget.user?['nombre'] ?? '');
    _apellidoController = TextEditingController(text: widget.user?['apellido'] ?? '');
    _dniController = TextEditingController(text: widget.user?['dni'] ?? '');
    _emailController = TextEditingController(text: widget.user?['email'] ?? '');
    _telefonoController = TextEditingController(text: widget.user?['telefono'] ?? '');
    _passwordController = TextEditingController();
    _selectedRole = widget.user?['rango'] ?? widget.defaultRole;
    _selectedEstado = widget.user?['estado'] ?? 'activo';
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _dniController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        final firestore = FirebaseFirestore.instance;
        final userData = {
          'nombre': _nombreController.text.trim(),
          'apellido': _apellidoController.text.trim(),
          'dni': _dniController.text.trim(),
          'email': _emailController.text.trim().toLowerCase(),
          'telefono': _telefonoController.text.trim(),
          'rango': _selectedRole,
          'estado': _selectedEstado,
          'fecha_actualizacion': FieldValue.serverTimestamp(),
        };

        if (widget.user == null) {
          // ========== MODO REGISTRO ==========
          final auth = FirebaseAuth.instance;
          final userCredential = await auth.createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
          
          await firestore.collection('usuarios').doc(userCredential.user?.uid).set({
            ...userData,
            'fecha_creacion': FieldValue.serverTimestamp(),
          });
        } else {
          // ========== MODO EDICIÓN ==========
          await firestore.collection('usuarios').doc(widget.user!.id).update(userData);
          
          // Opcional: Actualizar email en Auth (requiere backend)
          if (widget.user!['email'] != _emailController.text.trim()) {
            debugPrint('Nota: Implementar Cloud Function para actualizar email en Auth');
          }
        }

        if (!mounted) return;
        Navigator.pop(context, true); // Retorna éxito
      } on FirebaseAuthException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.message ?? e.code}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.user != null;

    return AlertDialog(
      title: Text(isEditing ? 'Editar Usuario' : 'Registrar Usuario'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ========== Campos Comunes ==========
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (value) => value!.isEmpty ? 'Campo obligatorio' : null,
              ),
              TextFormField(
                controller: _apellidoController,
                decoration: const InputDecoration(labelText: 'Apellido'),
                validator: (value) => value!.isEmpty ? 'Campo obligatorio' : null,
              ),
              TextFormField(
                controller: _dniController,
                decoration: const InputDecoration(labelText: 'DNI'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value!.isEmpty) return 'Campo obligatorio';
                  if (value.length != 8) return 'DNI debe tener 8 dígitos';
                  return null;
                },
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value!.isEmpty) return 'Campo obligatorio';
                  if (!value.contains('@')) return 'Email inválido';
                  return null;
                },
                readOnly: isEditing, // Evitar edición directa en modo edición
              ),
              TextFormField(
                controller: _telefonoController,
                decoration: const InputDecoration(labelText: 'Teléfono'),
                keyboardType: TextInputType.phone,
              ),

              // ========== Selectores ==========
              DropdownButtonFormField<String>(
                value: _selectedRole,
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text('Administrador')),
                  DropdownMenuItem(value: 'guardia', child: Text('Guardia')),
                ],
                onChanged: isEditing ? null : (value) => setState(() => _selectedRole = value),
                decoration: const InputDecoration(labelText: 'Rol'),
              ),

              if (isEditing)
                DropdownButtonFormField<String>(
                  value: _selectedEstado,
                  items: const [
                    DropdownMenuItem(value: 'activo', child: Text('Activo')),
                    DropdownMenuItem(value: 'inactivo', child: Text('Inactivo')),
                  ],
                  onChanged: (value) => setState(() => _selectedEstado = value),
                  decoration: const InputDecoration(labelText: 'Estado'),
                ),

              // ========== Solo para registro ==========
              if (!isEditing)
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Contraseña'),
                  obscureText: true,
                  validator: (value) {
                    if (value!.isEmpty) return 'Campo obligatorio';
                    if (value.length < 6) return 'Mínimo 6 caracteres';
                    return null;
                  },
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _submitForm,
          child: Text(isEditing ? 'Guardar Cambios' : 'Registrar'),
        ),
      ],
    );
  }
}