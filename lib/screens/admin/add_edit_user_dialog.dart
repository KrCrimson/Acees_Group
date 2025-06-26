import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddEditUserDialog extends StatefulWidget {
  final DocumentSnapshot? user;
  final String userRole;

  const AddEditUserDialog({Key? key, this.user, required this.userRole})
      : super(key: key);

  @override
  State<AddEditUserDialog> createState() => _AddEditUserDialogState();
}

class _AddEditUserDialogState extends State<AddEditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _dniController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _selectedPuerta;
  String _status = 'activo'; // Default status
  bool _isEditing = false;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _isEditing = true;
      _nombreController.text = widget.user!['nombre'] ?? '';
      _apellidoController.text = widget.user!['apellido'] ?? '';
      _dniController.text = widget.user!['dni'] ?? '';
      _emailController.text = widget.user!['email'] ?? '';
      _selectedPuerta = widget.user!['puerta_acargo'];
      _status = widget.user!['estado'] ?? 'activo';
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _dniController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final nombre = _nombreController.text.trim();
      final apellido = _apellidoController.text.trim();
      final dni = _dniController.text.trim();
      final email = _emailController.text.trim();
      final password = _isEditing ? null : _passwordController.text.trim();

      final userData = {
        'nombre': nombre,
        'apellido': apellido,
        'dni': dni,
        'email': email,
        'rango': widget.userRole,
        'puerta_acargo': _selectedPuerta,
        'estado': _isEditing ? widget.user!['estado'] : _status,
        'fecha_modificacion': Timestamp.now(),
      };

      if (!_isEditing) {
        userData['fecha_creacion'] = Timestamp.now(); // Add creation date only for new users
      }

      try {
        if (_isEditing) {
          await widget.user!.reference.update(userData);
          Navigator.of(context).pop();
        } else {
          // Crear usuario en Firebase Authentication
          final authResult = await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email,
            password: password!,
          );

          // Guardar datos en Firestore usando el UID de Auth como ID
          await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(authResult.user!.uid)
              .set({
                ...userData,
                'auth_uid': authResult.user!.uid,
              });

          // Mostrar la contraseña al admin para que la copie
          if (context.mounted) {
            await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Usuario creado'),
                content: SelectableText('La contraseña del usuario es: $password'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
            // Cerrar el AlertDialog principal después de mostrar la contraseña
            Navigator.of(context).pop();
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
      ),
      title: Text(
        _isEditing ? 'Editar ${widget.userRole}' : 'Agregar ${widget.userRole}',
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          color: Colors.indigo,
        ),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Ingrese un nombre' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _apellidoController,
                decoration: const InputDecoration(
                  labelText: 'Apellido',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Ingrese un apellido' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _dniController,
                decoration: const InputDecoration(
                  labelText: 'DNI',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Ingrese un DNI' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Ingrese un Email' : null,
              ),
              const SizedBox(height: 8),
              if (!_isEditing)
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_showPassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                    ),
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Ingrese una contraseña' : null,
                ),
              if (!_isEditing) const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Estado',
                  border: OutlineInputBorder(),
                ),
                value: _status,
                items: const [
                  DropdownMenuItem(value: 'activo', child: Text('Activo')),
                  DropdownMenuItem(value: 'inactivo', child: Text('Inactivo')),
                ],
                onChanged: (value) => setState(() => _status = value!),
              ),
              const SizedBox(height: 8),
              if (widget.userRole == 'guardia')
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Puerta a Cargo',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedPuerta,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Sin asignar')),
                    DropdownMenuItem(value: 'faing', child: Text('FAING')),
                    DropdownMenuItem(value: 'facsa', child: Text('FACSA')),
                    DropdownMenuItem(value: 'facem', child: Text('FACEM')),
                    DropdownMenuItem(value: 'faedcoh', child: Text('FAEDCOH')),
                    DropdownMenuItem(value: 'fade', child: Text('FADE')),
                    DropdownMenuItem(value: 'fau', child: Text('FAU')),
                  ],
                  onChanged: (value) => setState(() => _selectedPuerta = value),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[700],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
          ),
          onPressed: _submit,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

void showAddEditUserDialog(BuildContext context,
    {DocumentSnapshot? user, required String userRole}) {
  showDialog(
    context: context,
    builder: (context) =>
        AddEditUserDialog(user: user, userRole: userRole),
  );
}