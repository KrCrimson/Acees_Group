import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart'; // Necesario para Firebase.app()
import '../../main.dart'; // Para acceder a secondaryAppName

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
              if (user == null)
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Requerido';
                    if (!value.contains('@')) return 'Email inválido';
                    return null;
                  }
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
                // Obtener la instancia de FirebaseAuth por defecto (para verificar el admin actual)
                final defaultAuth = FirebaseAuth.instance;
                final firestore = FirebaseFirestore.instance;

                // Capturar el email para la creación de forma consistente
                final String emailParaNuevoUsuario = user == null 
                    ? emailController.text.trim().toLowerCase() 
                    : '';

                final userData = {
                  'nombre': nombreController.text,
                  'apellido': apellidoController.text,
                  'dni': dniController.text,
                  if (user == null) 'email': emailParaNuevoUsuario,
                  'rango': userRole, // CORREGIDO: de 'ranga' a 'rango'
                  'estado': 'activo', 
                  'fecha_actualizacion': FieldValue.serverTimestamp(),
                };

                if (user == null) {
                  // USAR LA INSTANCIA SECUNDARIA DE FIREBASE AUTH PARA CREAR EL USUARIO
                  FirebaseAuth secondaryAuthInstance;
                  try {
                    FirebaseApp secondaryApp = Firebase.app(secondaryAppName);
                    secondaryAuthInstance = FirebaseAuth.instanceFor(app: secondaryApp);
                  } catch (e) {
                    debugPrint("Error getting secondary Firebase app instance: $e. Make sure it's initialized in main.dart.");
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Error de configuración al crear usuario. Contacte al soporte.')),
                    );
                    return;
                  }
                  
                  debugPrint("Admin actual (defaultAuth) ANTES de createUser: ${defaultAuth.currentUser?.uid}");

                  // Crear el usuario en la instancia secundaria.
                  // Esto NO debería afectar defaultAuth.currentUser.
                  final UserCredential cred = await secondaryAuthInstance.createUserWithEmailAndPassword(
                    email: emailParaNuevoUsuario,
                    password: passwordController.text,
                  );
                  
                  // El nuevo usuario (guardia) está "logueado" en secondaryAuthInstance, no en defaultAuth.
                  debugPrint("Nuevo guardia creado con UID: ${cred.user?.uid} (en instancia secundaria)");
                  debugPrint("Admin actual (defaultAuth) DESPUÉS de createUser: ${defaultAuth.currentUser?.uid}");


                  // Guardar datos en Firestore usando el UID del usuario creado.
                  await firestore
                      .collection('usuarios')
                      .doc(cred.user!.uid) // Usar el UID del usuario recién creado
                      .set({
                    ...userData, // userData ahora tiene 'rango' correctamente
                    'fecha_creacion': FieldValue.serverTimestamp(),
                  });

                  // Opcional: Desloguear al usuario de la instancia secundaria si es necesario,
                  // aunque no debería afectar a la instancia principal.
                  // await secondaryAuthInstance.signOut();
                  // debugPrint("Usuario ${cred.user?.uid} deslogueado de instancia secundaria.");

                } else {
                  // Solo actualizar Firestore (esto no involucra la instancia secundaria)
                  // Asegurarse que aquí también se use 'rango' si se modifica
                  await user.reference.update(userData); // userData ahora tiene 'rango' correctamente
                  debugPrint('Guardia actualizado. Admin actual (defaultAuth): ${defaultAuth.currentUser?.uid}');
                }

                if (context.mounted) {
                  // Verificar el currentUser de la instancia por defecto ANTES de cerrar el diálogo
                  debugPrint('Dialogo ADD/EDIT: Antes de Navigator.pop. Admin actual (defaultAuth) (UID: ${defaultAuth.currentUser?.uid}, Email: ${defaultAuth.currentUser?.email})');
                  Navigator.pop(context); // Cierra el diálogo
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