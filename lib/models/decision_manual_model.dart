class DecisionManualModel {
  final String id;
  final String estudianteId;
  final String estudianteDni;
  final String estudianteNombre;
  final String guardiaId;
  final String guardiaNombre;
  final bool autorizado;
  final String razon;
  final DateTime timestamp;
  final String puntoControl;
  final String tipoAcceso; // 'entrada' o 'salida'
  final Map<String, dynamic>? datosEstudiante;

  DecisionManualModel({
    required this.id,
    required this.estudianteId,
    required this.estudianteDni,
    required this.estudianteNombre,
    required this.guardiaId,
    required this.guardiaNombre,
    required this.autorizado,
    required this.razon,
    required this.timestamp,
    required this.puntoControl,
    required this.tipoAcceso,
    this.datosEstudiante,
  });

  factory DecisionManualModel.fromJson(Map<String, dynamic> json) {
    return DecisionManualModel(
      id: json['_id'] ?? '',
      estudianteId: json['estudiante_id'] ?? '',
      estudianteDni: json['estudiante_dni'] ?? '',
      estudianteNombre: json['estudiante_nombre'] ?? '',
      guardiaId: json['guardia_id'] ?? '',
      guardiaNombre: json['guardia_nombre'] ?? '',
      autorizado: json['autorizado'] ?? false,
      razon: json['razon'] ?? '',
      timestamp: DateTime.parse(json['timestamp']),
      puntoControl: json['punto_control'] ?? '',
      tipoAcceso: json['tipo_acceso'] ?? 'entrada',
      datosEstudiante: json['datos_estudiante'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'estudiante_id': estudianteId,
      'estudiante_dni': estudianteDni,
      'estudiante_nombre': estudianteNombre,
      'guardia_id': guardiaId,
      'guardia_nombre': guardiaNombre,
      'autorizado': autorizado,
      'razon': razon,
      'timestamp': timestamp.toIso8601String(),
      'punto_control': puntoControl,
      'tipo_acceso': tipoAcceso,
      'datos_estudiante': datosEstudiante,
    };
  }

  // Métodos utilitarios
  bool get isAutorizado => autorizado;
  bool get isDenegado => !autorizado;
  String get statusText => autorizado ? 'AUTORIZADO' : 'DENEGADO';
  String get tiempoTranscurrido {
    final ahora = DateTime.now();
    final diferencia = ahora.difference(timestamp);

    if (diferencia.inMinutes < 1) {
      return 'Hace ${diferencia.inSeconds} segundos';
    } else if (diferencia.inHours < 1) {
      return 'Hace ${diferencia.inMinutes} minutos';
    } else if (diferencia.inDays < 1) {
      return 'Hace ${diferencia.inHours} horas';
    } else {
      return 'Hace ${diferencia.inDays} días';
    }
  }
}
