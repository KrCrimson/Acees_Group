import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';

class SessionManagementView extends StatefulWidget {
  final String adminId;
  final String adminName;

  const SessionManagementView({
    Key? key,
    required this.adminId,
    required this.adminName,
  }) : super(key: key);

  @override
  State<SessionManagementView> createState() => _SessionManagementViewState();
}

class _SessionManagementViewState extends State<SessionManagementView> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _sesionesActivas = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _cargarSesionesActivas();
  }

  Future<void> _cargarSesionesActivas() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sesiones = await _apiService.getSesionesActivas();
      setState(() {
        _sesionesActivas = sesiones;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _forzarFinalizacion(
    String guardiaId,
    String guardiaNombre,
  ) async {
    final confirmacion = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Confirmar Finalización'),
            content: Text(
              '¿Está seguro de que desea finalizar la sesión de $guardiaNombre?\n\n'
              'Esta acción cerrará todas las sesiones activas del guardia.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text('Finalizar'),
              ),
            ],
          ),
    );

    if (confirmacion == true) {
      try {
        final success = await _apiService.forzarFinalizacionSesion(
          guardiaId: guardiaId,
          adminId: widget.adminId,
        );

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sesión finalizada exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
          _cargarSesionesActivas();
        } else {
          _mostrarError('Error al finalizar la sesión');
        }
      } catch (e) {
        _mostrarError('Error: ${e.toString()}');
      }
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gestión de Sesiones'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _cargarSesionesActivas,
            icon: Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _cargarSesionesActivas,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Cargando sesiones activas...',
              style: GoogleFonts.lato(fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text(
              'Error al cargar sesiones',
              style: GoogleFonts.lato(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: GoogleFonts.lato(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _cargarSesionesActivas,
              child: Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_sesionesActivas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.security, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No hay sesiones activas',
              style: GoogleFonts.lato(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Todos los guardias están desconectados',
              style: GoogleFonts.lato(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        _buildResumenGeneral(),
        SizedBox(height: 24),
        Text(
          'Sesiones Activas (${_sesionesActivas.length})',
          style: GoogleFonts.lato(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 16),
        ..._sesionesActivas.map((sesion) => _buildSesionCard(sesion)),
      ],
    );
  }

  Widget _buildResumenGeneral() {
    final totalSesiones = _sesionesActivas.length;
    final puntoMap = <String, int>{};

    for (final sesion in _sesionesActivas) {
      final punto = sesion['punto_control'] ?? 'Desconocido';
      puntoMap[punto] = (puntoMap[punto] ?? 0) + 1;
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumen General',
              style: GoogleFonts.lato(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Guardias',
                    totalSesiones.toString(),
                    Icons.security,
                    Colors.blue,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Puntos Activos',
                    puntoMap.length.toString(),
                    Icons.location_on,
                    Colors.green,
                  ),
                ),
              ],
            ),
            if (puntoMap.isNotEmpty) ...[
              SizedBox(height: 16),
              Text(
                'Distribución por Punto de Control:',
                style: GoogleFonts.lato(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              ...puntoMap.entries.map(
                (entry) => Padding(
                  padding: EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key, style: GoogleFonts.lato()),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${entry.value} guardia${entry.value > 1 ? 's' : ''}',
                          style: GoogleFonts.lato(
                            fontSize: 12,
                            color: Colors.blue[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
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
        children: [
          Icon(icon, color: color, size: 32),
          SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.lato(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.lato(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSesionCard(Map<String, dynamic> sesion) {
    final guardiaId = sesion['guardia_id'] ?? '';
    final guardiaNombre = sesion['guardia_nombre'] ?? 'Desconocido';
    final puntoControl = sesion['punto_control'] ?? 'Desconocido';
    final fechaInicio =
        DateTime.tryParse(sesion['fecha_inicio'] ?? '') ?? DateTime.now();
    final lastActivity =
        DateTime.tryParse(sesion['last_activity'] ?? '') ?? DateTime.now();

    final tiempoSesion = DateTime.now().difference(fechaInicio);
    final tiempoUltimaActividad = DateTime.now().difference(lastActivity);

    final isRecentActivity = tiempoUltimaActividad.inMinutes < 2;

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      isRecentActivity ? Colors.green[100] : Colors.orange[100],
                  child: Icon(
                    Icons.person,
                    color:
                        isRecentActivity
                            ? Colors.green[700]
                            : Colors.orange[700],
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        guardiaNombre,
                        style: GoogleFonts.lato(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'ID: $guardiaId',
                        style: GoogleFonts.lato(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        isRecentActivity
                            ? Colors.green[100]
                            : Colors.orange[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isRecentActivity ? 'Activo' : 'Inactivo',
                    style: GoogleFonts.lato(
                      fontSize: 12,
                      color:
                          isRecentActivity
                              ? Colors.green[800]
                              : Colors.orange[800],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            _buildDetalleSesion(
              'Punto de Control',
              puntoControl,
              Icons.location_on,
            ),
            _buildDetalleSesion(
              'Duración Sesión',
              _formatearTiempo(tiempoSesion),
              Icons.access_time,
            ),
            _buildDetalleSesion(
              'Última Actividad',
              _formatearTiempo(tiempoUltimaActividad),
              Icons.update,
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _mostrarDetallesSesion(sesion),
                  icon: Icon(Icons.info_outline),
                  label: Text('Detalles'),
                ),
                SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed:
                      () => _forzarFinalizacion(guardiaId, guardiaNombre),
                  icon: Icon(Icons.stop),
                  label: Text('Finalizar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetalleSesion(String label, String valor, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          SizedBox(width: 8),
          Text(
            '$label: ',
            style: GoogleFonts.lato(fontSize: 14, color: Colors.grey[600]),
          ),
          Text(
            valor,
            style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _mostrarDetallesSesion(Map<String, dynamic> sesion) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Detalles de Sesión'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetalleCompleto(
                    'Guardia',
                    sesion['guardia_nombre'] ?? 'N/A',
                  ),
                  _buildDetalleCompleto(
                    'ID Guardia',
                    sesion['guardia_id'] ?? 'N/A',
                  ),
                  _buildDetalleCompleto(
                    'Punto Control',
                    sesion['punto_control'] ?? 'N/A',
                  ),
                  _buildDetalleCompleto(
                    'Token Sesión',
                    sesion['session_token'] ?? 'N/A',
                  ),
                  _buildDetalleCompleto(
                    'Fecha Inicio',
                    sesion['fecha_inicio'] ?? 'N/A',
                  ),
                  _buildDetalleCompleto(
                    'Última Actividad',
                    sesion['last_activity'] ?? 'N/A',
                  ),
                  if (sesion['device_info'] != null) ...[
                    SizedBox(height: 8),
                    Text(
                      'Información del Dispositivo:',
                      style: GoogleFonts.lato(fontWeight: FontWeight.bold),
                    ),
                    _buildDetalleCompleto(
                      'Plataforma',
                      sesion['device_info']['platform'] ?? 'N/A',
                    ),
                    _buildDetalleCompleto(
                      'ID Dispositivo',
                      sesion['device_info']['device_id'] ?? 'N/A',
                    ),
                    _buildDetalleCompleto(
                      'Versión App',
                      sesion['device_info']['app_version'] ?? 'N/A',
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cerrar'),
              ),
            ],
          ),
    );
  }

  Widget _buildDetalleCompleto(String label, String valor) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: GoogleFonts.lato(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(valor, style: GoogleFonts.lato())),
        ],
      ),
    );
  }

  String _formatearTiempo(Duration duration) {
    final horas = duration.inHours;
    final minutos = duration.inMinutes % 60;

    if (horas > 0) {
      return '${horas}h ${minutos}m';
    } else {
      return '${minutos}m';
    }
  }
}
