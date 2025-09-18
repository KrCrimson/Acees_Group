import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool _isOnline = true;
  ConnectivityResult _connectionType = ConnectivityResult.none;
  DateTime? _lastOnlineTime;
  DateTime? _lastOfflineTime;

  // Getters
  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;
  ConnectivityResult get connectionType => _connectionType;
  DateTime? get lastOnlineTime => _lastOnlineTime;
  DateTime? get lastOfflineTime => _lastOfflineTime;

  // Inicializar el servicio de conectividad
  Future<void> initialize() async {
    // Obtener estado inicial
    final connectivityResults = await _connectivity.checkConnectivity();
    _updateConnectionStatus(connectivityResults);

    // Escuchar cambios en la conectividad
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
      onError: (error) {
        debugPrint('Error en conectividad: $error');
        _setOffline();
      },
    );
  }

  // Actualizar estado de conexión
  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    
    // Determinar si hay conexión
    _isOnline = results.any((result) => 
        result == ConnectivityResult.mobile || 
        result == ConnectivityResult.wifi || 
        result == ConnectivityResult.ethernet);

    // Actualizar tipo de conexión
    if (results.isNotEmpty) {
      _connectionType = results.first;
    }

    // Registrar tiempos de cambio de estado
    if (_isOnline && !wasOnline) {
      _lastOnlineTime = DateTime.now();
      debugPrint('🟢 Conexión restaurada: ${_connectionType.name}');
    } else if (!_isOnline && wasOnline) {
      _lastOfflineTime = DateTime.now();
      debugPrint('🔴 Conexión perdida');
    }

    notifyListeners();
  }

  // Forzar estado offline (para testing)
  void _setOffline() {
    if (_isOnline) {
      _isOnline = false;
      _lastOfflineTime = DateTime.now();
      notifyListeners();
    }
  }

  // Forzar estado online (para testing)
  void _setOnline() {
    if (!_isOnline) {
      _isOnline = true;
      _lastOnlineTime = DateTime.now();
      notifyListeners();
    }
  }

  // Verificar conectividad específica
  Future<bool> hasInternetConnection() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.any((result) => 
          result == ConnectivityResult.mobile || 
          result == ConnectivityResult.wifi || 
          result == ConnectivityResult.ethernet);
    } catch (e) {
      debugPrint('Error verificando conectividad: $e');
      return false;
    }
  }

  // Obtener descripción del tipo de conexión
  String get connectionDescription {
    switch (_connectionType) {
      case ConnectivityResult.wifi:
        return 'WiFi';
      case ConnectivityResult.mobile:
        return 'Datos móviles';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.bluetooth:
        return 'Bluetooth';
      case ConnectivityResult.vpn:
        return 'VPN';
      case ConnectivityResult.other:
        return 'Otro';
      case ConnectivityResult.none:
      default:
        return 'Sin conexión';
    }
  }

  // Obtener tiempo offline
  Duration? get timeOffline {
    if (_isOnline || _lastOfflineTime == null) return null;
    return DateTime.now().difference(_lastOfflineTime!);
  }

  // Obtener tiempo online
  Duration? get timeOnline {
    if (!_isOnline || _lastOnlineTime == null) return null;
    return DateTime.now().difference(_lastOnlineTime!);
  }

  // Verificar si ha estado offline por mucho tiempo
  bool get hasBeenOfflineTooLong {
    final offlineTime = timeOffline;
    if (offlineTime == null) return false;
    return offlineTime.inHours > 1; // Más de 1 hora offline
  }

  // Obtener estadísticas de conectividad
  Map<String, dynamic> get connectivityStats {
    return {
      'isOnline': _isOnline,
      'connectionType': _connectionType.name,
      'connectionDescription': connectionDescription,
      'lastOnlineTime': _lastOnlineTime?.toIso8601String(),
      'lastOfflineTime': _lastOfflineTime?.toIso8601String(),
      'timeOffline': timeOffline?.inMinutes,
      'timeOnline': timeOnline?.inMinutes,
      'hasBeenOfflineTooLong': hasBeenOfflineTooLong,
    };
  }

  // Limpiar recursos
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
