import 'dart:convert'; // Para utf8
import 'dart:typed_data'; // Para Uint8List
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  @override
  void initState() {
    super.initState();
    _loadInitialData();
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

      // Consulta base
      Query query = _firestore.collection('asistencias')
          .orderBy('fecha_hora', descending: true)
          .limit(100);

      // Verifica si es administrador
      final userDoc = await _firestore.collection('usuarios').doc(user.uid).get();
      final isAdmin = userDoc.data()?['rango'] == 'admin';

      if (!isAdmin) {
        // Si no es admin, solo puede ver sus registros
        query = query.where('registrado_por.uid', isEqualTo: user.uid);
      } else {
        // Si es admin, puede aplicar filtros
        if (_selectedFilter == 'entrada' || _selectedFilter == 'salida') {
          query = query.where('tipo', isEqualTo: _selectedFilter);
        } else if (_selectedFilter == 'mis_registros') {
          query = query.where('registrado_por.uid', isEqualTo: user.uid);
        }
      }

      // Filtro por rango de fechas
      if (_dateRange != null) {
        query = query
            .where('fecha_hora', isGreaterThanOrEqualTo: Timestamp.fromDate(_dateRange!.start))
            .where('fecha_hora', isLessThanOrEqualTo: Timestamp.fromDate(_dateRange!.end));
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
        _errorMessage = 'Error: ${e.toString()}';
      });
    }
  }
  
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateRange = null;
      });
      await _loadInitialData();
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
        _selectedDate = null;
      });
      await _loadInitialData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Registros de Asistencia'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInitialData,
          ),
          PopupMenuButton<String>(
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'todos',
                child: Text('Todos los registros'),
              ),
              const PopupMenuItem(
                value: 'entrada',
                child: Text('Solo entradas'),
              ),
              const PopupMenuItem(
                value: 'salida',
                child: Text('Solo salidas'),
              ),
            ],
            onSelected: (value) async {
              setState(() => _selectedFilter = value);
              await _loadInitialData();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                // Botón para seleccionar fecha única
                ElevatedButton(
                  onPressed: () => _selectDate(context),
                  child: Text(
                    _selectedDate == null
                        ? 'Seleccionar día'
                        : DateFormat('dd/MM/yy').format(_selectedDate!),
                  ),
                ),
                const SizedBox(width: 8),
                // Botón para seleccionar rango de fechas
                ElevatedButton(
                  onPressed: () => _selectDateRange(context),
                  child: Text(
                    _dateRange == null
                        ? 'Seleccionar rango'
                        : '${DateFormat('dd/MM/yy').format(_dateRange!.start)} - ${DateFormat('dd/MM/yy').format(_dateRange!.end)}',
                  ),
                ),
                const SizedBox(width: 8),
                // Botón para limpiar filtros
                if (_selectedDate != null || _dateRange != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () async {
                      setState(() {
                        _selectedDate = null;
                        _dateRange = null;
                      });
                      await _loadInitialData();
                    },
                  ),
              ],
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
      floatingActionButton: FloatingActionButton(
        onPressed: _exportToCsv,
        child: const Icon(Icons.download),
        tooltip: 'Exportar a CSV',
      ),
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Icon(
          record['tipo'] == 'entrada' ? Icons.login : Icons.logout,
          color: record['tipo'] == 'entrada' ? Colors.green : Colors.red,
        ),
        title: Text(
          '${record['nombre'] ?? ''} ${record['apellido'] ?? ''}'.trim(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DNI: ${record['dni'] ?? 'No disponible'}'),
            Text('${record['siglas_facultad'] ?? ''} - ${record['siglas_escuela'] ?? ''}'),
            Text(fechaHora, style: const TextStyle(fontSize: 12)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              tipo,
              style: TextStyle(
                color: record['tipo'] == 'entrada' ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(hora, style: const TextStyle(fontSize: 12)),
          ],
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