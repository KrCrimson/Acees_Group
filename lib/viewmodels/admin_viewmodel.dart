import 'package:flutter/foundation.dart';
import '../models/usuario_model.dart';
import '../services/api_service.dart';

class AdminViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<UsuarioModel> _usuarios = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Getters
  List<UsuarioModel> get usuarios => _usuarios;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  // Cargar usuarios
  Future<void> loadUsuarios() async {
    _setLoading(true);
    _clearMessages();

    try {
      _usuarios = await _apiService.getUsuarios();
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  // Crear usuario
  Future<bool> createUsuario(UsuarioModel usuario) async {
    _setLoading(true);
    _clearMessages();

    try {
      final nuevoUsuario = await _apiService.createUsuario(usuario);
      _usuarios.add(nuevoUsuario);
      _setSuccess('Usuario creado exitosamente');
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // Cambiar contraseña de usuario
  Future<bool> changeUserPassword(String userId, String newPassword) async {
    _setLoading(true);
    _clearMessages();

    try {
      await _apiService.changePassword(userId, newPassword);
      _setSuccess('Contraseña actualizada exitosamente');
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // Filtrar usuarios por tipo
  List<UsuarioModel> getUsuariosByRango(String rango) {
    return _usuarios.where((user) => user.rango == rango).toList();
  }

  // Obtener usuarios activos
  List<UsuarioModel> getActiveUsuarios() {
    return _usuarios.where((user) => user.isActive).toList();
  }

  // Limpiar mensajes
  void clearMessages() {
    _clearMessages();
  }

  // Métodos privados
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    _successMessage = null;
    notifyListeners();
  }

  void _setSuccess(String success) {
    _successMessage = success;
    _errorMessage = null;
    notifyListeners();
  }

  void _clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }
}
