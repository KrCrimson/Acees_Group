class ExternoModel {
  final String? id;
  final String nombreCompleto;
  final String dni;
  final String razon;
  final String tipo; // 'entrada' o 'salida'
  final String estado; // 'autorizado'
  final String? descripcionUbicacion;
  final String guardiaId;
  final String guardiaNombre;
  final DateTime? fechaHora;

  ExternoModel({
    this.id,
    required this.nombreCompleto,
    required this.dni,
    required this.razon,
    this.tipo = 'entrada',
    this.estado = 'autorizado',
    this.descripcionUbicacion,
    required this.guardiaId,
    required this.guardiaNombre,
    this.fechaHora,
  });

  factory ExternoModel.fromJson(Map<String, dynamic> json) {
    return ExternoModel(
      id: json['_id'],
      nombreCompleto: json['nombre_completo'] ?? '',
      dni: json['dni'] ?? '',
      razon: json['razon'] ?? '',
      tipo: json['tipo'] ?? 'entrada',
      estado: json['estado'] ?? 'autorizado',
      descripcionUbicacion: json['descripcion_ubicacion'],
      guardiaId: json['guardia_id'] ?? '',
      guardiaNombre: json['guardia_nombre'] ?? '',
      fechaHora: json['fecha_hora'] != null ? DateTime.parse(json['fecha_hora']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre_completo': nombreCompleto,
      'dni': dni,
      'razon': razon,
      'tipo': tipo,
      'estado': estado,
      'descripcion_ubicacion': descripcionUbicacion,
      'guardia_id': guardiaId,
      'guardia_nombre': guardiaNombre,
      // fecha_hora se genera en backend
    };
  }
}
