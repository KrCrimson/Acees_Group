import 'package:flutter/foundation.dart';
import '../models/usuario_model.dart';
import '../models/historial_modificacion_model.dart';
import '../services/api_service.dart';

class AdminViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<UsuarioModel> _usuarios = [];
  List<HistorialModificacionModel> _historial = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Getters
  List<UsuarioModel> get usuarios => _usuarios;
  List<HistorialModificacionModel> get historial => _historial;
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

  // Cambiar estado de usuario (activar/desactivar)
  Future<bool> toggleUserStatus(String userId, bool activate) async {
    _setLoading(true);
    _clearMessages();

    try {
      final newStatus = activate ? 'activo' : 'inactivo';
      await _apiService.updateUserStatus(userId, newStatus);

      // Actualizar el usuario en la lista local
      final index = _usuarios.indexWhere((u) => u.id == userId);
      if (index != -1) {
        final user = _usuarios[index];
        final updatedUser = UsuarioModel(
          id: user.id,
          nombre: user.nombre,
          apellido: user.apellido,
          dni: user.dni,
          email: user.email,
          password: user.password,
          rango: user.rango,
          estado: newStatus,
          puertaACargo: user.puertaACargo,
          telefono: user.telefono,
          fechaCreacion: user.fechaCreacion,
          fechaActualizacion: DateTime.now(),
        );
        _usuarios[index] = updatedUser;
      }

      _setSuccess(
        activate
            ? 'Usuario activado exitosamente'
            : 'Usuario desactivado exitosamente',
      );
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Error al cambiar estado: $e');
      _setLoading(false);
      return false;
    }
  }

  // Obtener historial de modificaciones
  Future<void> loadHistorial([String? entidadId]) async {
    _setLoading(true);
    _clearMessages();

    try {
      // Por ahora, crear historial simulado (en implementación real vendría del API)
      _historial = _crearHistorialSimulado();
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  // Crear historial simulado para demostración
  List<HistorialModificacionModel> _crearHistorialSimulado() {
    return [
      HistorialModificacionModel(
        id: '1',
        entidadId: 'user1',
        tipoEntidad: 'usuario',
        accion: 'crear',
        adminId: 'admin1',
        adminNombre: 'Admin Principal',
        cambiosRealizados: {'nombre': 'Juan Pérez', 'rango': 'guardia'},
        descripcion: 'Nuevo guardia registrado',
        fechaModificacion: DateTime.now().subtract(Duration(days: 2)),
      ),
      HistorialModificacionModel(
        id: '2',
        entidadId: 'user1',
        tipoEntidad: 'usuario',
        accion: 'modificar',
        adminId: 'admin1',
        adminNombre: 'Admin Principal',
        cambiosRealizados: {'telefono': '+51987654321'},
        descripcion: 'Actualización de teléfono',
        fechaModificacion: DateTime.now().subtract(Duration(days: 1)),
      ),
      HistorialModificacionModel(
        id: '3',
        entidadId: 'user2',
        tipoEntidad: 'usuario',
        accion: 'desactivar',
        adminId: 'admin1',
        adminNombre: 'Admin Principal',
        cambiosRealizados: {'estado': 'inactivo'},
        descripcion: 'Usuario desactivado por inactividad',
        fechaModificacion: DateTime.now().subtract(Duration(hours: 3)),
      ),
    ];
  }

  // Registrar cambio en historial (método para implementación futura)
  Future<void> _registrarCambio({
    required String entidadId,
    required String tipoEntidad,
    required String accion,
    required Map<String, dynamic> cambios,
    String? descripcion,
  }) async {
    // En implementación real, esto haría un POST al servidor
    // Por ahora, solo añadimos al historial local
    final nuevoRegistro = HistorialModificacionModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      entidadId: entidadId,
      tipoEntidad: tipoEntidad,
      accion: accion,
      adminId: 'current_admin', // Vendría del usuario actual
      adminNombre: 'Admin Actual',
      cambiosRealizados: cambios,
      descripcion: descripcion,
      fechaModificacion: DateTime.now(),
    );

    _historial.insert(0, nuevoRegistro); // Añadir al inicio
    notifyListeners();
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
