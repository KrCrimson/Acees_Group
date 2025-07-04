import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';

class VisitorFormScreen extends StatefulWidget {
  final String dni;
  final String guardName;
  final String assignedDoor;
  final String? nombre; // <-- Agrega esto

  const VisitorFormScreen({
    Key? key,
    required this.dni,
    required this.guardName,
    required this.assignedDoor,
    this.nombre, // <-- Agrega esto
  }) : super(key: key);

  @override
  State<VisitorFormScreen> createState() => _VisitorFormScreenState();
}

class _VisitorFormScreenState extends State<VisitorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _reasonController = TextEditingController();
  String? _selectedFaculty;
  bool _isLoadingName = false;

  @override
  void initState() {
    super.initState();
    _fetchNameIfNeeded();
  }

  Future<void> _fetchNameIfNeeded() async {
    // Usa el nombre proporcionado si existe
    if (widget.nombre != null && widget.nombre!.isNotEmpty) {
      _nameController.text = widget.nombre!;
      setState(() {});
      return;
    }
    // Verifica si el externo ya está en la BD
    final extSnap = await FirebaseFirestore.instance
        .collection('externos')
        .where('dni', isEqualTo: widget.dni)
        .limit(1)
        .get();
    if (extSnap.docs.isNotEmpty) {
      final nombre = extSnap.docs.first.data()['nombre'] as String?;
      if (nombre != null && nombre.isNotEmpty) {
        _nameController.text = nombre;
        setState(() {});
        return;
      }
    }
    // Si no está, consulta la API externa
    setState(() => _isLoadingName = true);
    try {
      final response = await http.get(
        Uri.parse('https://api.apis.net.pe/v1/dni?numero=${widget.dni}'),
        headers: {'Authorization': 'Bearer apis-token-16172.YnjI01QPbvQ2cuf5U3nsb5qOUgiLZ7tW'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final nombre = data['nombre'] ?? '';
        if (nombre.isNotEmpty) {
          _nameController.text = nombre;
        }
      }
    } catch (_) {}
    setState(() => _isLoadingName = false);
  }

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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.indigo.withOpacity(0.92),
        elevation: 8,
        title: Text(
          'Formulario de Visita',
          style: GoogleFonts.lato(
            textStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF536976),
              Color(0xFF292E49),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Card(
              elevation: 14,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 30),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.indigo,
                        radius: 38,
                        child: const Icon(Icons.person_add_alt_1, color: Colors.white, size: 44),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'DNI: ${widget.dni}',
                        style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo[900]),
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Nombre del visitante',
                          prefixIcon: const Icon(Icons.person, color: Colors.indigo),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          filled: true,
                          fillColor: Colors.indigo.withOpacity(0.06),
                          suffixIcon: _isLoadingName
                              ? const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                )
                              : null,
                        ),
                        validator: (value) => value == null || value.isEmpty ? 'Ingrese el nombre' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _reasonController,
                        decoration: InputDecoration(
                          labelText: 'Asunto de la visita',
                          prefixIcon: const Icon(Icons.edit_note, color: Colors.deepPurple),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          filled: true,
                          fillColor: Colors.deepPurple.withOpacity(0.06),
                        ),
                        validator: (value) => value == null || value.isEmpty ? 'Ingrese el asunto' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Facultad a visitar',
                          prefixIcon: const Icon(Icons.school, color: Colors.teal),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          filled: true,
                          fillColor: Colors.teal.withOpacity(0.06),
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
                        validator: (value) => value == null ? 'Seleccione una facultad' : null,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 6,
                          ),
                          icon: const Icon(Icons.check_circle, color: Colors.white, size: 26),
                          label: Text(
                            'Registrar Visita',
                            style: GoogleFonts.lato(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          onPressed: _submitForm,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
