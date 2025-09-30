import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../models/historial_modificacion_model.dart';
import '../../widgets/status_widgets.dart';

class HistorialView extends StatefulWidget {
  @override
  _HistorialViewState createState() => _HistorialViewState();
}

class _HistorialViewState extends State<HistorialView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHistorial();
    });
  }

  Future<void> _loadHistorial() async {
    final adminViewModel = Provider.of<AdminViewModel>(context, listen: false);
    await adminViewModel.loadHistorial();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Historial de Modificaciones'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Consumer<AdminViewModel>(
        builder: (context, adminViewModel, child) {
          if (adminViewModel.isLoading && adminViewModel.historial.isEmpty) {
            return LoadingWidget(message: 'Cargando historial...');
          }

          if (adminViewModel.errorMessage != null &&
              adminViewModel.historial.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  SizedBox(height: 16),
                  Text(
                    adminViewModel.errorMessage!,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadHistorial,
                    child: Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          if (adminViewModel.historial.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey[400]),
                  SizedBox(height: 16),
                  Text(
                    'No hay historial disponible',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  Text(
                    'Los cambios realizados aparecerán aquí',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadHistorial,
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: adminViewModel.historial.length,
              itemBuilder: (context, index) {
                final registro = adminViewModel.historial[index];
                return _buildHistorialCard(registro);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistorialCard(HistorialModificacionModel registro) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con acción y fecha
            Row(
              children: [
                Text(
                  registro.accionDisplay,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _getColorForAccion(registro.accion),
                  ),
                ),
                Spacer(),
                Text(
                  registro.fechaFormateada,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            SizedBox(height: 8),

            // Tipo de entidad
            Row(
              children: [
                Text(
                  registro.tipoEntidadDisplay,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'ID: ${registro.entidadId}',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),

            // Descripción si existe
            if (registro.descripcion != null &&
                registro.descripcion!.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  registro.descripcion!,
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[700],
                  ),
                ),
              ),

            // Cambios realizados
            if (registro.cambiosRealizados.isNotEmpty)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cambios realizados:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      registro.resumenCambios,
                      style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                    ),
                  ],
                ),
              ),

            SizedBox(height: 8),

            // Admin que realizó el cambio
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey[500]),
                SizedBox(width: 4),
                Text(
                  'Por: ${registro.adminNombre}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorForAccion(String accion) {
    switch (accion.toLowerCase()) {
      case 'crear':
        return Colors.green;
      case 'modificar':
        return Colors.blue;
      case 'activar':
        return Colors.green;
      case 'desactivar':
        return Colors.red;
      case 'asignar':
        return Colors.purple;
      case 'desasignar':
        return Colors.orange;
      default:
        return Colors.grey[700]!;
    }
  }
}
