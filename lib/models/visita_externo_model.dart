class VisitaModel {
  final String id;
  final String puerta;
  final String guardiaNombre;
  final String asunto;
  final DateTime fechaHora;
  final String nombre;
  final String dni;
  final String facultad;

  VisitaModel({
    required this.id,
    required this.puerta,
    required this.guardiaNombre,
    required this.asunto,
    required this.fechaHora,
    required this.nombre,
    required this.dni,
    required this.facultad,
  });

  factory VisitaModel.fromJson(Map<String, dynamic> json) {
    return VisitaModel(
      id: json['_id'] ?? '',
      puerta: json['puerta'] ?? '',
      guardiaNombre: json['guardia_nombre'] ?? '',
      asunto: json['asunto'] ?? '',
      fechaHora: DateTime.parse(json['fecha_hora']),
      nombre: json['nombre'] ?? '',
      dni: json['dni'] ?? '',
      facultad: json['facultad'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'puerta': puerta,
      'guardia_nombre': guardiaNombre,
      'asunto': asunto,
      'fecha_hora': fechaHora.toIso8601String(),
      'nombre': nombre,
      'dni': dni,
      'facultad': facultad,
    };
  }

  String get fechaFormateada =>
      '${fechaHora.day}/${fechaHora.month}/${fechaHora.year} ${fechaHora.hour}:${fechaHora.minute.toString().padLeft(2, '0')}';
}

class ExternoModel {
  final String id;
  final String nombre;
  final String dni;

  ExternoModel({required this.id, required this.nombre, required this.dni});

  factory ExternoModel.fromJson(Map<String, dynamic> json) {
    return ExternoModel(
      id: json['_id'] ?? '',
      nombre: json['nombre'] ?? '',
      dni: json['dni'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'_id': id, 'nombre': nombre, 'dni': dni};
  }
}
