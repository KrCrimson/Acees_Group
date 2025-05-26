import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_edit_user_dialog.dart';
import 'user_card.dart';

class AdminView extends StatefulWidget {
  const AdminView({super.key});

  @override
  State<AdminView> createState() => _AdminViewState();
}

class _AdminViewState extends State<AdminView> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int _currentTabIndex = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login'); // Asegúrate que esta ruta esté definida
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Panel de Administrador'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Cerrar sesión',
              onPressed: _signOut,
            ),
          ],
          bottom: TabBar(
            tabs: const [
              Tab(icon: Icon(Icons.admin_panel_settings)),
              Tab(icon: Icon(Icons.security)),
            ],
            onTap: (index) => setState(() => _currentTabIndex = index),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Buscar',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  ),
                ),
                onChanged: (value) =>
                    setState(() => _searchQuery = value.toLowerCase()),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildUserList('admin'),
                  _buildUserList('guardia'),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: _currentTabIndex == 1
            ? FloatingActionButton(
                onPressed: () => showAddEditUserDialog(
                  context,
                  userRole: 'guardia',
                ),
                child: const Icon(Icons.add),
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
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data!.docs.where((user) {
          final nombre = user['nombre'].toString().toLowerCase();
          final dni = user['dni'].toString().toLowerCase();
          return nombre.contains(_searchQuery) ||
              dni.contains(_searchQuery);
        }).toList();

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) => UserCard(
            user: users[index],
            onEdit: () => showAddEditUserDialog(
              context,
              user: users[index],
              userRole: role,
            ),
          ),
        );
      },
    );
  }
}
