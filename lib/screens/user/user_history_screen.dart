import 'dart:convert'; // Para utf8
import 'dart:typed_data'; // Para Uint8List
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'pending_all_exit_screen.dart'; // Importa la pantalla de pendientes de salida
import 'user_alarm_details_screen.dart'; // Importa la pantalla de alarma
import 'package:google_fonts/google_fonts.dart';

class UserHistoryScreen extends StatefulWidget {
  const UserHistoryScreen({super.key});

  @override
  State<UserHistoryScreen> createState() => _UserHistoryScreenState();
}

class _UserHistoryScreenState extends State<UserHistoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _selectedFilter = 'todos';
  DateTime? _selectedDate;
  DateTimeRange? _dateRange;
  bool _isLoading = true;
  String? _errorMessage;
  final List<Map<String, dynamic>> _attendanceData = [];

  // NUEVO: Filtros avanzados
  String? _dniFilter;
  String? _nombreFilter;
  String? _facultadFilter;
  String? _escuelaFilter;
  List<String> _facultadesDisponibles = [];
  List<String> _escuelasDisponibles = [];

  @override
  void initState() {
    super.initState();
    _loadFacultadesEscuelas();
    _loadInitialData();
  }

  Future<void> _loadFacultadesEscuelas() async {
    final facSnap = await _firestore.collection('facultades').get();
    final escSnap = await _firestore.collection('escuelas').get();
    setState(() {
      _facultadesDisponibles = facSnap.docs.map((d) => d.data()['nombre'] as String).toList();
      _escuelasDisponibles = escSnap.docs.map((d) => d.data()['nombre'] as String).toList();
    });
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Usuario no autenticado';
        });
        return;
      }

      Query query = _firestore.collection('asistencias')
          .orderBy('fecha_hora', descending: true)
          .limit(100);

      final userDoc = await _firestore.collection('usuarios').doc(user.uid).get();
      final isAdmin = userDoc.data()?['rango'] == 'admin';

      if (!isAdmin) {
        query = query.where('registrado_por.uid', isEqualTo: user.uid);
      } else {
        if (_selectedFilter == 'mis_registros') {
          query = query.where('registrado_por.uid', isEqualTo: user.uid);
        }
      }

      if (_selectedFilter == 'entrada' || _selectedFilter == 'salida') {
        query = query.where('tipo', isEqualTo: _selectedFilter);
      }

      // Filtros avanzados
      if (_dniFilter != null && _dniFilter!.isNotEmpty) {
        query = query.where('dni', isEqualTo: _dniFilter);
      }
      if (_nombreFilter != null && _nombreFilter!.isNotEmpty) {
        query = query.where('nombre', isEqualTo: _nombreFilter);
      }
      if (_facultadFilter != null && _facultadFilter!.isNotEmpty) {
        query = query.where('siglas_facultad', isEqualTo: _facultadFilter);
      }
      if (_escuelaFilter != null && _escuelaFilter!.isNotEmpty) {
        query = query.where('siglas_escuela', isEqualTo: _escuelaFilter);
      }

      // Filtro por rango de fechas (incluye caso de un solo día)
      if (_dateRange != null) {
        final start = DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day, 0, 0, 0);
        final end = DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day, 23, 59, 59, 999);
        query = query
            .where('fecha_hora', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
            .where('fecha_hora', isLessThanOrEqualTo: Timestamp.fromDate(end));
      }

      final snapshot = await query.get();

      setState(() {
        _attendanceData.clear();
        _attendanceData.addAll(snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            ...data,
            'id': doc.id,
            'fecha_hora': (data['fecha_hora'] as Timestamp).toDate(),
          };
        }));
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: \\${e.toString()}';
      });
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );

    if (picked != null) {
      setState(() {
        _dateRange = picked;
      });
      await _loadInitialData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.indigo.withOpacity(0.9),
        elevation: 8,
        title: Text(
          'Mis Registros de Asistencia',
          style: GoogleFonts.lato(
            textStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Tooltip(
              message: 'Alumnos dentro después de las 9',
              child: CircleAvatar(
                backgroundColor: Colors.white.withOpacity(0.85),
                radius: 22,
                child: IconButton(
                  icon: const Icon(Icons.warning_amber_rounded, size: 28),
                  color: Colors.orangeAccent,
                  splashRadius: 24,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PendingAllExitScreen(),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Tooltip(
              message: 'Visitas de externos',
              child: CircleAvatar(
                backgroundColor: Colors.white.withOpacity(0.85),
                radius: 22,
                child: IconButton(
                  icon: const Icon(Icons.groups_2_rounded, size: 28),
                  color: Colors.teal,
                  splashRadius: 24,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UserAlarmDetailsScreen(),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Tooltip(
              message: 'Refrescar registros',
              child: CircleAvatar(
                backgroundColor: Colors.white.withOpacity(0.85),
                radius: 22,
                child: IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 28),
                  color: Colors.indigo,
                  splashRadius: 24,
                  onPressed: _loadInitialData,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: PopupMenuButton<String>(
              tooltip: 'Filtrar por tipo',
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              icon: CircleAvatar(
                backgroundColor: Colors.white.withOpacity(0.85),
                radius: 20,
                child: const Icon(Icons.filter_list_rounded, color: Colors.deepPurple, size: 26),
              ),
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem(
                  value: 'todos',
                  child: Row(
                    children: [
                      Icon(Icons.list_alt, color: Colors.blueGrey),
                      SizedBox(width: 8),
                      Text('Todos los registros'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'entrada',
                  child: Row(
                    children: [
                      Icon(Icons.login, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Solo entradas'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'salida',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.redAccent),
                      SizedBox(width: 8),
                      Text('Solo salidas'),
                    ],
                  ),
                ),
              ],
              onSelected: (value) async {
                setState(() => _selectedFilter = value);
                await _loadInitialData();
              },
            ),
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF536976),
              Color(0xFF292E49),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                child: Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(labelText: 'DNI'),
                                onChanged: (v) {
                                  _dniFilter = v;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(labelText: 'Nombre'),
                                onChanged: (v) {
                                  _nombreFilter = v;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _facultadFilter,
                                decoration: const InputDecoration(labelText: 'Facultad'),
                                items: _facultadesDisponibles.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                                onChanged: (v) {
                                  setState(() => _facultadFilter = v);
                                },
                                isExpanded: true,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _escuelaFilter,
                                decoration: const InputDecoration(labelText: 'Escuela'),
                                items: _escuelasDisponibles.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                                onChanged: (v) {
                                  setState(() => _escuelaFilter = v);
                                },
                                isExpanded: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.filter_alt),
                                label: const Text('Aplicar filtros'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigo[700],
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: _loadInitialData,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.clear),
                                label: const Text('Limpiar filtros'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[300],
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () async {
                                  setState(() {
                                    _dniFilter = null;
                                    _nombreFilter = null;
                                    _facultadFilter = null;
                                    _escuelaFilter = null;
                                    _dateRange = null;
                                    _escuelasDisponibles = [];
                                  });
                                  await _loadInitialData();
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.date_range),
                                label: Text(_dateRange == null
                                    ? 'Rango de fechas'
                                    : '${DateFormat('dd/MM/yyyy').format(_dateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(_dateRange!.end)}'),
                                onPressed: () => _selectDateRange(context),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadInitialData,
                  child: _buildContent(),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'export',
            backgroundColor: Colors.amber[700],
            tooltip: 'Exportar a CSV',
            child: const Icon(Icons.download, color: Colors.white),
            onPressed: _exportToCsv,
          ),
          const SizedBox(height: 14),
          FloatingActionButton(
            heroTag: 'logout',
            backgroundColor: Colors.redAccent,
            tooltip: 'Cerrar sesión',
            child: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }

    if (_attendanceData.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No se encontraron registros',
              style: TextStyle(fontSize: 18),
            ),
            Text(
              'Prueba cambiando los filtros',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _attendanceData.length,
      itemBuilder: (context, index) {
        final record = _attendanceData[index];
        return _buildAttendanceItem(record);
      },
    );
  }

  Widget _buildAttendanceItem(Map<String, dynamic> record) {
    final fechaHora = DateFormat('dd/MM/yyyy HH:mm').format(record['fecha_hora']);
    final tipo = record['tipo']?.toString().toUpperCase() ?? '';
    final hora = record['hora'] ?? DateFormat('HH:mm').format(record['fecha_hora']);
    final registradoPor = record['registrado_por'];
    String? registradoPorNombre;
    if (registradoPor != null && registradoPor is Map<String, dynamic>) {
      final nombre = registradoPor['nombre'] ?? '';
      final apellido = registradoPor['apellido'] ?? '';
      registradoPorNombre = (nombre + ' ' + apellido).trim();
    }
    final entradaTipo = record['entrada_tipo'] ?? 'Desconocido';
    final puerta = record['puerta'] ?? '-';

    final isEntrada = record['tipo'] == 'entrada';
    final cardColor = isEntrada ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE); // Verde claro o rojo claro
    final borderColor = isEntrada ? Colors.green : Colors.redAccent;
    final iconColor = isEntrada ? Colors.green[700] : Colors.redAccent;
    final iconData = isEntrada ? Icons.login_rounded : Icons.logout_rounded;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border(
          left: BorderSide(color: borderColor, width: 7),
        ),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.13),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        leading: CircleAvatar(
          backgroundColor: iconColor?.withOpacity(0.15),
          radius: 28,
          child: Icon(iconData, color: iconColor, size: 32),
        ),
        title: Text(
          '${record['nombre'] ?? ''} ${record['apellido'] ?? ''}'.trim(),
          style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 19, color: Colors.black87),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 2),
            Text('DNI: ${record['dni'] ?? 'No disponible'}', style: GoogleFonts.lato(fontSize: 15, color: Colors.blueGrey[800])),
            Text('${record['siglas_facultad'] ?? ''} - ${record['siglas_escuela'] ?? ''}', style: GoogleFonts.lato(fontSize: 15, color: Colors.indigo[700])),
            Text(fechaHora, style: GoogleFonts.lato(fontSize: 13, color: Colors.grey[700])),
            Text('Entrada por: $entradaTipo | Puerta: $puerta', style: GoogleFonts.lato(fontSize: 13, color: Colors.deepPurple)),
          ],
        ),
        trailing: SizedBox(
          height: 40,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isEntrada ? Colors.green[100] : Colors.red[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tipo,
                  style: GoogleFonts.lato(
                    fontWeight: FontWeight.bold,
                    color: isEntrada ? Colors.green[800] : Colors.red[800],
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Icon(Icons.door_front_door, color: Colors.teal[400], size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportToCsv() async {
    try {
      String csvContent = "Nombre,Apellido,DNI,Código,Facultad,Escuela,Tipo,Fecha,Hora\n";
      
      for (var record in _attendanceData) {
        final date = DateFormat('dd/MM/yyyy').format(record['fecha_hora']);
        final time = record['hora'] ?? DateFormat('HH:mm').format(record['fecha_hora']);
        
        csvContent += '"${record['nombre'] ?? ''}",'
                     '"${record['apellido'] ?? ''}",'
                     '"${record['dni'] ?? ''}",'
                     '"${record['codigo_universitario'] ?? ''}",'
                     '"${record['siglas_facultad'] ?? ''}",'
                     '"${record['siglas_escuela'] ?? ''}",'
                     '"${record['tipo'] ?? ''}",'
                     '"$date","$time"\n';
      }

      final bytes = utf8.encode(csvContent);
      final file = XFile.fromData(
        Uint8List.fromList(bytes),
        mimeType: 'text/csv',
        name: 'mis_asistencias_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv'
      );

      await Share.shareXFiles([file], text: 'Mis registros de asistencia');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al exportar: ${e.toString()}')),
      );
    }
  }
}