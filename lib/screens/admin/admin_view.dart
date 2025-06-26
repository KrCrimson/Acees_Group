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
import 'pending_exit_screen.dart';

enum _AdminMenuOption {
  reportChart,
  reportGeneral,
  reportVisits,
  pendingExit,
  logout,
}

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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.indigo.withOpacity(0.85),
        elevation: 8,
        title: Text(
          'Panel de Administración',
          style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        actions: [
          PopupMenuButton<_AdminMenuOption>(
            icon: const Icon(Icons.menu, color: Colors.white),
            color: Colors.white,
            onSelected: (option) {
              switch (option) {
                case _AdminMenuOption.reportChart:
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (context) => const AdminReportChartScreen()),
                  );
                  break;
                case _AdminMenuOption.reportGeneral:
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (context) => const AdminReportScreen()),
                  );
                  break;
                case _AdminMenuOption.reportVisits:
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (context) => const ExternalVisitsReportScreen()),
                  );
                  break;
                case _AdminMenuOption.pendingExit:
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (context) => const PendingExitScreen()),
                  );
                  break;
                case _AdminMenuOption.logout:
                  _signOut();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _AdminMenuOption.reportChart,
                child: Row(
                  children: [
                    Icon(Icons.bar_chart, color: Colors.deepPurpleAccent),
                    const SizedBox(width: 8),
                    const Text('Reportes de asistencias'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _AdminMenuOption.reportGeneral,
                child: Row(
                  children: [
                    Icon(Icons.analytics, color: Colors.orangeAccent),
                    const SizedBox(width: 8),
                    const Text('Reporte General'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _AdminMenuOption.reportVisits,
                child: Row(
                  children: [
                    Icon(Icons.people, color: Colors.teal),
                    const SizedBox(width: 8),
                    const Text('Reporte de Visitas Externas'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _AdminMenuOption.pendingExit,
                child: Row(
                  children: [
                    Icon(Icons.pending_actions, color: Colors.deepOrange),
                    const SizedBox(width: 8),
                    const Text('Salidas Pendientes'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: _AdminMenuOption.logout,
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.redAccent),
                    const SizedBox(width: 8),
                    const Text('Cerrar sesión'),
                  ],
                ),
              ),
            ],
          ),
        ],
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
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Icon(Icons.admin_panel_settings, color: Colors.indigo[700]),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '¡Bienvenido, Administrador!',
                        style: GoogleFonts.lato(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, color: Colors.indigo),
                      labelText: 'Buscar (Nombre, DNI, Facultad)',
                      labelStyle: TextStyle(color: Colors.blueGrey[600]),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16.0),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildGuardiaList()),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.amber[700],
        elevation: 8,
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
          return Center(child: Text('Error: [${snapshot.error}', style: TextStyle(color: Colors.white)));
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
        List<DocumentSnapshot> unassignedUsers = [];
        for (var user in users) {
          final facultadRaw = user['puerta_acargo'];
          final facultad = (facultadRaw == null || facultadRaw.toString().trim().isEmpty || facultadRaw.toString().toLowerCase() == 'sin asignar')
              ? null
              : facultadRaw;
          if (facultad == null) {
            unassignedUsers.add(user);
          } else {
            if (!groupedUsers.containsKey(facultad)) {
              groupedUsers[facultad] = [];
            }
            groupedUsers[facultad]!.add(user);
          }
        }

        final allSections = [
          ...groupedUsers.keys.map((facultad) => _SectionData(facultad, groupedUsers[facultad]!)),
        ];
        if (unassignedUsers.isNotEmpty) {
          allSections.add(_SectionData('Sin Puerta Asignada', unassignedUsers));
        }

        return ListView.builder(
          itemCount: allSections.length,
          itemBuilder: (context, index) {
            final section = allSections[index];
            final facultad = section.facultad;
            final usersInFacultad = section.users;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                  child: Material(
                    elevation: 2,
                    borderRadius: BorderRadius.circular(12),
                    color: facultad == 'Sin Puerta Asignada' ? Colors.red[100] : Colors.indigo[50],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6),
                      child: Text(
                        facultad,
                        style: GoogleFonts.roboto(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: facultad == 'Sin Puerta Asignada' ? Colors.red[900] : Colors.indigo[900],
                        ),
                      ),
                    ),
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

class _SectionData {
  final String facultad;
  final List<DocumentSnapshot> users;
  _SectionData(this.facultad, this.users);
}
