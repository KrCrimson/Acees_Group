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
    };
  }

  String get nombreCompleto => '$nombre $apellido';
  String get fechaFormateada =>
      '${fechaHora.day}/${fechaHora.month}/${fechaHora.year} ${fechaHora.hour}:${fechaHora.minute.toString().padLeft(2, '0')}';
}
