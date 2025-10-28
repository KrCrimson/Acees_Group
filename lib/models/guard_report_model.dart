class GuardReportModel {
  final String guardiaId;
  final String guardiaNombre;
  final int totalAsistencias;
  final int entradas;
  final int salidas;
  final int autorizacionesManuales;
  final String puertaMasUsada;
  final String facultadMasAtendida;
  final double promedioDiario;
  final DateTime fechaInicio;
  final DateTime fechaFin;

  GuardReportModel({
    required this.guardiaId,
    required this.guardiaNombre,
    required this.totalAsistencias,
    required this.entradas,
    required this.salidas,
    required this.autorizacionesManuales,
    required this.puertaMasUsada,
    required this.facultadMasAtendida,
    required this.promedioDiario,
    required this.fechaInicio,
    required this.fechaFin,
  });

  factory GuardReportModel.fromMap(Map<String, dynamic> map) {
    return GuardReportModel(
      guardiaId: map['guardiaId'] ?? '',
      guardiaNombre: map['guardiaNombre'] ?? '',
      totalAsistencias: map['totalAsistencias'] ?? 0,
      entradas: map['entradas'] ?? 0,
      salidas: map['salidas'] ?? 0,
      autorizacionesManuales: map['autorizacionesManuales'] ?? 0,
      puertaMasUsada: map['puertaMasUsada'] ?? 'N/A',
      facultadMasAtendida: map['facultadMasAtendida'] ?? 'N/A',
      promedioDiario: (map['promedioDiario'] ?? 0.0).toDouble(),
      fechaInicio: DateTime.parse(map['fechaInicio']),
      fechaFin: DateTime.parse(map['fechaFin']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'guardiaId': guardiaId,
      'guardiaNombre': guardiaNombre,
      'totalAsistencias': totalAsistencias,
      'entradas': entradas,
      'salidas': salidas,
      'autorizacionesManuales': autorizacionesManuales,
      'puertaMasUsada': puertaMasUsada,
      'facultadMasAtendida': facultadMasAtendida,
      'promedioDiario': promedioDiario,
      'fechaInicio': fechaInicio.toIso8601String(),
      'fechaFin': fechaFin.toIso8601String(),
    };
  }

  // Métodos utilitarios
  double get porcentajeAutorizaciones {
    if (totalAsistencias == 0) return 0.0;
    return (autorizacionesManuales / totalAsistencias) * 100;
  }

  String get nivelActividad {
    if (promedioDiario >= 20) return 'Alto';
    if (promedioDiario >= 10) return 'Medio';
    if (promedioDiario >= 5) return 'Bajo';
    return 'Muy Bajo';
  }

  String get nivelAutorizaciones {
    if (porcentajeAutorizaciones >= 20) return 'Alto';
    if (porcentajeAutorizaciones >= 10) return 'Medio';
    if (porcentajeAutorizaciones >= 5) return 'Bajo';
    return 'Muy Bajo';
  }

  String get resumenActividad {
    return '${totalAsistencias} asistencias (${entradas} entradas, ${salidas} salidas)';
  }

  String get resumenAutorizaciones {
    return '$autorizacionesManuales autorizaciones (${porcentajeAutorizaciones.toStringAsFixed(1)}%)';
  }
}

class GuardActivitySummaryModel {
  final int totalAsistencias;
  final int guardiasActivos;
  final int autorizacionesManuales;
  final String puertaMasUsada;
  final String facultadMasAtendida;
  final double promedioDiario;
  final DateTime fechaInicio;
  final DateTime fechaFin;

  GuardActivitySummaryModel({
    required this.totalAsistencias,
    required this.guardiasActivos,
    required this.autorizacionesManuales,
    required this.puertaMasUsada,
    required this.facultadMasAtendida,
    required this.promedioDiario,
    required this.fechaInicio,
    required this.fechaFin,
  });

  factory GuardActivitySummaryModel.fromMap(Map<String, dynamic> map) {
    return GuardActivitySummaryModel(
      totalAsistencias: map['totalAsistencias'] ?? 0,
      guardiasActivos: map['guardiasActivos'] ?? 0,
      autorizacionesManuales: map['autorizacionesManuales'] ?? 0,
      puertaMasUsada: map['puertaMasUsada'] ?? 'N/A',
      facultadMasAtendida: map['facultadMasAtendida'] ?? 'N/A',
      promedioDiario: (map['promedioDiario'] ?? 0.0).toDouble(),
      fechaInicio: DateTime.parse(map['fechaInicio']),
      fechaFin: DateTime.parse(map['fechaFin']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalAsistencias': totalAsistencias,
      'guardiasActivos': guardiasActivos,
      'autorizacionesManuales': autorizacionesManuales,
      'puertaMasUsada': puertaMasUsada,
      'facultadMasAtendida': facultadMasAtendida,
      'promedioDiario': promedioDiario,
      'fechaInicio': fechaInicio.toIso8601String(),
      'fechaFin': fechaFin.toIso8601String(),
    };
  }

  double get porcentajeAutorizaciones {
    if (totalAsistencias == 0) return 0.0;
    return (autorizacionesManuales / totalAsistencias) * 100;
  }

  String get resumenPeriodo {
    final dias = fechaFin.difference(fechaInicio).inDays + 1;
    return '${dias} días (${fechaInicio.day}/${fechaInicio.month} - ${fechaFin.day}/${fechaFin.month})';
  }
}
