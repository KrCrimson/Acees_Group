import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Administrador'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => authService.signOut(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Bienvenido Administrador: ${user?.email}'),
            const SizedBox(height: 20),
            const Text('Esta es la vista exclusiva para administradores'),
          ],
        ),
      ),
    );
  }
}