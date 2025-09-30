class PuntoControlModel {
  final String id;
  final String nombre;
  final String codigo;
  final String ubicacion;
  final String descripcion;
  final bool activo;
  final List<String> guardiasAsignados;
  final DateTime? fechaCreacion;
  final DateTime? fechaActualizacion;

  PuntoControlModel({
    required this.id,
    required this.nombre,
    required this.codigo,
    required this.ubicacion,
    required this.descripcion,
    required this.activo,
    required this.guardiasAsignados,
    this.fechaCreacion,
    this.fechaActualizacion,
  });

  factory PuntoControlModel.fromJson(Map<String, dynamic> json) {
    return PuntoControlModel(
      id: json['_id'] ?? json['id'] ?? '',
      nombre: json['nombre'] ?? '',
      codigo: json['codigo'] ?? '',
      ubicacion: json['ubicacion'] ?? '',
      descripcion: json['descripcion'] ?? '',
      activo: json['activo'] ?? true,
      guardiasAsignados: List<String>.from(json['guardias_asignados'] ?? []),
      fechaCreacion:
          json['fecha_creacion'] != null
              ? DateTime.parse(json['fecha_creacion'])
              : null,
      fechaActualizacion:
          json['fecha_actualizacion'] != null
              ? DateTime.parse(json['fecha_actualizacion'])
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id.isEmpty ? null : id,
      'nombre': nombre,
      'codigo': codigo,
      'ubicacion': ubicacion,
      'descripcion': descripcion,
      'activo': activo,
      'guardias_asignados': guardiasAsignados,
      'fecha_creacion': fechaCreacion?.toIso8601String(),
      'fecha_actualizacion': fechaActualizacion?.toIso8601String(),
    };
  }

  // Getters útiles
  String get displayName => '$nombre ($codigo)';
  bool get tieneGuardias => guardiasAsignados.isNotEmpty;
  int get cantidadGuardias => guardiasAsignados.length;

  // Método para copiar con cambios
  PuntoControlModel copyWith({
    String? id,
    String? nombre,
    String? codigo,
    String? ubicacion,
    String? descripcion,
    bool? activo,
    List<String>? guardiasAsignados,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
  }) {
    return PuntoControlModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      codigo: codigo ?? this.codigo,
      ubicacion: ubicacion ?? this.ubicacion,
      descripcion: descripcion ?? this.descripcion,
      activo: activo ?? this.activo,
      guardiasAsignados: guardiasAsignados ?? this.guardiasAsignados,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
    );
  }
}
