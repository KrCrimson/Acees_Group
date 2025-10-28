class MatriculationModel {
  final String id;
  final String estudianteId;
  final String codigoUniversitario;
  final String nombreCompleto;
  final String cicloAcademico;
  final String anioAcademico;
  final DateTime fechaMatriculacion;
  final DateTime fechaVencimiento;
  final String estadoMatricula;
  final String tipoMatricula;
  final double montoMatricula;
  final bool pagoCompleto;
  final DateTime? fechaPago;
  final String? numeroComprobante;
  final String? observaciones;
  final DateTime fechaCreacion;
  final DateTime fechaActualizacion;
  final bool activa;

  MatriculationModel({
    required this.id,
    required this.estudianteId,
    required this.codigoUniversitario,
    required this.nombreCompleto,
    required this.cicloAcademico,
    required this.anioAcademico,
    required this.fechaMatriculacion,
    required this.fechaVencimiento,
    required this.estadoMatricula,
    required this.tipoMatricula,
    required this.montoMatricula,
    required this.pagoCompleto,
    this.fechaPago,
    this.numeroComprobante,
    this.observaciones,
    required this.fechaCreacion,
    required this.fechaActualizacion,
    required this.activa,
  });

  factory MatriculationModel.fromJson(Map<String, dynamic> json) {
    return MatriculationModel(
      id: json['_id'] ?? '',
      estudianteId: json['estudiante_id'] ?? '',
      codigoUniversitario: json['codigo_universitario'] ?? '',
      nombreCompleto: json['nombre_completo'] ?? '',
      cicloAcademico: json['ciclo_academico'] ?? '',
      anioAcademico: json['anio_academico'] ?? '',
      fechaMatriculacion: DateTime.parse(json['fecha_matriculacion']),
      fechaVencimiento: DateTime.parse(json['fecha_vencimiento']),
      estadoMatricula: json['estado_matricula'] ?? '',
      tipoMatricula: json['tipo_matricula'] ?? '',
      montoMatricula: (json['monto_matricula'] ?? 0.0).toDouble(),
      pagoCompleto: json['pago_completo'] ?? false,
      fechaPago: json['fecha_pago'] != null 
          ? DateTime.parse(json['fecha_pago']) 
          : null,
      numeroComprobante: json['numero_comprobante'],
      observaciones: json['observaciones'],
      fechaCreacion: DateTime.parse(json['fecha_creacion']),
      fechaActualizacion: DateTime.parse(json['fecha_actualizacion']),
      activa: json['activa'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'estudiante_id': estudianteId,
      'codigo_universitario': codigoUniversitario,
      'nombre_completo': nombreCompleto,
      'ciclo_academico': cicloAcademico,
      'anio_academico': anioAcademico,
      'fecha_matriculacion': fechaMatriculacion.toIso8601String(),
      'fecha_vencimiento': fechaVencimiento.toIso8601String(),
      'estado_matricula': estadoMatricula,
      'tipo_matricula': tipoMatricula,
      'monto_matricula': montoMatricula,
      'pago_completo': pagoCompleto,
      'fecha_pago': fechaPago?.toIso8601String(),
      'numero_comprobante': numeroComprobante,
      'observaciones': observaciones,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_actualizacion': fechaActualizacion.toIso8601String(),
      'activa': activa,
    };
  }

  // Getters para estado de matrícula
  bool get isVigente {
    final ahora = DateTime.now();
    return activa && 
           estadoMatricula == 'VIGENTE' && 
           ahora.isBefore(fechaVencimiento) &&
           pagoCompleto;
  }

  bool get isVencida {
    final ahora = DateTime.now();
    return ahora.isAfter(fechaVencimiento);
  }

  bool get isPorVencer {
    final ahora = DateTime.now();
    final diasRestantes = fechaVencimiento.difference(ahora).inDays;
    return isVigente && diasRestantes <= 30 && diasRestantes > 0;
  }

  bool get isPendientePago {
    return estadoMatricula == 'PENDIENTE_PAGO' || !pagoCompleto;
  }

  bool get isSuspendida {
    return estadoMatricula == 'SUSPENDIDA';
  }

  bool get isCancelada {
    return estadoMatricula == 'CANCELADA';
  }

  // Getters para información temporal
  int get diasRestantes {
    final ahora = DateTime.now();
    if (isVencida) return 0;
    return fechaVencimiento.difference(ahora).inDays;
  }

  int get diasTranscurridos {
    final ahora = DateTime.now();
    return ahora.difference(fechaMatriculacion).inDays;
  }

  Duration get tiempoRestante {
    final ahora = DateTime.now();
    if (isVencida) return Duration.zero;
    return fechaVencimiento.difference(ahora);
  }

  String get tiempoRestanteFormateado {
    final tiempo = tiempoRestante;
    if (tiempo.inDays > 0) {
      return '${tiempo.inDays} días';
    } else if (tiempo.inHours > 0) {
      return '${tiempo.inHours} horas';
    } else {
      return '${tiempo.inMinutes} minutos';
    }
  }

  // Getters para información académica
  String get periodoCompleto => '$anioAcademico - $cicloAcademico';
  
  String get tipoMatriculaFormateado {
    switch (tipoMatricula.toUpperCase()) {
      case 'REGULAR':
        return 'Regular';
      case 'EXTRAORDINARIA':
        return 'Extraordinaria';
      case 'REINGRESO':
        return 'Reingreso';
      case 'TRASLADO':
        return 'Traslado';
      default:
        return tipoMatricula;
    }
  }

  String get estadoMatriculaFormateado {
    switch (estadoMatricula.toUpperCase()) {
      case 'VIGENTE':
        return 'Vigente';
      case 'PENDIENTE_PAGO':
        return 'Pendiente de Pago';
      case 'SUSPENDIDA':
        return 'Suspendida';
      case 'CANCELADA':
        return 'Cancelada';
      case 'VENCIDA':
        return 'Vencida';
      default:
        return estadoMatricula;
    }
  }

  // Getters para información de pago
  String get montoFormateado => 'S/ ${montoMatricula.toStringAsFixed(2)}';
  
  String get estadoPago {
    if (pagoCompleto) return 'Pagado';
    if (fechaPago != null) return 'Pago Parcial';
    return 'Pendiente';
  }

  String get fechaPagoFormateada {
    if (fechaPago == null) return 'No pagado';
    return '${fechaPago!.day}/${fechaPago!.month}/${fechaPago!.year}';
  }

  // Getters para alertas y recomendaciones
  List<String> get alertas {
    List<String> alertas = [];
    
    if (isVencida) {
      alertas.add('Matrícula vencida');
    } else if (isPorVencer) {
      alertas.add('Matrícula por vencer (${diasRestantes} días)');
    }
    
    if (isPendientePago) {
      alertas.add('Pago pendiente');
    }
    
    if (isSuspendida) {
      alertas.add('Matrícula suspendida');
    }
    
    if (isCancelada) {
      alertas.add('Matrícula cancelada');
    }
    
    return alertas;
  }

  bool get tieneAlertas => alertas.isNotEmpty;

  String get recomendacionAcceso {
    if (!activa) return 'Matrícula inactiva - Acceso denegado';
    if (isVencida) return 'Matrícula vencida - Acceso denegado';
    if (isSuspendida) return 'Matrícula suspendida - Acceso denegado';
    if (isCancelada) return 'Matrícula cancelada - Acceso denegado';
    if (isPendientePago) return 'Pago pendiente - Verificar con administración';
    if (isPorVencer) return 'Matrícula por vencer - Acceso permitido con advertencia';
    return 'Matrícula vigente - Acceso permitido';
  }

  bool get puedeAcceder {
    return activa && 
           isVigente && 
           !isSuspendida && 
           !isCancelada;
  }

  // Getters para información de validación
  Map<String, dynamic> get resumenValidacion {
    return {
      'vigente': isVigente,
      'vencida': isVencida,
      'por_vencer': isPorVencer,
      'pendiente_pago': isPendientePago,
      'suspendida': isSuspendida,
      'cancelada': isCancelada,
      'puede_acceder': puedeAcceder,
      'dias_restantes': diasRestantes,
      'estado': estadoMatriculaFormateado,
      'tipo': tipoMatriculaFormateado,
      'periodo': periodoCompleto,
      'alertas': alertas,
      'recomendacion': recomendacionAcceso,
    };
  }

  // Getters para información detallada
  Map<String, dynamic> get informacionDetallada {
    return {
      'estudiante': {
        'id': estudianteId,
        'codigo': codigoUniversitario,
        'nombre': nombreCompleto,
      },
      'matricula': {
        'id': id,
        'ciclo': cicloAcademico,
        'anio': anioAcademico,
        'periodo': periodoCompleto,
        'tipo': tipoMatriculaFormateado,
        'estado': estadoMatriculaFormateado,
        'fecha_matriculacion': '${fechaMatriculacion.day}/${fechaMatriculacion.month}/${fechaMatriculacion.year}',
        'fecha_vencimiento': '${fechaVencimiento.day}/${fechaVencimiento.month}/${fechaVencimiento.year}',
        'dias_restantes': diasRestantes,
        'dias_transcurridos': diasTranscurridos,
      },
      'pago': {
        'monto': montoFormateado,
        'completo': pagoCompleto,
        'estado': estadoPago,
        'fecha_pago': fechaPagoFormateada,
        'comprobante': numeroComprobante,
      },
      'validacion': resumenValidacion,
      'observaciones': observaciones,
    };
  }
}
