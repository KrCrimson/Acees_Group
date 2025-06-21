import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class VisitorFormScreen extends StatefulWidget {
  final String dni;
  final String guardName;
  final String assignedDoor;

  const VisitorFormScreen({
    Key? key,
    required this.dni,
    required this.guardName,
    required this.assignedDoor,
  }) : super(key: key);

  @override
  State<VisitorFormScreen> createState() => _VisitorFormScreenState();
}

class _VisitorFormScreenState extends State<VisitorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _reasonController = TextEditingController();
  String? _selectedFaculty;

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final now = DateTime.now();
      final visitorData = {
        'dni': widget.dni,
        'nombre': _nameController.text.trim(),
        'asunto': _reasonController.text.trim(),
        'facultad': _selectedFaculty,
        'fecha_hora': Timestamp.fromDate(now),
        'guardia_nombre': widget.guardName,
        'puerta': widget.assignedDoor,
      };

      try {
        // Guardar los datos del visitante en la colección 'visitas'
        await FirebaseFirestore.instance.collection('visitas').add(visitorData);

        // Guardar los datos del externo en la colección 'externos'
        await FirebaseFirestore.instance.collection('externos').add({
          'dni': widget.dni,
          'nombre': _nameController.text.trim(),
        });

        // Notificar a los guardias de la facultad seleccionada
        if (_selectedFaculty != null) {
          final guardsSnapshot = await FirebaseFirestore.instance
              .collection('usuarios')
              .where('rango', isEqualTo: 'guardia')
              .where('puerta_acargo', isEqualTo: _selectedFaculty)
              .get();

          for (var guard in guardsSnapshot.docs) {
            await FirebaseFirestore.instance.collection('notificaciones').add({
              'guardia_uid': guard.id,
              'mensaje': 'Un externo irá a la facultad $_selectedFaculty.',
              'info': visitorData,
              'fecha_hora': Timestamp.fromDate(now),
            });
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Visita registrada exitosamente')),
        );
        Navigator.of(context).pop();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al registrar visita: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Formulario de Visita'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DNI: ${widget.dni}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del visitante',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Ingrese el nombre' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Asunto de la visita',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Ingrese el asunto' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Facultad a visitar',
                  border: OutlineInputBorder(),
                ),
                value: _selectedFaculty,
                items: const [
                  DropdownMenuItem(value: 'FAING', child: Text('FAING')),
                  DropdownMenuItem(value: 'FACSA', child: Text('FACSA')),
                  DropdownMenuItem(value: 'FACEM', child: Text('FACEM')),
                  DropdownMenuItem(value: 'FAEDCOH', child: Text('FAEDCOH')),
                  DropdownMenuItem(value: 'FADE', child: Text('FADE')),
                  DropdownMenuItem(value: 'FAU', child: Text('FAU')),
                ],
                onChanged: (value) => setState(() => _selectedFaculty = value),
                validator: (value) =>
                    value == null ? 'Seleccione una facultad' : null,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _submitForm,
                child: const Text('Registrar Visita'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
