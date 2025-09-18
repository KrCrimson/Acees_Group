import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/matriculation_viewmodel.dart';
import '../widgets/status_widgets.dart';

class MatriculationDetailView extends StatefulWidget {
  final String codigoUniversitario;

  const MatriculationDetailView({
    Key? key,
    required this.codigoUniversitario,
  }) : super(key: key);

  @override
  _MatriculationDetailViewState createState() => _MatriculationDetailViewState();
}

class _MatriculationDetailViewState extends State<MatriculationDetailView>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadMatriculationDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMatriculationDetails() async {
    final matriculationViewModel = Provider.of<MatriculationViewModel>(
      context,
      listen: false,
    );
    await matriculationViewModel.verificarVigenciaMatricula(widget.codigoUniversitario);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detalles de Matrícula'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: Consumer<MatriculationViewModel>(
        builder: (context, matriculationViewModel, child) {
          if (matriculationViewModel.isLoading) {
            return LoadingWidget(message: 'Cargando detalles de matrícula...');
          }

          if (matriculationViewModel.errorMessage != null) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                SizedBox(height: 16),
                Text(matriculationViewModel.errorMessage!, textAlign: TextAlign.center),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadMatriculationDetails,
                  child: Text('Reintentar'),
                ),
              ],
            );
          }

          if (matriculationViewModel.currentMatriculation == null) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.school_off, size: 64, color: Colors.grey[400]),
                SizedBox(height: 16),
                Text('No se encontró información de matrícula'),
              ],
            );
          }

          final matriculation = matriculationViewModel.currentMatriculation!;

          return Column(
            children: [
              // Header con información básica
              _buildMatriculationHeader(matriculation),
              
              // Tabs
              TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: 'Información', icon: Icon(Icons.info)),
                  Tab(text: 'Pago', icon: Icon(Icons.payment)),
                  Tab(text: 'Historial', icon: Icon(Icons.history)),
                ],
              ),

              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildInformationTab(matriculation),
                    _buildPaymentTab(matriculation),
                    _buildHistoryTab(matriculation),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMatriculationHeader(matriculation) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: matriculation.puedeAcceder ? Colors.green[50] : Colors.red[50],
        border: Border(
          bottom: BorderSide(
            color: matriculation.puedeAcceder ? Colors.green[200] : Colors.red[200],
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: matriculation.puedeAcceder ? Colors.green : Colors.red,
                child: Icon(
                  matriculation.puedeAcceder ? Icons.check : Icons.close,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      matriculation.nombreCompleto,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      'Código: ${matriculation.codigoUniversitario}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    Text(
                      'Período: ${matriculation.periodoCompleto}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: matriculation.puedeAcceder ? Colors.green[100] : Colors.red[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  matriculation.puedeAcceder ? 'Acceso Permitido' : 'Acceso Denegado',
                  style: TextStyle(
                    color: matriculation.puedeAcceder ? Colors.green[700] : Colors.red[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: matriculation.puedeAcceder ? Colors.green[200] : Colors.red[200],
              ),
            ),
            child: Text(
              matriculation.recomendacionAcceso,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: matriculation.puedeAcceder ? Colors.green[700] : Colors.red[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInformationTab(matriculation) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Información académica
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Información Académica',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  _buildInfoRow('Período Académico', matriculation.periodoCompleto),
                  _buildInfoRow('Ciclo', matriculation.cicloAcademico),
                  _buildInfoRow('Año', matriculation.anioAcademico),
                  _buildInfoRow('Tipo de Matrícula', matriculation.tipoMatriculaFormateado),
                  _buildInfoRow('Estado', matriculation.estadoMatriculaFormateado),
                  _buildInfoRow('Fecha de Matriculación', 
                    '${matriculation.fechaMatriculacion.day}/${matriculation.fechaMatriculacion.month}/${matriculation.fechaMatriculacion.year}'),
                  _buildInfoRow('Fecha de Vencimiento', 
                    '${matriculation.fechaVencimiento.day}/${matriculation.fechaVencimiento.month}/${matriculation.fechaVencimiento.year}'),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),

          // Estado de vigencia
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estado de Vigencia',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  _buildStatusRow('Vigente', matriculation.isVigente ? 'Sí' : 'No'),
                  _buildStatusRow('Vencida', matriculation.isVencida ? 'Sí' : 'No'),
                  _buildStatusRow('Por Vencer', matriculation.isPorVencer ? 'Sí' : 'No'),
                  _buildStatusRow('Días Restantes', '${matriculation.diasRestantes}'),
                  _buildStatusRow('Días Transcurridos', '${matriculation.diasTranscurridos}'),
                  _buildStatusRow('Tiempo Restante', matriculation.tiempoRestanteFormateado),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),

          // Alertas
          if (matriculation.tieneAlertas) ...[
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          'Alertas',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    ...matriculation.alertas.map((alerta) => Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.orange, size: 16),
                          SizedBox(width: 8),
                          Expanded(child: Text(alerta)),
                        ],
                      ),
                    )).toList(),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentTab(matriculation) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Información de pago
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Información de Pago',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  _buildInfoRow('Monto', matriculation.montoFormateado),
                  _buildInfoRow('Estado de Pago', matriculation.estadoPago),
                  _buildInfoRow('Pago Completo', matriculation.pagoCompleto ? 'Sí' : 'No'),
                  if (matriculation.fechaPago != null)
                    _buildInfoRow('Fecha de Pago', matriculation.fechaPagoFormateada),
                  if (matriculation.numeroComprobante != null)
                    _buildInfoRow('Comprobante', matriculation.numeroComprobante!),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),

          // Estado de pago visual
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estado de Pago',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        matriculation.pagoCompleto ? Icons.check_circle : Icons.pending,
                        color: matriculation.pagoCompleto ? Colors.green : Colors.orange,
                        size: 24,
                      ),
                      SizedBox(width: 8),
                      Text(
                        matriculation.estadoPago,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: matriculation.pagoCompleto ? Colors.green[700] : Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                  if (!matriculation.pagoCompleto) ...[
                    SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Text(
                        'Pago pendiente - Verificar con administración',
                        style: TextStyle(color: Colors.orange[700]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(matriculation) {
    return Consumer<MatriculationViewModel>(
      builder: (context, matriculationViewModel, child) {
        return FutureBuilder<List<MatriculationModel>>(
          future: matriculationViewModel.getHistorialMatriculas(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return LoadingWidget(message: 'Cargando historial...');
            }

            if (snapshot.hasError) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  SizedBox(height: 16),
                  Text('Error al cargar historial: ${snapshot.error}'),
                ],
              );
            }

            final historial = snapshot.data ?? [];

            if (historial.isEmpty) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey[400]),
                  SizedBox(height: 16),
                  Text('No hay historial de matrículas'),
                ],
              );
            }

            return ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: historial.length,
              itemBuilder: (context, index) {
                final matricula = historial[index];
                return Card(
                  margin: EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: matricula.isVigente ? Colors.green[100] : Colors.red[100],
                      child: Icon(
                        matricula.isVigente ? Icons.check : Icons.close,
                        color: matricula.isVigente ? Colors.green : Colors.red,
                      ),
                    ),
                    title: Text(
                      matricula.periodoCompleto,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tipo: ${matricula.tipoMatriculaFormateado}'),
                        Text('Estado: ${matricula.estadoMatriculaFormateado}'),
                        Text('Monto: ${matricula.montoFormateado}'),
                      ],
                    ),
                    trailing: Text(
                      '${matricula.fechaMatriculacion.day}/${matricula.fechaMatriculacion.month}/${matricula.fechaMatriculacion.year}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                );
              },
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

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.w500)),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: value == 'Sí' ? Colors.green[100] : Colors.red[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: value == 'Sí' ? Colors.green[700] : Colors.red[700],
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
