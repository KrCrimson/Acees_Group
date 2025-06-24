import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class UserCard extends StatelessWidget {
  final DocumentSnapshot user;
  final VoidCallback onEdit;

  const UserCard({
    super.key,
    required this.user,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = user['estado'] == 'activo';

    return Card(
      margin: const EdgeInsets.all(8),
      color: isActive ? null : Colors.grey[100], // Cambiar color si está inactivo
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isActive ? Colors.blue : Colors.grey,
          child: Text(
            user['nombre'][0],
            style: TextStyle(
              color: isActive ? Colors.white : Colors.black54,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${user['nombre']} ${user['apellido']}',
                style: TextStyle(
                  color: isActive ? Colors.black : Colors.grey[600],
                  fontWeight: isActive ? FontWeight.normal : FontWeight.w300,
                ),
              ),
            ),
            if (!isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red[300]!),
                ),
                child: Text(
                  'INACTIVO',
                  style: TextStyle(
                    color: Colors.red[700],
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DNI: ${user['dni']}',
              style: TextStyle(color: isActive ? Colors.black87 : Colors.grey[500]),
            ),
            Text(
              'Email: ${user['email']}',
              style: TextStyle(color: isActive ? Colors.black87 : Colors.grey[500]),
            ),
            Text(
              'Rol: ${user['rango']}',
              style: TextStyle(color: isActive ? Colors.black87 : Colors.grey[500]),
            ),
            if (user['rango'] == 'guardia')
              Text(
                'Puerta a Cargo: ${user['puerta_acargo'] ?? 'Sin asignar'}',
                style: TextStyle(color: isActive ? Colors.black87 : Colors.grey[500]),
              ),
            Text(
              'Estado: ${user['estado']}',
              style: TextStyle(
                color: isActive ? Colors.green[600] : Colors.red[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: onEdit,
            ),
            IconButton(
              icon: Icon(
                isActive ? Icons.block : Icons.check_circle,
                color: isActive ? Colors.red : Colors.green,
              ),
              onPressed: () => _toggleStatus(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleStatus(BuildContext context) async {
  try {
    final newStatus = user['estado'] == 'activo' ? 'inactivo' : 'activo';
    
    // 1. Actualizar Firestore
    await user.reference.update({
      'estado': newStatus,
      'fecha_actualizacion': FieldValue.serverTimestamp(),
    });

    // 2. Opcional: Actualizar Auth (requiere backend)
    if (newStatus == 'inactivo') {
      // Esto debería hacerse desde una Cloud Function
      debugPrint('Nota: Para deshabilitar en Auth, implementa una Cloud Function');
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Estado actualizado a $newStatus')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}
}