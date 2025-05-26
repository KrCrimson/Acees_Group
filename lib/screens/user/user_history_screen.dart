import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';

class UserHistoryScreen extends StatefulWidget {
  const UserHistoryScreen({super.key});

  @override
  State<UserHistoryScreen> createState() => _UserHistoryScreenState();
}

class _UserHistoryScreenState extends State<UserHistoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedFilter = 'todos';
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

    Query query = _firestore.collection('asistencias')
        .orderBy('fecha_hora', descending: true)
        .limit(100);

    if (_selectedFilter == 'entrada' || _selectedFilter == 'salida') {
      query = query.where('tipo', isEqualTo: _selectedFilter);
    } else if (_selectedFilter == 'mis_registros') {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        query = query.where('registrado_por.uid', isEqualTo: currentUser.uid);
      }
    }

    if (_dateRange != null) {
      query = query
          .where('fecha_hora', isGreaterThanOrEqualTo: _dateRange!.start)
          .where('fecha_hora', isLessThanOrEqualTo: _dateRange!.end);
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
    debugPrint('Error loading data: $e');
    setState(() {
      _errorMessage = 'Error al cargar datos: ${e.toString()}';
      _isLoading = false;
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
      setState(() => _dateRange = picked);
      await _loadInitialData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Asistencias'),
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
              const PopupMenuItem(
                value: 'mis_registros',
                child: Text('Mis registros'),
              ),
            ],
            onSelected: (value) async {
              setState(() => _selectedFilter = value);
              await _loadInitialData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
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
                ElevatedButton(
                  onPressed: () => _selectDateRange(context),
                  child: Text(
                    _dateRange == null
                        ? 'Seleccionar fechas'
                        : '${DateFormat('dd/MM/yy').format(_dateRange!.start)} - ${DateFormat('dd/MM/yy').format(_dateRange!.end)}',
                  ),
                ),
                const SizedBox(width: 8),
                if (_dateRange != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () async {
                      setState(() => _dateRange = null);
                      await _loadInitialData();
                    },
                  ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _exportToCsv(),
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
      return const Center(child: Text('No se encontraron registros'));
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
  final registradoPor = record['registrado_por'] as Map<String, dynamic>?;
  
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
          Text(
            DateFormat('dd/MM/yyyy HH:mm').format(record['fecha_hora']),
            style: const TextStyle(fontSize: 12),
          ),
          if (registradoPor != null)
            Text(
              'Registrado por: ${registradoPor['nombre']} ${registradoPor['apellido']}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          // En el método _buildAttendanceItem
        Text('Entrada: ${record['entrada_tipo'] == 'principal' ? 'Principal' : 'Cochera'}',
          style: TextStyle(
            color: record['entrada_tipo'] == 'principal' ? Colors.blue : Colors.orange,
          ),
        ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            record['tipo']?.toString().toUpperCase() ?? '',
            style: TextStyle(
              color: record['tipo'] == 'entrada' ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            record['hora'] ?? DateFormat('HH:mm').format(record['fecha_hora']),
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

    Future<void> _exportToCsv() async {
    try {
      String csvContent = "Nombre,Apellido,DNI,Código,Facultad,Escuela,Tipo,Fecha,Hora,Registrado Por\n";
      
      for (var record in _attendanceData) {
        final date = DateFormat('dd/MM/yyyy').format(record['fecha_hora']);
        final time = record['hora'] ?? DateFormat('HH:mm').format(record['fecha_hora']);
        final registradoPor = record['registrado_por'] as Map<String, dynamic>?;
        
        csvContent += '"${record['nombre'] ?? ''}",'
                    '"${record['apellido'] ?? ''}",'
                    '"${record['dni'] ?? ''}",'
                    '"${record['codigo_universitario'] ?? ''}",'
                    '"${record['siglas_facultad'] ?? ''}",'
                    '"${record['siglas_escuela'] ?? ''}",'
                    '"${record['tipo'] ?? ''}",'
                    '"$date","$time",'
                    '"${registradoPor?['nombre'] ?? ''} ${registradoPor?['apellido'] ?? ''}"\n';
      }

      final bytes = utf8.encode(csvContent);
      final file = XFile.fromData(
        Uint8List.fromList(bytes),
        mimeType: 'text/csv',
        name: 'asistencias_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv'
      );

      if (!mounted) return;
      await Share.shareXFiles([file], text: 'Exportación de asistencias');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al exportar: ${e.toString()}')),
      );
    }
  }
}