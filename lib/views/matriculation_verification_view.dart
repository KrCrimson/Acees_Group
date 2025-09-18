import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/matriculation_viewmodel.dart';
import '../widgets/status_widgets.dart';
import 'matriculation_detail_view.dart';
import 'matriculation_search_view.dart';

class MatriculationVerificationView extends StatefulWidget {
  @override
  _MatriculationVerificationViewState createState() => _MatriculationVerificationViewState();
}

class _MatriculationVerificationViewState extends State<MatriculationVerificationView>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final matriculationViewModel = Provider.of<MatriculationViewModel>(
      context,
      listen: false,
    );
    await matriculationViewModel.loadMatriculasPorVencer();
    await matriculationViewModel.loadMatriculasVencidas();
    await matriculationViewModel.loadMatriculasPendientePago();
    await matriculationViewModel.loadEstadisticas();
    await matriculationViewModel.loadAlertas();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Verificar Vigencia Matrícula'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MatriculationSearchView(),
                ),
              );
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildVerificationTab(),
          _buildPorVencerTab(),
          _buildVencidasTab(),
          _buildPendientesTab(),
        ],
      ),
      bottomNavigationBar: TabBar(
        controller: _tabController,
        tabs: [
          Tab(text: 'Verificar', icon: Icon(Icons.verified_user)),
          Tab(text: 'Por Vencer', icon: Icon(Icons.warning)),
          Tab(text: 'Vencidas', icon: Icon(Icons.error)),
          Tab(text: 'Pendientes', icon: Icon(Icons.pending)),
        ],
      ),
    );
  }

  Widget _buildVerificationTab() {
    return Consumer<MatriculationViewModel>(
      builder: (context, matriculationViewModel, child) {
        return SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Búsqueda rápida
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verificación Rápida',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Código universitario o DNI...',
                                prefixIcon: Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey[100],
                              ),
                              onSubmitted: (value) {
                                if (value.trim().isNotEmpty) {
                                  _verifyMatriculation(value.trim());
                                }
                              },
                            ),
                          ),
                          SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () {
                              if (_searchController.text.trim().isNotEmpty) {
                                _verifyMatriculation(_searchController.text.trim());
                              }
                            },
                            icon: Icon(Icons.verified_user),
                            label: Text('Verificar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[700],
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Resultado de verificación
              if (matriculationViewModel.currentMatriculation != null)
                _buildMatriculationResult(matriculationViewModel.currentMatriculation!),

              // Estadísticas generales
              _buildStatisticsCard(matriculationViewModel),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMatriculationResult(matriculation) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  matriculation.puedeAcceder ? Icons.check_circle : Icons.cancel,
                  color: matriculation.puedeAcceder ? Colors.green : Colors.red,
                  size: 24,
                ),
                SizedBox(width: 8),
                Text(
                  'Resultado de Verificación',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 12),
            _buildInfoRow('Estudiante', matriculation.nombreCompleto),
            _buildInfoRow('Código', matriculation.codigoUniversitario),
            _buildInfoRow('Período', matriculation.periodoCompleto),
            _buildInfoRow('Estado', matriculation.estadoMatriculaFormateado),
            _buildInfoRow('Tipo', matriculation.tipoMatriculaFormateado),
            _buildInfoRow('Vigencia', matriculation.isVigente ? 'Vigente' : 'No vigente'),
            _buildInfoRow('Días restantes', '${matriculation.diasRestantes}'),
            _buildInfoRow('Pago', matriculation.estadoPago),
            if (matriculation.tieneAlertas) ...[
              SizedBox(height: 8),
              Text('Alertas:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...matriculation.alertas.map((alerta) => Padding(
                padding: EdgeInsets.only(left: 16, top: 4),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange, size: 16),
                    SizedBox(width: 8),
                    Expanded(child: Text(alerta)),
                  ],
                ),
              )).toList(),
            ],
            SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: matriculation.puedeAcceder ? Colors.green[50] : Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: matriculation.puedeAcceder ? Colors.green[200] : Colors.red[200],
                ),
              ),
              child: Text(
                matriculation.recomendacionAcceso,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: matriculation.puedeAcceder ? Colors.green[700] : Colors.red[700],
                ),
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MatriculationDetailView(
                            codigoUniversitario: matriculation.codigoUniversitario,
                          ),
                        ),
                      );
                    },
                    icon: Icon(Icons.info),
                    label: Text('Ver Detalles'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCard(MatriculationViewModel matriculationViewModel) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estadísticas Generales',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            if (matriculationViewModel.estadisticas.isNotEmpty) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total Matrículas',
                      '${matriculationViewModel.estadisticas['total'] ?? 0}',
                      Colors.blue,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      'Vigentes',
                      '${matriculationViewModel.estadisticas['vigentes'] ?? 0}',
                      Colors.green,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Vencidas',
                      '${matriculationViewModel.estadisticas['vencidas'] ?? 0}',
                      Colors.red,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      'Por Vencer',
                      '${matriculationViewModel.estadisticas['por_vencer'] ?? 0}',
                      Colors.orange,
                    ),
                  ),
                ],
              ),
            ] else ...[
              Text('No hay estadísticas disponibles'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPorVencerTab() {
    return Consumer<MatriculationViewModel>(
      builder: (context, matriculationViewModel, child) {
        if (matriculationViewModel.isLoading) {
          return LoadingWidget(message: 'Cargando matrículas por vencer...');
        }

        if (matriculationViewModel.matriculasPorVencer.isEmpty) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, size: 64, color: Colors.green[400]),
              SizedBox(height: 16),
              Text(
                'No hay matrículas por vencer',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: matriculationViewModel.matriculasPorVencer.length,
          itemBuilder: (context, index) {
            final matriculation = matriculationViewModel.matriculasPorVencer[index];
            return Card(
              margin: EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange[100],
                  child: Icon(Icons.warning, color: Colors.orange),
                ),
                title: Text(
                  matriculation.nombreCompleto,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Código: ${matriculation.codigoUniversitario}'),
                    Text('Período: ${matriculation.periodoCompleto}'),
                    Text('Días restantes: ${matriculation.diasRestantes}'),
                  ],
                ),
                trailing: Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MatriculationDetailView(
                        codigoUniversitario: matriculation.codigoUniversitario,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildVencidasTab() {
    return Consumer<MatriculationViewModel>(
      builder: (context, matriculationViewModel, child) {
        if (matriculationViewModel.isLoading) {
          return LoadingWidget(message: 'Cargando matrículas vencidas...');
        }

        if (matriculationViewModel.matriculasVencidas.isEmpty) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, size: 64, color: Colors.green[400]),
              SizedBox(height: 16),
              Text(
                'No hay matrículas vencidas',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: matriculationViewModel.matriculasVencidas.length,
          itemBuilder: (context, index) {
            final matriculation = matriculationViewModel.matriculasVencidas[index];
            return Card(
              margin: EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.red[100],
                  child: Icon(Icons.error, color: Colors.red),
                ),
                title: Text(
                  matriculation.nombreCompleto,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Código: ${matriculation.codigoUniversitario}'),
                    Text('Período: ${matriculation.periodoCompleto}'),
                    Text('Vencida desde: ${matriculation.fechaVencimiento.day}/${matriculation.fechaVencimiento.month}/${matriculation.fechaVencimiento.year}'),
                  ],
                ),
                trailing: Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MatriculationDetailView(
                        codigoUniversitario: matriculation.codigoUniversitario,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPendientesTab() {
    return Consumer<MatriculationViewModel>(
      builder: (context, matriculationViewModel, child) {
        if (matriculationViewModel.isLoading) {
          return LoadingWidget(message: 'Cargando matrículas pendientes...');
        }

        if (matriculationViewModel.matriculasPendientePago.isEmpty) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, size: 64, color: Colors.green[400]),
              SizedBox(height: 16),
              Text(
                'No hay matrículas pendientes de pago',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: matriculationViewModel.matriculasPendientePago.length,
          itemBuilder: (context, index) {
            final matriculation = matriculationViewModel.matriculasPendientePago[index];
            return Card(
              margin: EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.amber[100],
                  child: Icon(Icons.pending, color: Colors.amber[700]),
                ),
                title: Text(
                  matriculation.nombreCompleto,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Código: ${matriculation.codigoUniversitario}'),
                    Text('Período: ${matriculation.periodoCompleto}'),
                    Text('Monto: ${matriculation.montoFormateado}'),
                  ],
                ),
                trailing: Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MatriculationDetailView(
                        codigoUniversitario: matriculation.codigoUniversitario,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(color: Colors.grey[700])),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyMatriculation(String query) async {
    final matriculationViewModel = Provider.of<MatriculationViewModel>(
      context,
      listen: false,
    );

    // Intentar verificar por código universitario primero
    try {
      await matriculationViewModel.verificarVigenciaMatricula(query);
    } catch (e) {
      // Si falla, intentar por DNI
      try {
        await matriculationViewModel.verificarVigenciaMatriculaByDni(query);
      } catch (e) {
        // Error ya manejado por el ViewModel
      }
    }
  }
}
