import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentRegisterScreen extends StatefulWidget {
  const StudentRegisterScreen({super.key});

  @override
  State<StudentRegisterScreen> createState() => _StudentRegisterScreenState();
}

class _StudentRegisterScreenState extends State<StudentRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  String? dni, codigo, nombre, apellido, escuela, facultad, siglaEscuela, siglaFacultad;
  List<Map<String, dynamic>> facultades = [];
  List<Map<String, dynamic>> escuelas = [];
  List<Map<String, dynamic>> escuelasFiltradas = [];

  @override
  void initState() {
    super.initState();
    _loadFacultades();
    _loadEscuelas();
  }

  Future<void> _loadFacultades() async {
    // Cargar desde la colección 'facultades'
    final snap = await FirebaseFirestore.instance.collection('facultades').get();
    setState(() {
      facultades = snap.docs.map((d) => d.data()).toList();
    });
  }

  Future<void> _loadEscuelas() async {
    // Cargar desde la colección 'escuelas'
    final snap = await FirebaseFirestore.instance.collection('escuelas').get();
    setState(() {
      escuelas = snap.docs.map((d) => d.data()).toList();
    });
  }

  void _onFacultadChanged(String? value) {
    facultad = value;
    // Buscar la sigla de la facultad seleccionada
    siglaFacultad = facultades.firstWhere(
      (f) => f['nombre'] == value,
      orElse: () => {},
    )['siglas'];
    // Filtrar escuelas por siglas_facultad que coincida con la sigla de la facultad seleccionada
    escuelasFiltradas = escuelas.where(
      (e) => e['siglas_facultad'] == siglaFacultad
    ).toList();
    escuela = null;
    siglaEscuela = null;
    setState(() {});
  }

  void _onEscuelaChanged(String? value) {
    escuela = value;
    // Buscar la sigla de la escuela seleccionada
    siglaEscuela = escuelasFiltradas.firstWhere(
      (e) => e['nombre'] == value,
      orElse: () => {},
    )['siglas'];
    setState(() {});
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    await FirebaseFirestore.instance.collection('alumnos').add({
      'dni': dni,
      'codigo_universitario': codigo,
      'nombre': nombre,
      'apellido': apellido,
      'escuela_profesional': escuela,
      'facultad': facultad,
      'siglas_escuela': siglaEscuela,
      'siglas_facultad': siglaFacultad,
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alumno registrado')));
    _formKey.currentState!.reset();
    setState(() {
      escuela = null;
      facultad = null;
      siglaEscuela = null;
      siglaFacultad = null;
      escuelasFiltradas = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registro Provisional de Estudiantes')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'DNI (opcional)'),
                onSaved: (v) => dni = v,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Código Universitario'),
                validator: (v) => v == null || v.isEmpty ? 'Obligatorio' : null,
                onSaved: (v) => codigo = v,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (v) => v == null || v.isEmpty ? 'Obligatorio' : null,
                onSaved: (v) => nombre = v,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Apellido'),
                validator: (v) => v == null || v.isEmpty ? 'Obligatorio' : null,
                onSaved: (v) => apellido = v,
              ),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Facultad'),
                value: facultad,
                items: facultades.map<DropdownMenuItem<String>>((f) => DropdownMenuItem<String>(
                  value: f['nombre'] as String,
                  child: Text(f['nombre'] as String),
                )).toList(),
                onChanged: _onFacultadChanged,
                validator: (v) => v == null ? 'Seleccione facultad' : null,
              ),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Escuela Profesional'),
                value: escuela,
                items: escuelasFiltradas.map<DropdownMenuItem<String>>((e) => DropdownMenuItem<String>(
                  value: e['nombre'] as String,
                  child: Text(e['nombre'] as String),
                )).toList(),
                onChanged: _onEscuelaChanged,
                validator: (v) => v == null ? 'Seleccione escuela' : null,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Siglas Facultad'),
                readOnly: true,
                controller: TextEditingController(text: siglaFacultad ?? ''),
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Siglas Escuela'),
                readOnly: true,
                controller: TextEditingController(text: siglaEscuela ?? ''),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _save,
                child: const Text('Registrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
