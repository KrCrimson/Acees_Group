import 'package:flutter/foundation.dart';
import '../models/usuario_model.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';

class AuthViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final SessionService _sessionService = SessionService();

  UsuarioModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  bool _sessionWarningShown = false;

  // Getters
  UsuarioModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  SessionService get sessionService => _sessionService;

  // Login
  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _clearError();

    try {
      _currentUser = await _apiService.login(email, password);

      // Inicializar sesión después del login exitoso
      await _sessionService.initializeSession();
      _startUserSession();

      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // Logout
  void logout() {
    _sessionService.endSession();
    _currentUser = null;
    _clearError();
    notifyListeners();
  }

  // Cambiar contraseña
  Future<bool> changePassword(String newPassword) async {
    if (_currentUser == null) return false;

    _setLoading(true);
    _clearError();

    try {
      await _apiService.changePassword(_currentUser!.id, newPassword);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // Extender sesión (llamar en actividades del usuario)
  void extendSession() {
    if (isLoggedIn) {
      _sessionService.extendSession();
    }
  }

  // Configurar tiempo de sesión (solo admin)
  Future<bool> configureSessionTimeout(
    int timeoutMinutes,
    int warningMinutes,
  ) async {
    if (!isAdmin) return false;

    try {
      await _sessionService.configureSessionTimeout(
        timeoutMinutes,
        warningMinutes,
      );
      return true;
    } catch (e) {
      _setError('Error al configurar sesión: $e');
      return false;
    }
  }

  // Iniciar sesión del usuario con callbacks
  void _startUserSession() {
    _sessionService.startSession(
      onSessionExpired: () {
        // Logout automático cuando expire la sesión
        logout();
      },
      onSessionWarning: () {
        // Marcar que se mostró la advertencia
        _sessionWarningShown = true;
        notifyListeners();
      },
    );
  }

  // Verificar si hay advertencia de sesión
  bool hasSessionWarning() {
    return _sessionWarningShown;
  }

  // Limpiar advertencia de sesión
  void clearSessionWarning() {
    _sessionWarningShown = false;
    notifyListeners();
  }

  // Métodos privados
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
