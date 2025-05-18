import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';

class UserScreen extends StatelessWidget {
  const UserScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Usuario'),
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
            Text('Bienvenido Usuario: ${user?.email}'),
            const SizedBox(height: 20),
            const Text('Esta es la vista para usuarios normales'),
          ],
        ),
      ),
    );
  }
}