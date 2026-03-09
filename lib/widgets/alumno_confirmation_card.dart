import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../services/photo_service.dart';

class AlumnoConfirmationCard extends StatelessWidget {
  final Map<String, dynamic> alumnoData;
  final String tipoAcceso; // 'entrada' o 'salida'

  const AlumnoConfirmationCard({
    Key? key,
    required this.alumnoData,
    required this.tipoAcceso,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isEntrada = tipoAcceso.toLowerCase() == 'entrada';
    final primaryColor = isEntrada ? Colors.green : Colors.orange;
    final backgroundColor = isEntrada ? Colors.green[50] : Colors.orange[50];
    final nombreCompleto =
        '${alumnoData['nombre'] ?? ''} ${alumnoData['apellido'] ?? ''}';

    return Card(
      elevation: 12,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              backgroundColor!,
              Colors.white,
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // TÍTULO CON ANIMACIÓN
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: primaryColor, width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isEntrada ? Icons.login_rounded : Icons.logout_rounded,
                    color: primaryColor,
                    size: 28,
                  ),
                  SizedBox(width: 8),
                  Text(
                    isEntrada ? 'ENTRADA REGISTRADA' : 'SALIDA REGISTRADA',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),

            // CONTENIDO PRINCIPAL
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // FOTO DEL ALUMNO
                _buildPhotoSection(nombreCompleto, primaryColor),

                SizedBox(width: 20),

                // INFORMACIÓN DEL ALUMNO
                Expanded(
                  child: _buildInfoSection(nombreCompleto, primaryColor),
                ),
              ],
            ),

            SizedBox(height: 20),

            // FECHA Y HORA
            _buildTimeSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection(String nombreCompleto, Color primaryColor) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(60),
        border: Border.all(color: primaryColor, width: 4),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(60),
        child: CachedNetworkImage(
          imageUrl: PhotoService.getAlumnoPhotoUrl(alumnoData['DNI']),
          fit: BoxFit.cover,

          // Mientras carga la foto
          placeholder: (context, url) => Container(
            color: Colors.grey[100],
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Cargando...',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Si no hay foto - mostrar iniciales con color
          errorWidget: (context, url, error) => Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(PhotoService.getColorForName(nombreCompleto)),
                  Color(PhotoService.getColorForName(nombreCompleto))
                      .withOpacity(0.8),
                ],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    PhotoService.getInitials(nombreCompleto),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          offset: Offset(1, 1),
                          blurRadius: 2,
                          color: Colors.black.withOpacity(0.3),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Sin foto',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(String nombreCompleto, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Nombre del alumno
        Text(
          nombreCompleto,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
            height: 1.2,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),

        SizedBox(height: 12),

        // Información detallada
        _buildInfoRow(Icons.badge_outlined, 'DNI',
            alumnoData['DNI']?.toString() ?? 'N/A'),
        _buildInfoRow(Icons.school_outlined, 'Código',
            alumnoData['código_universitario']?.toString() ?? 'N/A'),
        _buildInfoRow(Icons.account_balance_outlined, 'Facultad',
            alumnoData['siglas_facultad']?.toString() ?? 'N/A'),
        _buildInfoRow(Icons.class_outlined, 'Escuela',
            alumnoData['siglas_escuela']?.toString() ?? 'N/A'),

        // Estado adicional si existe
        if (alumnoData['estado'] != null)
          _buildStatusChip(alumnoData['estado'].toString(), primaryColor),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.grey[600],
          ),
          SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String estado, Color primaryColor) {
    final isActive =
        estado.toLowerCase() == 'verdadero' || estado.toLowerCase() == 'activo';

    return Container(
      margin: EdgeInsets.only(top: 8),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? Colors.green[100] : Colors.red[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Text(
        isActive ? 'ACTIVO' : 'INACTIVO',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isActive ? Colors.green[800] : Colors.red[800],
        ),
      ),
    );
  }

  Widget _buildTimeSection() {
    final now = DateTime.now();
    final dateFormat = DateFormat('EEEE, dd MMMM yyyy', 'es_ES');
    final timeFormat = DateFormat('HH:mm:ss');

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.access_time_rounded,
                color: Colors.grey[600],
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                timeFormat.format(now),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            dateFormat.format(now),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
