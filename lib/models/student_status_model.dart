import 'alumno_model.dart';
import 'asistencia_model.dart';
import 'presencia_model.dart';
import 'decision_manual_model.dart';

class StudentStatusModel {
  final AlumnoModel estudiante;
  final PresenciaModel? presenciaActual;
  final List<AsistenciaModel> asistenciasRecientes;
  final List<DecisionManualModel> decisionesRecientes;
  final Map<String, dynamic> estadisticas;
  final Map<String, dynamic> alertas;
  final DateTime ultimaConsulta;

  StudentStatusModel({
    required this.estudiante,
    this.presenciaActual,
    required this.asistenciasRecientes,
    required this.decisionesRecientes,
    required this.estadisticas,
    required this.alertas,
    required this.ultimaConsulta,
  });

  factory StudentStatusModel.fromMap(Map<String, dynamic> map) {
    return StudentStatusModel(
      estudiante: AlumnoModel.fromJson(map['estudiante']),
      presenciaActual: map['presencia_actual'] != null 
          ? PresenciaModel.fromJson(map['presencia_actual']) 
          : null,
      asistenciasRecientes: (map['asistencias_recientes'] as List?)
          ?.map((json) => AsistenciaModel.fromJson(json))
          .toList() ?? [],
      decisionesRecientes: (map['decisiones_recientes'] as List?)
          ?.map((json) => DecisionManualModel.fromJson(json))
          .toList() ?? [],
      estadisticas: Map<String, dynamic>.from(map['estadisticas'] ?? {}),
      alertas: Map<String, dynamic>.from(map['alertas'] ?? {}),
      ultimaConsulta: DateTime.parse(map['ultima_consulta']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'estudiante': estudiante.toJson(),
      'presencia_actual': presenciaActual?.toJson(),
      'asistencias_recientes': asistenciasRecientes.map((a) => a.toJson()).toList(),
      'decisiones_recientes': decisionesRecientes.map((d) => d.toJson()).toList(),
      'estadisticas': estadisticas,
      'alertas': alertas,
      'ultima_consulta': ultimaConsulta.toIso8601String(),
    };
  }

  // Getters para información del estudiante
  String get nombreCompleto => estudiante.nombreCompleto;
  String get codigoUniversitario => estudiante.codigoUniversitario;
  String get dni => estudiante.dni;
  String get facultad => estudiante.facultad;
  String get escuela => estudiante.escuelaProfesional;
  bool get isActive => estudiante.isActive;

  // Getters para estado de presencia
  bool get estaEnCampus => presenciaActual?.estaDentro ?? false;
  String get estadoPresencia {
    if (presenciaActual == null) return 'Sin registro';
    if (estaEnCampus) return 'En campus';
    return 'Fuera del campus';
  }

  String get ultimaActividad {
    if (presenciaActual == null) return 'Sin actividad reciente';
    if (estaEnCampus) {
      return 'Entrada: ${presenciaActual!.horaEntrada.day}/${presenciaActual!.horaEntrada.month} ${presenciaActual!.horaEntrada.hour}:${presenciaActual!.horaEntrada.minute.toString().padLeft(2, '0')}';
    } else {
      return 'Salida: ${presenciaActual!.horaSalida!.day}/${presenciaActual!.horaSalida!.month} ${presenciaActual!.horaSalida!.hour}:${presenciaActual!.horaSalida!.minute.toString().padLeft(2, '0')}';
    }
  }

  Duration? get tiempoEnCampus {
    if (presenciaActual == null || !estaEnCampus) return null;
    return DateTime.now().difference(presenciaActual!.horaEntrada);
  }

  String get tiempoEnCampusFormateado {
    final tiempo = tiempoEnCampus;
    if (tiempo == null) return 'N/A';
    final horas = tiempo.inHours;
    final minutos = tiempo.inMinutes.remainder(60);
    return '${horas}h ${minutos}m';
  }

  // Getters para estadísticas
  int get totalAsistenciasHoy {
    final hoy = DateTime.now();
    return asistenciasRecientes.where((a) => 
        a.fechaHora.year == hoy.year &&
        a.fechaHora.month == hoy.month &&
        a.fechaHora.day == hoy.day).length;
  }

  int get totalAsistenciasEstaSemana {
    final ahora = DateTime.now();
    final inicioSemana = ahora.subtract(Duration(days: ahora.weekday - 1));
    return asistenciasRecientes.where((a) => 
        a.fechaHora.isAfter(inicioSemana) &&
        a.fechaHora.isBefore(ahora.add(Duration(days: 1)))).length;
  }

  int get totalAsistenciasEsteMes {
    final ahora = DateTime.now();
    final inicioMes = DateTime(ahora.year, ahora.month, 1);
    return asistenciasRecientes.where((a) => 
        a.fechaHora.isAfter(inicioMes) &&
        a.fechaHora.isBefore(ahora.add(Duration(days: 1)))).length;
  }

  int get totalEntradas {
    return asistenciasRecientes.where((a) => a.entradaTipo == 'entrada').length;
  }

  int get totalSalidas {
    return asistenciasRecientes.where((a) => a.entradaTipo == 'salida').length;
  }

  int get totalAutorizacionesManuales {
    return asistenciasRecientes.where((a) => a.autorizacionManual == true).length;
  }

  // Getters para alertas
  bool get tieneAlertas => alertas.isNotEmpty;
  List<String> get listaAlertas {
    List<String> alertasList = [];
    if (alertas['estudiante_inactivo'] == true) {
      alertasList.add('Estudiante inactivo');
    }
    if (alertas['muchas_autorizaciones'] == true) {
      alertasList.add('Muchas autorizaciones manuales');
    }
    if (alertas['tiempo_excesivo_campus'] == true) {
      alertasList.add('Tiempo excesivo en campus');
    }
    if (alertas['patron_irregular'] == true) {
      alertasList.add('Patrón de asistencia irregular');
    }
    return alertasList;
  }

  // Getters para patrones de asistencia
  Map<String, int> get asistenciasPorDiaSemana {
    Map<String, int> dias = {
      'Lunes': 0, 'Martes': 0, 'Miércoles': 0, 'Jueves': 0,
      'Viernes': 0, 'Sábado': 0, 'Domingo': 0
    };
    
    for (var asistencia in asistenciasRecientes) {
      final diaSemana = asistencia.fechaHora.weekday;
      final nombresDias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
      dias[nombresDias[diaSemana - 1]] = (dias[nombresDias[diaSemana - 1]] ?? 0) + 1;
    }
    
    return dias;
  }

  Map<String, int> get asistenciasPorHora {
    Map<String, int> horas = {};
    for (int i = 0; i < 24; i++) {
      horas['${i.toString().padLeft(2, '0')}:00'] = 0;
    }
    
    for (var asistencia in asistenciasRecientes) {
      final hora = asistencia.fechaHora.hour;
      final horaStr = '${hora.toString().padLeft(2, '0')}:00';
      horas[horaStr] = (horas[horaStr] ?? 0) + 1;
    }
    
    return horas;
  }

  // Getters para decisiones manuales
  int get totalDecisionesManuales => decisionesRecientes.length;
  int get decisionesAutorizadas => decisionesRecientes.where((d) => d.autorizado).length;
  int get decisionesRechazadas => decisionesRecientes.where((d) => !d.autorizado).length;

  List<String> get razonesDecisionesRechazadas {
    return decisionesRecientes
        .where((d) => !d.autorizado)
        .map((d) => d.razon)
        .toSet()
        .toList();
  }

  // Getters para información de contacto/ubicación
  String get puntoEntradaActual => presenciaActual?.puntoEntrada ?? 'N/A';
  String get puntoSalidaActual => presenciaActual?.puntoSalida ?? 'N/A';
  String get guardiaActual => presenciaActual?.guardiaEntrada ?? 'N/A';

  // Métodos de utilidad
  bool get puedeAcceder {
    if (!isActive) return false;
    if (estaEnCampus) return false; // Ya está dentro
    return true;
  }

  String get proximaAccionRecomendada {
    if (!isActive) return 'Estudiante inactivo - requiere autorización manual';
    if (estaEnCampus) return 'Estudiante ya está en campus - registrar salida';
    return 'Estudiante puede ingresar normalmente';
  }

  Map<String, dynamic> get resumenEjecutivo {
    return {
      'estudiante': {
        'nombre': nombreCompleto,
        'codigo': codigoUniversitario,
        'dni': dni,
        'facultad': facultad,
        'escuela': escuela,
        'activo': isActive,
      },
      'presencia': {
        'en_campus': estaEnCampus,
        'estado': estadoPresencia,
        'ultima_actividad': ultimaActividad,
        'tiempo_en_campus': tiempoEnCampusFormateado,
      },
      'estadisticas': {
        'asistencias_hoy': totalAsistenciasHoy,
        'asistencias_semana': totalAsistenciasEstaSemana,
        'asistencias_mes': totalAsistenciasEsteMes,
        'entradas': totalEntradas,
        'salidas': totalSalidas,
        'autorizaciones_manuales': totalAutorizacionesManuales,
      },
      'alertas': listaAlertas,
      'puede_acceder': puedeAcceder,
      'proxima_accion': proximaAccionRecomendada,
    };
  }
}
