class AlumnoModel {
  final String id;
  final String identificacion;
  final String nombre;
  final String apellido;
  final String dni;
  final String codigoUniversitario;
  final String escuelaProfesional;
  final String facultad;
  final String siglasEscuela;
  final String siglasFacultad;
  final bool estado;

  AlumnoModel({
    required this.id,
    required this.identificacion,
    required this.nombre,
    required this.apellido,
    required this.dni,
    required this.codigoUniversitario,
    required this.escuelaProfesional,
    required this.facultad,
    required this.siglasEscuela,
    required this.siglasFacultad,
    required this.estado,
  });

  factory AlumnoModel.fromJson(Map<String, dynamic> json) {
    return AlumnoModel(
      id: json['_id'] ?? '',
      identificacion: json['_identificacion'] ?? '',
      nombre: json['nombre'] ?? '',
      apellido: json['apellido'] ?? '',
      dni: json['dni'] ?? '',
      codigoUniversitario: json['codigo_universitario'] ?? '',
      escuelaProfesional: json['escuela_profesional'] ?? '',
      facultad: json['facultad'] ?? '',
      siglasEscuela: json['siglas_escuela'] ?? '',
      siglasFacultad: json['siglas_facultad'] ?? '',
      estado: json['estado'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      '_identificacion': identificacion,
      'nombre': nombre,
      'apellido': apellido,
      'dni': dni,
      'codigo_universitario': codigoUniversitario,
      'escuela_profesional': escuelaProfesional,
      'facultad': facultad,
      'siglas_escuela': siglasEscuela,
      'siglas_facultad': siglasFacultad,
      'estado': estado,
    };
  }

  String get nombreCompleto => '$nombre $apellido';
  bool get isActive => estado;
}
