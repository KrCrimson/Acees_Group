import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> showAddEditUserDialog(
  BuildContext context, {
  DocumentSnapshot? user,
  required String userRole,
}) async {
  final nombreController = TextEditingController(text: user?['nombre'] ?? '');
  final apellidoController = TextEditingController(text: user?['apellido'] ?? '');
  final dniController = TextEditingController(text: user?['dni'] ?? '');
  final emailController = TextEditingController(text: user?['email'] ?? '');
  final passwordController = TextEditingController();

  final formKey = GlobalKey<FormState>();

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text(user == null ? 'Agregar $userRole' : 'Editar $userRole'),
      content: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nombreController,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (value) => value!.isEmpty ? 'Requerido' : null,
              ),
              TextFormField(
                controller: apellidoController,
                decoration: const InputDecoration(labelText: 'Apellido'),
                validator: (value) => value!.isEmpty ? 'Requerido' : null,
              ),
              TextFormField(
                controller: dniController,
                decoration: const InputDecoration(labelText: 'DNI'),
                keyboardType: TextInputType.number,
                validator: (value) => value!.length < 8 ? 'Mínimo 8 dígitos' : null,
              ),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) => 
                    !value!.contains('@') ? 'Email inválido' : null,
              ),
              if (user == null)
                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: 'Contraseña'),
                  obscureText: true,
                  validator: (value) => 
                      value!.length < 6 ? 'Mínimo 6 caracteres' : null,
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
          onPressed: () async {
            if (formKey.currentState!.validate()) {
              try {
                final auth = FirebaseAuth.instance;
                final firestore = FirebaseFirestore.instance;

                final userData = {
                  'nombre': nombreController.text,
                  'apellido': apellidoController.text,
                  'dni': dniController.text,
                  'email': emailController.text,
                  'rango': userRole,
                  'estado': 'activo',
                  'fecha_actualizacion': FieldValue.serverTimestamp(),
                };

                if (user == null) {
                  // Crear en Auth + Firestore
                  final cred = await auth.createUserWithEmailAndPassword(
                    email: emailController.text,
                    password: passwordController.text,
                  );
                  await firestore
                      .collection('usuarios')
                      .doc(cred.user!.uid)
                      .set({
                    ...userData,
                    'fecha_creacion': FieldValue.serverTimestamp(),
                  });
                } else {
                  // Solo actualizar Firestore
                  await user.reference.update(userData);
                }

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(
                      user == null ? 'Usuario creado' : 'Actualizado'
                    )),
                  );
                }
              } on FirebaseAuthException catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(
                      e.code == 'email-already-in-use' 
                        ? 'El email ya está registrado' 
                        : 'Error: ${e.message}'
                    )),
                  );
                }
              }
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
}