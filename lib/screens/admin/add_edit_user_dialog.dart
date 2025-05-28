import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  String? _selectedPuerta;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.user != null;
    if (_isEditing) {
      _nombreController.text = widget.user!['nombre'] ?? '';
      _apellidoController.text = widget.user!['apellido'] ?? '';
      _dniController.text = widget.user!['dni'] ?? '';
      _emailController.text = widget.user!['email'] ?? '';
      _selectedPuerta = widget.user!['puerta_acargo'];

      // Ensure _selectedPuerta matches a valid DropdownMenuItem value
      if (_selectedPuerta != null &&
          !['faing', 'facsa', 'facem', 'faedcoh'].contains(_selectedPuerta)) {
        _selectedPuerta = null; // Set to null if it's an invalid value
      }
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _dniController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<bool> _isDoorAssignmentValid(String puerta, String? userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('usuarios')
        .where('rango', isEqualTo: 'guardia')
        .where('puerta_acargo', isEqualTo: puerta)
        .get();

    final count = snapshot.docs.where((doc) => doc.id != userId).length;
    return count < 3;
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final nombre = _nombreController.text.trim();
      final apellido = _apellidoController.text.trim();
      final dni = _dniController.text.trim();
      final email = _emailController.text.trim();

      if (_selectedPuerta == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, seleccione una puerta.')),
        );
        return;
      }

      final isValidAssignment = await _isDoorAssignmentValid(
          _selectedPuerta!, widget.user?.id);

      if (!isValidAssignment) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Máximo 3 guardias por puerta permitidos.')),
        );
        return;
      }

      try {
        final userData = {
          'nombre': nombre,
          'apellido': apellido,
          'dni': dni,
          'email': email,
          'rango': widget.userRole,
          'puerta_acargo': _selectedPuerta,
        };

        if (_isEditing) {
          await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(widget.user!.id)
              .update(userData);
        } else {
          await FirebaseFirestore.instance.collection('usuarios').add(userData);
        }

        Navigator.of(context).pop();
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
      title: Text(_isEditing ? 'Editar ${widget.userRole}' : 'Agregar ${widget.userRole}'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Ingrese un nombre' : null,
              ),
              TextFormField(
                controller: _apellidoController,
                decoration: const InputDecoration(labelText: 'Apellido'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Ingrese un apellido' : null,
              ),
              TextFormField(
                controller: _dniController,
                decoration: const InputDecoration(labelText: 'DNI'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Ingrese un DNI' : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Ingrese un Email' : null,
              ),
              if (widget.userRole == 'guardia')
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Puerta a Cargo'),
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
                  validator: (value) => null, // Allow null values
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