import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionService extends ChangeNotifier {
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  Timer? _sessionTimer;
  Timer? _warningTimer;
  int _sessionTimeoutMinutes = 30; // Tiempo por defecto
  int _warningTimeMinutes = 5; // Advertencia 5 min antes

  VoidCallback? _onSessionExpired;
  VoidCallback? _onSessionWarning;

  // Getters
  int get sessionTimeoutMinutes => _sessionTimeoutMinutes;
  int get warningTimeMinutes => _warningTimeMinutes;
  bool get hasActiveSession => _sessionTimer?.isActive ?? false;

  // Inicializar configuración desde preferencias
  Future<void> initializeSession() async {
    final prefs = await SharedPreferences.getInstance();
    _sessionTimeoutMinutes = prefs.getInt('session_timeout_minutes') ?? 30;
    _warningTimeMinutes = prefs.getInt('warning_time_minutes') ?? 5;
  }

  // Configurar tiempo de sesión (solo admin)
  Future<void> configureSessionTimeout(
    int timeoutMinutes,
    int warningMinutes,
  ) async {
    _sessionTimeoutMinutes = timeoutMinutes;
    _warningTimeMinutes = warningMinutes;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('session_timeout_minutes', timeoutMinutes);
    await prefs.setInt('warning_time_minutes', warningMinutes);

    // Reiniciar sesión con nueva configuración
    if (hasActiveSession) {
      _resetSessionTimer();
    }

    notifyListeners();
  }

  // Iniciar sesión con callbacks
  void startSession({
    required VoidCallback onSessionExpired,
    required VoidCallback onSessionWarning,
  }) {
    _onSessionExpired = onSessionExpired;
    _onSessionWarning = onSessionWarning;
    _startSessionTimer();
  }

  // Extender sesión (llamar en cada actividad del usuario)
  void extendSession() {
    if (hasActiveSession) {
      _resetSessionTimer();
    }
  }

  // Terminar sesión manualmente
  void endSession() {
    _sessionTimer?.cancel();
    _warningTimer?.cancel();
    _sessionTimer = null;
    _warningTimer = null;
    notifyListeners();
  }

  // Iniciar timer de sesión
  void _startSessionTimer() {
    _sessionTimer?.cancel();
    _warningTimer?.cancel();

    // Timer para advertencia
    final warningDuration = Duration(
      minutes: _sessionTimeoutMinutes - _warningTimeMinutes,
    );
    _warningTimer = Timer(warningDuration, () {
      _onSessionWarning?.call();
    });

    // Timer para expiración
    final sessionDuration = Duration(minutes: _sessionTimeoutMinutes);
    _sessionTimer = Timer(sessionDuration, () {
      _onSessionExpired?.call();
      endSession();
    });

    notifyListeners();
  }

  // Reiniciar timer
  void _resetSessionTimer() {
    _startSessionTimer();
  }

  // Obtener tiempo restante
  Duration? getRemainingTime() {
    if (_sessionTimer == null || !_sessionTimer!.isActive) {
      return null;
    }

    // Aproximación del tiempo restante
    return Duration(minutes: _sessionTimeoutMinutes);
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _warningTimer?.cancel();
    super.dispose();
  }
}
