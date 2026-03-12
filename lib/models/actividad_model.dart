class ActividadModel {
  final String id;
  final String guardiaId;
  final String guardiaNombre;
  final String puntoControl;
  final DateTime fecha;
  final String tipoActividad;
  final int? duracionSesion;
  final String? estudianteDni;
  final ContadoresModel contadores;
  final MetricasModel metricas;
  final String? sessionToken;
  final DateTime timestamp;

  ActividadModel({
    required this.id,
    required this.guardiaId,
    required this.guardiaNombre,
    required this.puntoControl,
    required this.fecha,
    required this.tipoActividad,
    this.duracionSesion,
    this.estudianteDni,
    required this.contadores,
    required this.metricas,
    this.sessionToken,
    required this.timestamp,
  });

  factory ActividadModel.fromJson(Map<String, dynamic> json) {
    return ActividadModel(
      id: json['_id'] ?? json['id'] ?? '',
      guardiaId: json['guardia_id'] ?? '',
      guardiaNombre: json['guardia_nombre'] ?? '',
      puntoControl: json['punto_control'] ?? '',
      fecha: DateTime.parse(json['fecha']),
      tipoActividad: json['tipo_actividad'] ?? '',
      duracionSesion: json['duracion_sesion'],
      estudianteDni: json['estudiante_dni'],
      contadores: ContadoresModel.fromJson(json['contadores'] ?? {}),
      metricas: MetricasModel.fromJson(json['metricas'] ?? {}),
      sessionToken: json['session_token'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'guardia_id': guardiaId,
      'guardia_nombre': guardiaNombre,
      'punto_control': puntoControl,
      'fecha': fecha.toIso8601String(),
      'tipo_actividad': tipoActividad,
      'duracion_sesion': duracionSesion,
      'estudiante_dni': estudianteDni,
      'contadores': contadores.toJson(),
      'metricas': metricas.toJson(),
      'session_token': sessionToken,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  // Getters útiles
  String get tipoActividadDisplay {
    switch (tipoActividad) {
      case 'sesion_iniciada':
        return '✅ Inició sesión';
      case 'sesion_finalizada':
        return '❌ Finalizó sesión';
      case 'sesion_forzada_cierre':
        return '🔴 Sesión cerrada por admin';
      case 'registro_entrada':
        return '📱 Registro de entrada';
      case 'registro_salida':
        return '📱 Registro de salida';
      case 'autorizacion_manual':
        return '✅ Autorización manual';
      case 'denegacion_acceso':
        return '❌ Accesso denegado';
      default:
        return tipoActividad;
    }
  }

  String get fechaFormateada {
    return '${fecha.day}/${fecha.month}/${fecha.year} ${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}';
  }

  String get horaFormateada {
    return '${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}';
  }

  String get duracionFormateada {
    if (duracionSesion == null) return '';
    final horas = duracionSesion! ~/ 60;
    final minutos = duracionSesion! % 60;
    if (horas > 0) {
      return '${horas}h ${minutos}min';
    }
    return '${minutos}min';
  }
}

class ContadoresModel {
  final int totalRegistros;
  final int entradas;
  final int salidas;
  final int autorizacionesManuales;
  final int denegaciones;

  ContadoresModel({
    required this.totalRegistros,
    required this.entradas,
    required this.salidas,
    required this.autorizacionesManuales,
    required this.denegaciones,
  });

  factory ContadoresModel.fromJson(Map<String, dynamic> json) {
    return ContadoresModel(
      totalRegistros: json['total_registros'] ?? 0,
      entradas: json['entradas'] ?? 0,
      salidas: json['salidas'] ?? 0,
      autorizacionesManuales: json['autorizaciones_manuales'] ?? 0,
      denegaciones: json['denegaciones'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_registros': totalRegistros,
      'entradas': entradas,
      'salidas': salidas,
      'autorizaciones_manuales': autorizacionesManuales,
      'denegaciones': denegaciones,
    };
  }
}

class MetricasModel {
  final double registrosPorHora;
  final int tiempoActividadTotal;

  MetricasModel({
    required this.registrosPorHora,
    required this.tiempoActividadTotal,
  });

  factory MetricasModel.fromJson(Map<String, dynamic> json) {
    return MetricasModel(
      registrosPorHora: (json['registros_por_hora'] ?? 0).toDouble(),
      tiempoActividadTotal: json['tiempo_actividad_total'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'registros_por_hora': registrosPorHora,
      'tiempo_actividad_total': tiempoActividadTotal,
    };
  }

  String get tiempoFormateado {
    final horas = tiempoActividadTotal ~/ 60;
    final minutos = tiempoActividadTotal % 60;
    if (horas > 0) {
      return '${horas}h ${minutos}min';
    }
    return '${minutos}min';
  }
}

// Modelo para resumen de productividad
class ProductividadModel {
  final int periodoDias;
  final int totalSesiones;
  final double horasTrabajadas;
  final int totalRegistros;
  final double registrosPorHora;
  final int autorizacionesManuales;
  final int denegaciones;
  final int promedioSesionMinutos;
  final int diasActivos;

  ProductividadModel({
    required this.periodoDias,
    required this.totalSesiones,
    required this.horasTrabajadas,
    required this.totalRegistros,
    required this.registrosPorHora,
    required this.autorizacionesManuales,
    required this.denegaciones,
    required this.promedioSesionMinutos,
    required this.diasActivos,
  });

  factory ProductividadModel.fromJson(Map<String, dynamic> json) {
    return ProductividadModel(
      periodoDias: json['periodo_dias'] ?? 0,
      totalSesiones: json['total_sesiones'] ?? 0,
      horasTrabajadas: (json['horas_trabajadas'] ?? 0).toDouble(),
      totalRegistros: json['total_registros'] ?? 0,
      registrosPorHora: (json['registros_por_hora'] ?? 0).toDouble(),
      autorizacionesManuales: json['autorizaciones_manuales'] ?? 0,
      denegaciones: json['denegaciones'] ?? 0,
      promedioSesionMinutos: json['promedio_sesion_minutos'] ?? 0,
      diasActivos: json['dias_activos'] ?? 0,
    );
  }
}

// Modelo para estadísticas comparativas
class EstadisticasGuardiaModel {
  final String guardiaId;
  final String guardiaNombre;
  final int totalSesiones;
  final double horasTrabajadas;
  final int totalRegistros;
  final int autorizacionesManuales;
  final int denegaciones;
  final double registrosPorHora;
  final int diasActivos;

  EstadisticasGuardiaModel({
    required this.guardiaId,
    required this.guardiaNombre,
    required this.totalSesiones,
    required this.horasTrabajadas,
    required this.totalRegistros,
    required this.autorizacionesManuales,
    required this.denegaciones,
    required this.registrosPorHora,
    required this.diasActivos,
  });

  factory EstadisticasGuardiaModel.fromJson(Map<String, dynamic> json) {
    return EstadisticasGuardiaModel(
      guardiaId: json['guardia_id'] ?? '',
      guardiaNombre: json['guardia_nombre'] ?? '',
      totalSesiones: json['total_sesiones'] ?? 0,
      horasTrabajadas: (json['horas_trabajadas'] ?? 0).toDouble(),
      totalRegistros: json['total_registros'] ?? 0,
      autorizacionesManuales: json['autorizaciones_manuales'] ?? 0,
      denegaciones: json['denegaciones'] ?? 0,
      registrosPorHora: (json['registros_por_hora'] ?? 0).toDouble(),
      diasActivos: json['dias_activos'] ?? 0,
    );
  }
}