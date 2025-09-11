class FacultadModel {
  final String id;
  final String siglas;
  final String nombre;

  FacultadModel({required this.id, required this.siglas, required this.nombre});

  factory FacultadModel.fromJson(Map<String, dynamic> json) {
    return FacultadModel(
      id: json['_id'] ?? '',
      siglas: json['siglas'] ?? '',
      nombre: json['nombre'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'_id': id, 'siglas': siglas, 'nombre': nombre};
  }
}

class EscuelaModel {
  final String id;
  final String nombre;
  final String siglas;
  final String siglasFacultad;

  EscuelaModel({
    required this.id,
    required this.nombre,
    required this.siglas,
    required this.siglasFacultad,
  });

  factory EscuelaModel.fromJson(Map<String, dynamic> json) {
    return EscuelaModel(
      id: json['_id'] ?? '',
      nombre: json['nombre'] ?? '',
      siglas: json['siglas'] ?? '',
      siglasFacultad: json['siglas_facultad'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'nombre': nombre,
      'siglas': siglas,
      'siglas_facultad': siglasFacultad,
    };
  }
}
