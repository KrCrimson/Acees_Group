class UsuarioModel {
  final String id;
  final String nombre;
  final String apellido;
  final String dni;
  final String email;
  final String? password;
  final String rango;
  final String estado;
  final String? puertaACargo;
  final String? telefono;
  final DateTime? fechaCreacion;
  final DateTime? fechaActualizacion;

  UsuarioModel({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.dni,
    required this.email,
    this.password,
    required this.rango,
    required this.estado,
    this.puertaACargo,
    this.telefono,
    this.fechaCreacion,
    this.fechaActualizacion,
  });

  factory UsuarioModel.fromJson(Map<String, dynamic> json) {
    return UsuarioModel(
      id: json['_id'] ?? json['id'] ?? '',
      nombre: json['nombre'] ?? '',
      apellido: json['apellido'] ?? '',
      dni: json['dni'] ?? '',
      email: json['email'] ?? '',
      password: json['password'],
      rango: json['rango'] ?? 'guardia',
      estado: json['estado'] ?? 'activo',
      puertaACargo: json['puerta_acargo'],
      telefono: json['telefono'],
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
      '_id': id,
      'nombre': nombre,
      'apellido': apellido,
      'dni': dni,
      'email': email,
      if (password != null) 'password': password,
      'rango': rango,
      'estado': estado,
      if (puertaACargo != null) 'puerta_acargo': puertaACargo,
      if (telefono != null) 'telefono': telefono,
      if (fechaCreacion != null)
        'fecha_creacion': fechaCreacion!.toIso8601String(),
      if (fechaActualizacion != null)
        'fecha_actualizacion': fechaActualizacion!.toIso8601String(),
    };
  }

  String get nombreCompleto => '$nombre $apellido';
  bool get isAdmin => rango == 'admin';
  bool get isActive => estado == 'activo';
}
