import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_edit_user_dialog.dart';
import 'user_card.dart';
import 'admin_report_chart_screen.dart';
import 'admin_report_screen.dart'; // Import admin_report_screen.dart
import 'external_visits_report_screen.dart'; // Import the external visits report screen
import 'package:google_fonts/google_fonts.dart';
import '../../login_screen.dart';

class AdminView extends StatefulWidget {
  const AdminView({Key? key}) : super(key: key);

  @override
  State<AdminView> createState() => _AdminViewState();
}

class _AdminViewState extends State<AdminView> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false, // Remove all previous routes
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cerrar sesión: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin View'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Reportes de asistencias',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (context) => const AdminReportChartScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.analytics),
            tooltip: 'Reporte General',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (context) => const AdminReportScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.people),
            tooltip: 'Reporte de Visitas Externas',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (context) => const ExternalVisitsReportScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
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
              decoration: const InputDecoration(
                labelText: 'Buscar (Nombre, DNI, Facultad)',
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(child: _buildGuardiaList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.indigo[700],
        onPressed: () {
          showAddEditUserDialog(
            context,
            userRole: 'guardia', // Default role for new users
          );
        },
        tooltip: 'Agregar Usuario',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildGuardiaList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('usuarios')
          .where('rango', isEqualTo: 'guardia')
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
          final facultad = user['puerta_acargo'].toString().toLowerCase();
          return nombre.contains(_searchQuery.toLowerCase()) ||
              dni.contains(_searchQuery.toLowerCase()) ||
              facultad.contains(_searchQuery.toLowerCase());
        }).toList();

        // Group users by faculty
        Map<String, List<DocumentSnapshot>> groupedUsers = {};
        for (var user in users) {
          final facultad = user['puerta_acargo'] ?? 'Sin Facultad';
          if (!groupedUsers.containsKey(facultad)) {
            groupedUsers[facultad] = [];
          }
          groupedUsers[facultad]!.add(user);
        }

        return ListView.builder(
          itemCount: groupedUsers.length,
          itemBuilder: (context, index) {
            final facultad = groupedUsers.keys.toList()[index];
            final usersInFacultad = groupedUsers[facultad]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    facultad,
                    style: GoogleFonts.roboto(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: usersInFacultad.length,
                  itemBuilder: (context, index) {
                    final user = usersInFacultad[index];
                    return UserCard(
                      user: user,
                      onEdit: () => showAddEditUserDialog(
                        context,
                        user: user,
                        userRole: 'guardia',
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
