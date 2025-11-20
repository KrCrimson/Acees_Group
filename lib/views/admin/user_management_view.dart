import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../models/usuario_model.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/status_widgets.dart';

class UserManagementView extends StatefulWidget {
  @override
  _UserManagementViewState createState() => _UserManagementViewState();
}

class _UserManagementViewState extends State<UserManagementView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUsuarios();
    });
  }

  Future<void> _loadUsuarios() async {
    final adminViewModel = Provider.of<AdminViewModel>(context, listen: false);
    await adminViewModel.loadUsuarios();
  }

  void _showCreateUserDialog() {
    showDialog(context: context, builder: (context) => CreateUserDialog());
  }

  void _showChangePasswordDialog(UsuarioModel usuario) {
    showDialog(
      context: context,
      builder: (context) => ChangePasswordDialog(usuario: usuario),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminViewModel>(
      builder: (context, adminViewModel, child) {
        if (adminViewModel.isLoading && adminViewModel.usuarios.isEmpty) {
          return LoadingWidget(message: 'Cargando usuarios...');
        }

        if (adminViewModel.errorMessage != null &&
            adminViewModel.usuarios.isEmpty) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              SizedBox(height: 16),
              Text(adminViewModel.errorMessage!, textAlign: TextAlign.center),
              SizedBox(height: 16),
              CustomButton(text: 'Reintentar', onPressed: _loadUsuarios),
            ],
          );
        }

        return RefreshIndicator(
          onRefresh: _loadUsuarios,
          child: Column(
            children: [
              // Header con botón para crear usuario
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Gestión de Usuarios',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    CustomButton(
                      text: 'Nuevo Usuario',
                      icon: Icons.person_add,
                      isLoading: adminViewModel.isLoading,
                      onPressed: _showCreateUserDialog,
                    ),
                  ],
                ),
              ),

              // Mensajes de estado
              if (adminViewModel.successMessage != null)
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.all(16),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    border: Border.all(color: Colors.green[200]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green[600],
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          adminViewModel.successMessage!,
                          style: TextStyle(color: Colors.green[700]),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, size: 18),
                        onPressed: () => adminViewModel.clearMessages(),
                      ),
                    ],
                  ),
                ),

              if (adminViewModel.errorMessage != null)
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.all(16),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    border: Border.all(color: Colors.red[200]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red[600], size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          adminViewModel.errorMessage!,
                          style: TextStyle(color: Colors.red[700]),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, size: 18),
                        onPressed: () => adminViewModel.clearMessages(),
                      ),
                    ],
                  ),
                ),

              // Lista de usuarios
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: adminViewModel.usuarios.length,
                  itemBuilder: (context, index) {
                    final usuario = adminViewModel.usuarios[index];
                    return _buildUserCard(usuario);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserCard(UsuarioModel usuario) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Avatar, Nombre y Menú
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor:
                      usuario.isAdmin ? Colors.purple[100] : Colors.blue[100],
                  child: Icon(
                    usuario.isAdmin ? Icons.admin_panel_settings : Icons.person,
                    color: usuario.isAdmin ? Colors.purple : Colors.blue,
                    size: 28,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        usuario.nombreCompleto,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        usuario.rango.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Badge de estado
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: usuario.isActive ? Colors.green[100] : Colors.red[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    usuario.estado,
                    style: TextStyle(
                      color: usuario.isActive ? Colors.green[700] : Colors.red[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                // Menú de acciones
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditUserDialog(usuario);
                    } else if (value == 'change_password') {
                      _showChangePasswordDialog(usuario);
                    } else if (value == 'delete') {
                      _showDeleteConfirmation(usuario);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Editar'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'change_password',
                      child: Row(
                        children: [
                          Icon(Icons.lock_reset, size: 18, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Cambiar Contraseña'),
                        ],
                      ),
                    ),
                    PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Eliminar', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12),
            Divider(),
            SizedBox(height: 8),
            // Información del usuario
            _buildInfoRow(Icons.email, 'Email', usuario.email),
            _buildInfoRow(Icons.badge, 'DNI', usuario.dni),
            if (usuario.telefono != null)
              _buildInfoRow(Icons.phone, 'Teléfono', usuario.telefono!),
            if (usuario.puertaACargo != null)
              _buildInfoRow(Icons.door_front_door, 'Puerta', usuario.puertaACargo!),
            SizedBox(height: 12),
            // Toggle de estado activo/inactivo
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Estado del usuario:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                Consumer<AdminViewModel>(
                  builder: (context, adminViewModel, child) {
                    return Row(
                      children: [
                        Text(
                          usuario.isActive ? 'Activo' : 'Inactivo',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: usuario.isActive ? Colors.green : Colors.red,
                          ),
                        ),
                        SizedBox(width: 8),
                        Switch(
                          value: usuario.isActive,
                          activeColor: Colors.green,
                          onChanged: adminViewModel.isLoading
                              ? null
                              : (bool value) async {
                                  final success = await adminViewModel
                                      .toggleUserStatus(usuario.id, value);
                                  if (!success && mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '❌ Error al cambiar estado del usuario',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditUserDialog(UsuarioModel usuario) {
    showDialog(
      context: context,
      builder: (context) => EditUserDialog(usuario: usuario),
    );
  }

  void _showDeleteConfirmation(UsuarioModel usuario) async {
    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmar Eliminación'),
        content: Text(
          '¿Está seguro de que desea eliminar a ${usuario.nombreCompleto}?\n\n'
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmacion == true) {
      final adminViewModel = Provider.of<AdminViewModel>(context, listen: false);
      final success = await adminViewModel.deleteUsuario(usuario.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? '✅ Usuario eliminado correctamente'
                  : '❌ Error al eliminar usuario',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }
}

class CreateUserDialog extends StatefulWidget {
  @override
  _CreateUserDialogState createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<CreateUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _dniController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _puertaController = TextEditingController();

  String _selectedRango = 'guardia';

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _dniController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _telefonoController.dispose();
    _puertaController.dispose();
    super.dispose();
  }

  void _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    final adminViewModel = Provider.of<AdminViewModel>(context, listen: false);

    final nuevoUsuario = UsuarioModel(
      id: '', // Se genera en el servidor
      nombre: _nombreController.text.trim(),
      apellido: _apellidoController.text.trim(),
      dni: _dniController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      rango: _selectedRango,
      estado: 'activo',
      telefono:
          _telefonoController.text.trim().isEmpty
              ? null
              : _telefonoController.text.trim(),
      puertaACargo:
          _puertaController.text.trim().isEmpty
              ? null
              : _puertaController.text.trim(),
    );

    bool success = await adminViewModel.createUsuario(nuevoUsuario);
    if (success && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Crear Nuevo Usuario'),
      content: Container(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  label: 'Nombre',
                  controller: _nombreController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingrese el nombre';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),

                CustomTextField(
                  label: 'Apellido',
                  controller: _apellidoController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingrese el apellido';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),

                CustomTextField(
                  label: 'DNI',
                  controller: _dniController,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingrese el DNI';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),

                CustomTextField(
                  label: 'Email',
                  controller: _emailController,
                  isEmail: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingrese el email';
                    }
                    if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(value)) {
                      return 'Email inválido';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),

                CustomTextField(
                  label: 'Contraseña',
                  controller: _passwordController,
                  isPassword: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingrese la contraseña';
                    }
                    if (value.length < 6) {
                      return 'Mínimo 6 caracteres';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),

                // Selector de rango
                DropdownButtonFormField<String>(
                  value: _selectedRango,
                  decoration: InputDecoration(
                    labelText: 'Rango',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items: [
                    DropdownMenuItem(value: 'guardia', child: Text('Guardia')),
                    DropdownMenuItem(
                      value: 'admin',
                      child: Text('Administrador'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedRango = value!;
                    });
                  },
                ),
                SizedBox(height: 16),

                CustomTextField(
                  label: 'Teléfono (Opcional)',
                  controller: _telefonoController,
                  keyboardType: TextInputType.phone,
                ),
                SizedBox(height: 16),

                CustomTextField(
                  label: 'Puerta a Cargo (Opcional)',
                  controller: _puertaController,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar'),
        ),
        Consumer<AdminViewModel>(
          builder: (context, adminViewModel, child) {
            return ElevatedButton(
              onPressed: adminViewModel.isLoading ? null : _handleCreate,
              child:
                  adminViewModel.isLoading
                      ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : Text('Crear Usuario'),
            );
          },
        ),
      ],
    );
  }
}

class ChangePasswordDialog extends StatefulWidget {
  final UsuarioModel usuario;

  const ChangePasswordDialog({Key? key, required this.usuario})
    : super(key: key);

  @override
  _ChangePasswordDialogState createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleChangePassword() async {
    if (!_formKey.currentState!.validate()) return;

    final adminViewModel = Provider.of<AdminViewModel>(context, listen: false);

    bool success = await adminViewModel.changeUserPassword(
      widget.usuario.id,
      _passwordController.text,
    );

    if (success && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Cambiar Contraseña'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Cambiar contraseña para: ${widget.usuario.nombreCompleto}'),
            SizedBox(height: 16),

            CustomTextField(
              label: 'Nueva Contraseña',
              controller: _passwordController,
              isPassword: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ingrese la nueva contraseña';
                }
                if (value.length < 6) {
                  return 'Mínimo 6 caracteres';
                }
                return null;
              },
            ),
            SizedBox(height: 16),

            CustomTextField(
              label: 'Confirmar Contraseña',
              controller: _confirmPasswordController,
              isPassword: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Confirme la contraseña';
                }
                if (value != _passwordController.text) {
                  return 'Las contraseñas no coinciden';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar'),
        ),
        Consumer<AdminViewModel>(
          builder: (context, adminViewModel, child) {
            return ElevatedButton(
              onPressed:
                  adminViewModel.isLoading ? null : _handleChangePassword,
              child:
                  adminViewModel.isLoading
                      ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : Text('Cambiar'),
            );
          },
        ),
      ],
    );
  }
}

class EditUserDialog extends StatefulWidget {
  final UsuarioModel usuario;

  const EditUserDialog({Key? key, required this.usuario}) : super(key: key);

  @override
  _EditUserDialogState createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreController;
  late TextEditingController _apellidoController;
  late TextEditingController _dniController;
  late TextEditingController _emailController;
  late TextEditingController _telefonoController;
  late TextEditingController _puertaController;
  late String _selectedRango;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.usuario.nombre);
    _apellidoController = TextEditingController(text: widget.usuario.apellido);
    _dniController = TextEditingController(text: widget.usuario.dni);
    _emailController = TextEditingController(text: widget.usuario.email);
    _telefonoController = TextEditingController(text: widget.usuario.telefono ?? '');
    _puertaController = TextEditingController(text: widget.usuario.puertaACargo ?? '');
    _selectedRango = widget.usuario.rango;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _dniController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    _puertaController.dispose();
    super.dispose();
  }

  void _handleUpdate() async {
    if (!_formKey.currentState!.validate()) return;

    final adminViewModel = Provider.of<AdminViewModel>(context, listen: false);

    final usuarioActualizado = UsuarioModel(
      id: widget.usuario.id,
      nombre: _nombreController.text.trim(),
      apellido: _apellidoController.text.trim(),
      dni: _dniController.text.trim(),
      email: _emailController.text.trim(),
      password: widget.usuario.password,
      rango: _selectedRango,
      estado: widget.usuario.estado,
      telefono: _telefonoController.text.trim().isEmpty ? null : _telefonoController.text.trim(),
      puertaACargo: _puertaController.text.trim().isEmpty ? null : _puertaController.text.trim(),
    );

    bool success = await adminViewModel.updateUsuario(usuarioActualizado);
    if (success && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Editar Usuario'),
      content: Container(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  label: 'Nombre',
                  controller: _nombreController,
                  validator: (value) => value == null || value.isEmpty ? 'Ingrese el nombre' : null,
                ),
                SizedBox(height: 16),
                CustomTextField(
                  label: 'Apellido',
                  controller: _apellidoController,
                  validator: (value) => value == null || value.isEmpty ? 'Ingrese el apellido' : null,
                ),
                SizedBox(height: 16),
                CustomTextField(
                  label: 'DNI',
                  controller: _dniController,
                  keyboardType: TextInputType.number,
                  validator: (value) => value == null || value.isEmpty ? 'Ingrese el DNI' : null,
                ),
                SizedBox(height: 16),
                CustomTextField(
                  label: 'Email',
                  controller: _emailController,
                  isEmail: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Ingrese el email';
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) return 'Email inválido';
                    return null;
                  },
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedRango,
                  decoration: InputDecoration(
                    labelText: 'Rango',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: [
                    DropdownMenuItem(value: 'guardia', child: Text('Guardia')),
                    DropdownMenuItem(value: 'admin', child: Text('Administrador')),
                  ],
                  onChanged: (value) => setState(() => _selectedRango = value!),
                ),
                SizedBox(height: 16),
                CustomTextField(
                  label: 'Teléfono (Opcional)',
                  controller: _telefonoController,
                  keyboardType: TextInputType.phone,
                ),
                SizedBox(height: 16),
                CustomTextField(
                  label: 'Puerta a Cargo (Opcional)',
                  controller: _puertaController,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar'),
        ),
        Consumer<AdminViewModel>(
          builder: (context, adminViewModel, child) {
            return ElevatedButton(
              onPressed: adminViewModel.isLoading ? null : _handleUpdate,
              child: adminViewModel.isLoading
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('Guardar Cambios'),
            );
          },
        ),
      ],
    );
  }
}
