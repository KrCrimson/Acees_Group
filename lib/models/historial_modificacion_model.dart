class HistorialModificacionModel {
  final String id;
  final String entidadId;
  final String tipoEntidad; // 'usuario', 'punto_control', etc.
  final String accion; // 'crear', 'modificar', 'activar', 'desactivar'
  final String adminId;
  final String adminNombre;
  final Map<String, dynamic> cambiosRealizados;
  final String? descripcion;
  final DateTime fechaModificacion;

  HistorialModificacionModel({
    required this.id,
    required this.entidadId,
    required this.tipoEntidad,
    required this.accion,
    required this.adminId,
    required this.adminNombre,
    required this.cambiosRealizados,
    this.descripcion,
    required this.fechaModificacion,
  });

  factory HistorialModificacionModel.fromJson(Map<String, dynamic> json) {
    return HistorialModificacionModel(
      id: json['_id'] ?? json['id'] ?? '',
      entidadId: json['entidad_id'] ?? '',
      tipoEntidad: json['tipo_entidad'] ?? '',
      accion: json['accion'] ?? '',
      adminId: json['admin_id'] ?? '',
      adminNombre: json['admin_nombre'] ?? '',
      cambiosRealizados: Map<String, dynamic>.from(
        json['cambios_realizados'] ?? {},
      ),
      descripcion: json['descripcion'],
      fechaModificacion: DateTime.parse(json['fecha_modificacion']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id.isEmpty ? null : id,
      'entidad_id': entidadId,
      'tipo_entidad': tipoEntidad,
      'accion': accion,
      'admin_id': adminId,
      'admin_nombre': adminNombre,
      'cambios_realizados': cambiosRealizados,
      'descripcion': descripcion,
      'fecha_modificacion': fechaModificacion.toIso8601String(),
    };
  }

  // Getters útiles
  String get accionDisplay {
    switch (accion.toLowerCase()) {
      case 'crear':
        return '➕ Creado';
      case 'modificar':
        return '✏️ Modificado';
      case 'activar':
        return '✅ Activado';
      case 'desactivar':
        return '❌ Desactivado';
      case 'asignar':
        return '📍 Asignado';
      case 'desasignar':
        return '🚫 Desasignado';
      default:
        return '📝 $accion';
    }
  }

  String get tipoEntidadDisplay {
    switch (tipoEntidad.toLowerCase()) {
      case 'usuario':
        return '👤 Usuario';
      case 'punto_control':
        return '🏢 Punto de Control';
      case 'asistencia':
        return '📅 Asistencia';
      default:
        return tipoEntidad;
    }
  }

  String get fechaFormateada {
    return '${fechaModificacion.day}/${fechaModificacion.month}/${fechaModificacion.year} ${fechaModificacion.hour}:${fechaModificacion.minute.toString().padLeft(2, '0')}';
  }

  String get resumenCambios {
    if (cambiosRealizados.isEmpty) return 'Sin cambios específicos';

    List<String> cambios = [];
    cambiosRealizados.forEach((campo, valor) {
      if (campo == 'password') {
        cambios.add('Contraseña actualizada');
      } else {
        cambios.add('$campo: $valor');
      }
    });

    return cambios.join(', ');
  }
}
