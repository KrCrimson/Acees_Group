class AsistenciaModel {
  final String id;
  final String nombre;
  final String apellido;
  final String dni;
  final String codigoUniversitario;
  final String siglasFacultad;
  final String siglasEscuela;
  final String tipo;
  final DateTime fechaHora;
  final String entradaTipo;
  final String puerta;
  // Nuevos campos para US025-US030
  final String? guardiaId;
  final String? guardiaNombre;
  final bool? autorizacionManual;
  final String? razonDecision;
  final DateTime? timestampDecision;
  final String? coordenadas;
  final String? descripcionUbicacion;

  AsistenciaModel({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.dni,
    required this.codigoUniversitario,
    required this.siglasFacultad,
    required this.siglasEscuela,
    required this.tipo,
    required this.fechaHora,
    required this.entradaTipo,
    required this.puerta,
    this.guardiaId,
    this.guardiaNombre,
    this.autorizacionManual,
    this.razonDecision,
    this.timestampDecision,
    this.coordenadas,
    this.descripcionUbicacion,
  });

  factory AsistenciaModel.fromJson(Map<String, dynamic> json) {
    return AsistenciaModel(
      id: json['_id'] ?? '',
      nombre: json['nombre'] ?? '',
      apellido: json['apellido'] ?? '',
      dni: json['dni'] ?? '',
      codigoUniversitario: json['codigo_universitario'] ?? '',
      siglasFacultad: json['siglas_facultad'] ?? '',
      siglasEscuela: json['siglas_escuela'] ?? '',
      tipo: json['tipo'] ?? '',
      fechaHora: DateTime.parse(json['fecha_hora']),
      entradaTipo: json['entrada_tipo'] ?? '',
      puerta: json['puerta'] ?? '',
      guardiaId: json['guardia_id'],
      guardiaNombre: json['guardia_nombre'],
      autorizacionManual: json['autorizacion_manual'],
      razonDecision: json['razon_decision'],
      timestampDecision:
          json['timestamp_decision'] != null
              ? DateTime.parse(json['timestamp_decision'])
              : null,
      coordenadas: json['coordenadas'],
      descripcionUbicacion: json['descripcion_ubicacion'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'nombre': nombre,
      'apellido': apellido,
      'dni': dni,
      'codigo_universitario': codigoUniversitario,
      'siglas_facultad': siglasFacultad,
      'siglas_escuela': siglasEscuela,
      'tipo': tipo,
      'fecha_hora': fechaHora.toIso8601String(),
      'entrada_tipo': entradaTipo,
      'puerta': puerta,
      'guardia_id': guardiaId,
      'guardia_nombre': guardiaNombre,
      'autorizacion_manual': autorizacionManual,
      'razon_decision': razonDecision,
      'timestamp_decision': timestampDecision?.toIso8601String(),
      'coordenadas': coordenadas,
      'descripcion_ubicacion': descripcionUbicacion,
    };
  }

  String get nombreCompleto => '$nombre $apellido';
  String get fechaFormateada =>
      '${fechaHora.day}/${fechaHora.month}/${fechaHora.year} ${fechaHora.hour}:${fechaHora.minute.toString().padLeft(2, '0')}';
}
