class PresenciaModel {
  final String id;
  final String estudianteId;
  final String estudianteDni;
  final String estudianteNombre;
  final String facultad;
  final String escuela;
  final DateTime horaEntrada;
  final DateTime? horaSalida;
  final String puntoEntrada;
  final String? puntoSalida;
  final bool estaDentro;
  final String guardiaEntrada;
  final String? guardiaSalida;
  final Duration? tiempoEnCampus;

  PresenciaModel({
    required this.id,
    required this.estudianteId,
    required this.estudianteDni,
    required this.estudianteNombre,
    required this.facultad,
    required this.escuela,
    required this.horaEntrada,
    this.horaSalida,
    required this.puntoEntrada,
    this.puntoSalida,
    required this.estaDentro,
    required this.guardiaEntrada,
    this.guardiaSalida,
    this.tiempoEnCampus,
  });

  factory PresenciaModel.fromJson(Map<String, dynamic> json) {
    return PresenciaModel(
      id: json['_id'] ?? '',
      estudianteId: json['estudiante_id'] ?? '',
      estudianteDni: json['estudiante_dni'] ?? '',
      estudianteNombre: json['estudiante_nombre'] ?? '',
      facultad: json['facultad'] ?? '',
      escuela: json['escuela'] ?? '',
      horaEntrada: DateTime.parse(json['hora_entrada']),
      horaSalida:
          json['hora_salida'] != null
              ? DateTime.parse(json['hora_salida'])
              : null,
      puntoEntrada: json['punto_entrada'] ?? '',
      puntoSalida: json['punto_salida'],
      estaDentro: json['esta_dentro'] ?? true,
      guardiaEntrada: json['guardia_entrada'] ?? '',
      guardiaSalida: json['guardia_salida'],
      tiempoEnCampus:
          json['tiempo_en_campus'] != null
              ? Duration(milliseconds: json['tiempo_en_campus'])
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'estudiante_id': estudianteId,
      'estudiante_dni': estudianteDni,
      'estudiante_nombre': estudianteNombre,
      'facultad': facultad,
      'escuela': escuela,
      'hora_entrada': horaEntrada.toIso8601String(),
      'hora_salida': horaSalida?.toIso8601String(),
      'punto_entrada': puntoEntrada,
      'punto_salida': puntoSalida,
      'esta_dentro': estaDentro,
      'guardia_entrada': guardiaEntrada,
      'guardia_salida': guardiaSalida,
      'tiempo_en_campus': tiempoEnCampus?.inMilliseconds,
    };
  }

  // Métodos utilitarios
  Duration get tiempoActualEnCampus {
    if (horaSalida != null) {
      return horaSalida!.difference(horaEntrada);
    }
    return DateTime.now().difference(horaEntrada);
  }

  String get tiempoFormateado {
    final duracion = tiempoActualEnCampus;
    final horas = duracion.inHours;
    final minutos = duracion.inMinutes.remainder(60);
    return '${horas}h ${minutos}m';
  }

  bool get llevaVariasHoras => tiempoActualEnCampus.inHours >= 8;

  String get statusPresencia {
    if (!estaDentro) return 'Salió del campus';
    if (llevaVariasHoras) return 'Lleva mucho tiempo en campus';
    return 'En campus';
  }
}
