import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/reports_viewmodel.dart';
import '../../widgets/custom_button.dart';
import '../login_view.dart';
import 'user_management_view.dart';
import 'reports_view.dart';
import 'session_config_view.dart';
import 'session_management_view.dart';
import 'historial_view.dart';
import 'sync_config_view.dart';

class AdminView extends StatefulWidget {
  @override
  _AdminViewState createState() => _AdminViewState();
}

class _AdminViewState extends State<AdminView> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    AdminDashboard(),
    UserManagementView(),
    ReportsView(),
  ];

  void _handleLogout() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Cerrar Sesión'),
            content: Text('¿Está seguro de que desea cerrar sesión?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancelar'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  final authViewModel = Provider.of<AuthViewModel>(
                    context,
                    listen: false,
                  );
                  authViewModel.logout();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => LoginView()),
                  );
                },
                child: Text('Cerrar Sesión'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Panel de Administración'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          Consumer<AuthViewModel>(
            builder: (context, authViewModel, child) {
              return PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'logout') {
                    _handleLogout();
                  }
                },
                itemBuilder:
                    (context) => [
                      PopupMenuItem(
                        value: 'profile',
                        child: ListTile(
                          leading: Icon(Icons.admin_panel_settings),
                          title: Text('Administrador'),
                          subtitle: Text(
                            authViewModel.currentUser?.nombreCompleto ?? '',
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'logout',
                        child: ListTile(
                          leading: Icon(Icons.logout, color: Colors.red),
                          title: Text(
                            'Cerrar Sesión',
                            style: TextStyle(color: Colors.red),
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
              );
            },
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Usuarios'),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Reportes',
          ),
        ],
      ),
    );
  }
}

class AdminDashboard extends StatefulWidget {
  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
    });
  }

  Future<void> _loadDashboardData() async {
    final reportsViewModel = Provider.of<ReportsViewModel>(
      context,
      listen: false,
    );
    await reportsViewModel.loadAllData();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16),
        child: Consumer<ReportsViewModel>(
          builder: (context, reportsViewModel, child) {
            if (reportsViewModel.isLoading) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Cargando datos...'),
                  ],
                ),
              );
            }

            if (reportsViewModel.errorMessage != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                    SizedBox(height: 16),
                    Text(
                      reportsViewModel.errorMessage!,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadDashboardData,
                      child: Text('Reintentar'),
                    ),
                  ],
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Estadísticas principales
                _buildStatsSection(reportsViewModel),
                SizedBox(height: 24),

                // Resumen de datos
                _buildDataSummary(reportsViewModel),
                SizedBox(height: 24),

                // Acciones rápidas
                _buildQuickActions(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatsSection(ReportsViewModel reportsViewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Estadísticas de Hoy',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Asistencias Hoy',
                '${reportsViewModel.getTotalAsistenciasHoy()}',
                Icons.today,
                Colors.blue,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Esta Semana',
                '${reportsViewModel.getTotalAsistenciasEstaSemana()}',
                Icons.date_range,
                Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataSummary(ReportsViewModel reportsViewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resumen del Sistema',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildSummaryRow(
                'Total Estudiantes',
                '${reportsViewModel.alumnos.length}',
                Icons.school,
              ),
              Divider(),
              _buildSummaryRow(
                'Total Asistencias',
                '${reportsViewModel.asistencias.length}',
                Icons.assignment_turned_in,
              ),
              Divider(),
              _buildSummaryRow(
                'Facultades',
                '${reportsViewModel.facultades.length}',
                Icons.business,
              ),
              Divider(),
              _buildSummaryRow(
                'Escuelas',
                '${reportsViewModel.escuelas.length}',
                Icons.location_city,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Acciones Rápidas',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: CustomButton(
                text: 'Gestionar Usuarios',
                icon: Icons.people,
                onPressed: () {
                  // Cambiar a la pestaña de usuarios
                  final adminView =
                      context.findAncestorStateOfType<_AdminViewState>();
                  adminView?.setState(() {
                    adminView._selectedIndex = 1;
                  });
                },
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: CustomButton(
                text: 'Ver Reportes',
                icon: Icons.analytics,
                backgroundColor: Colors.green,
                onPressed: () {
                  // Cambiar a la pestaña de reportes
                  final adminView =
                      context.findAncestorStateOfType<_AdminViewState>();
                  adminView?.setState(() {
                    adminView._selectedIndex = 2;
                  });
                },
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: CustomButton(
                text: 'Configurar Sesión',
                icon: Icons.timer,
                backgroundColor: Colors.orange,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SessionConfigView(),
                    ),
                  );
                },
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: CustomButton(
                text: 'Sincronización',
                icon: Icons.sync_alt,
                backgroundColor: Colors.teal,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SyncConfigView()),
                  );
                },
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: CustomButton(
                text: 'Gestión Sesiones',
                icon: Icons.supervisor_account,
                backgroundColor: Colors.purple,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => Consumer<AuthViewModel>(
                            builder: (context, authViewModel, child) {
                              return SessionManagementView(
                                adminId: authViewModel.currentUser?.id ?? '',
                                adminName:
                                    authViewModel.currentUser?.nombreCompleto ??
                                    'Admin',
                              );
                            },
                          ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: CustomButton(
                text: 'Ver Historial',
                icon: Icons.history,
                backgroundColor: Colors.indigo,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => HistorialView()),
                  );
                },
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Container(), // Espacio vacío para simetría
            ),
          ],
        ),
      ],
    );
  }
}
