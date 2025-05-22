import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminView extends StatefulWidget {
  const AdminView({super.key});

  @override
  State<AdminView> createState() => _AdminViewState();
}

class _AdminViewState extends State<AdminView> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedTabIndex = 0; // 0 = Admins, 1 = Guardias

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Panel de Administrador'),
          bottom: TabBar(
            onTap: (index) => setState(() => _selectedTabIndex = index),
            tabs: const [
              Tab(icon: Icon(Icons.admin_panel_settings)),
              Tab(icon: Icon(Icons.security)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _signOut,
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Buscar',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  ),
                ),
                onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildUserList('admin'), // Tabla de administradores
                  _buildUserList('usuario'), // Tabla de guardias
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: _selectedTabIndex == 1 
            ? FloatingActionButton(
                child: const Icon(Icons.add),
                onPressed: () => _showAddGuardDialog(context),
              )
            : null,
      ),
    );
  }

  Widget _buildUserList(String role) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('usuarios')
          .where('rango', isEqualTo: role)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final users = snapshot.data?.docs.where((user) {
          final nombre = user['nombre'].toString().toLowerCase();
          final apellido = user['apellido'].toString().toLowerCase();
          final dni = user['dni'].toString().toLowerCase();
          return nombre.contains(_searchQuery) || 
                 apellido.contains(_searchQuery) || 
                 dni.contains(_searchQuery);
        }).toList() ?? [];

        if (users.isEmpty) {
          return Center(child: Text('No se encontraron ${role == 'admin' ? 'administradores' : 'usuario'}'));
        }

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) => _buildUserCard(users[index], role),
        );
      },
    );
  }

  Widget _buildUserCard(DocumentSnapshot user, String role) {
    final isActive = user['estado'] == 'activo';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(user['nombre'].toString().substring(0, 1)),
        ),
        title: Text('${user['nombre']} ${user['apellido']}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DNI: ${user['dni']}'),
            Text('Email: ${user['email']}'),
            Text('Estado: ${user['estado']}'),
            if (role == 'usuario') Text('Facultad: ${user['facultad']}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (role == 'usuario') IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _showEditUserDialog(context, user),
            ),
            IconButton(
              icon: Icon(
                isActive ? Icons.block : Icons.check_circle,
                color: isActive ? Colors.red : Colors.green,
              ),
              onPressed: () => _toggleUserStatus(user),
            ),
          ],
        ),
        onTap: () => _showUserDetails(context, user),
      ),
    );
  }

  void _showAddGuardDialog(BuildContext context) {
    final _formKey = GlobalKey<FormState>();
    final controllers = {
      'dni': TextEditingController(),
      'nombre': TextEditingController(),
      'apellido': TextEditingController(),
      'telefono': TextEditingController(),
      'email': TextEditingController(),
      'facultad': TextEditingController(),
      'password': TextEditingController(),
    };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar Guardia'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _buildTextFormField('DNI', controllers['dni']!, TextInputType.number),
                _buildTextFormField('Nombre', controllers['nombre']!),
                _buildTextFormField('Apellido', controllers['apellido']!),
                _buildTextFormField('Teléfono', controllers['telefono']!, TextInputType.phone),
                _buildTextFormField('Email', controllers['email']!, TextInputType.emailAddress),
                _buildTextFormField('Facultad', controllers['facultad']!),
                _buildTextFormField('Contraseña', controllers['password']!, null, true),
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
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                try {
                  // Crear usuario en Firebase Auth
                  final userCredential = await FirebaseAuth.instance
                      .createUserWithEmailAndPassword(
                    email: controllers['email']!.text.trim(),
                    password: controllers['password']!.text.trim(),
                  );

                  // Guardar datos en Firestore
                  await FirebaseFirestore.instance
                      .collection('usuarios')
                      .doc(userCredential.user?.uid)
                      .set({
                    'dni': controllers['dni']!.text.trim(),
                    'nombre': controllers['nombre']!.text.trim(),
                    'apellido': controllers['apellido']!.text.trim(),
                    'telefono': controllers['telefono']!.text.trim(),
                    'email': controllers['email']!.text.trim(),
                    'facultad': controllers['facultad']!.text.trim(),
                    'rango': 'guardia',
                    'estado': 'activo',
                    'fecha_creacion': FieldValue.serverTimestamp(),
                  });

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Guardia creado exitosamente')),
                    );
                  }
                } on FirebaseAuthException catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_getErrorMessage(e))),
                  );
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ).then((_) {
      controllers.values.forEach((controller) => controller.dispose());
    });
  }

  TextFormField _buildTextFormField(
    String label, 
    TextEditingController controller,
    [TextInputType? keyboardType, bool obscureText = false]
  ) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: (value) => value?.isEmpty ?? true ? 'Campo requerido' : null,
    );
  }

  void _showEditUserDialog(BuildContext context, DocumentSnapshot user) {
    final _formKey = GlobalKey<FormState>();
    final controllers = {
      'dni': TextEditingController(text: user['dni']),
      'nombre': TextEditingController(text: user['nombre']),
      'apellido': TextEditingController(text: user['apellido']),
      'telefono': TextEditingController(text: user['telefono']),
      'email': TextEditingController(text: user['email']),
      'facultad': TextEditingController(text: user['facultad']),
    };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Guardia'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _buildTextFormField('DNI', controllers['dni']!, TextInputType.number),
                _buildTextFormField('Nombre', controllers['nombre']!),
                _buildTextFormField('Apellido', controllers['apellido']!),
                _buildTextFormField('Teléfono', controllers['telefono']!, TextInputType.phone),
                _buildTextFormField('Email', controllers['email']!, TextInputType.emailAddress),
                _buildTextFormField('Facultad', controllers['facultad']!),
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
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                try {
                  await user.reference.update({
                    'dni': controllers['dni']!.text.trim(),
                    'nombre': controllers['nombre']!.text.trim(),
                    'apellido': controllers['apellido']!.text.trim(),
                    'telefono': controllers['telefono']!.text.trim(),
                    'email': controllers['email']!.text.trim(),
                    'facultad': controllers['facultad']!.text.trim(),
                    'fecha_actualizacion': FieldValue.serverTimestamp(),
                  });

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Guardia actualizado exitosamente')),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ).then((_) {
      controllers.values.forEach((controller) => controller.dispose());
    });
  }

  void _showUserDetails(BuildContext context, DocumentSnapshot user) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Detalles de ${user['nombre']}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildDetailRow('DNI', user['dni']),
            _buildDetailRow('Nombre', '${user['nombre']} ${user['apellido']}'),
            _buildDetailRow('Email', user['email']),
            _buildDetailRow('Teléfono', user['telefono']),
            if (user['facultad'] != null) _buildDetailRow('Facultad', user['facultad']),
            _buildDetailRow('Estado', user['estado']),
            _buildDetailRow('Rango', user['rango']),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _toggleUserStatus(DocumentSnapshot user) async {
    try {
      final newStatus = user['estado'] == 'activo' ? 'inactivo' : 'activo';
      await user.reference.update({
        'estado': newStatus,
        'fecha_actualizacion': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Estado cambiado a $newStatus')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cerrar sesión: ${e.toString()}')),
        );
      }
    }
  }

  String _getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'El email ya está registrado';
      case 'weak-password':
        return 'La contraseña es muy débil';
      case 'invalid-email':
        return 'Email inválido';
      default:
        return e.message ?? 'Error desconocido';
    }
  }
}