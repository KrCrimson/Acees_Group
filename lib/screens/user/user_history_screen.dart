import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class GeneralHistoryScreen extends StatefulWidget {
  const GeneralHistoryScreen({super.key});

  @override
  State<GeneralHistoryScreen> createState() => _GeneralHistoryScreenState();
}

class _GeneralHistoryScreenState extends State<GeneralHistoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedFilter = 'todos';
  DateTimeRange? _dateRange;
  final int _itemsPerPage = 20;
  DocumentSnapshot? _lastDocument;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;

  final List<Map<String, dynamic>> _attendanceData = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _attendanceData.clear();
      _lastDocument = null;
      _hasMoreData = true;
    });
    await _loadMoreData();
  }

  Future<void> _loadMoreData() async {
    if (!_hasMoreData || _isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    try {
      Query query = _firestore.collection('asistencias')
          .orderBy('fecha_hora', descending: true)
          .limit(_itemsPerPage);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      // Aplicar filtros
      if (_selectedFilter != 'todos') {
        query = query.where('tipo', isEqualTo: _selectedFilter);
      }

      if (_dateRange != null) {
        query = query
            .where('fecha_hora', isGreaterThanOrEqualTo: _dateRange!.start)
            .where('fecha_hora', isLessThanOrEqualTo: _dateRange!.end);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        setState(() => _hasMoreData = false);
      } else {
        _lastDocument = snapshot.docs.last;
        setState(() {
          _attendanceData.addAll(snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              ...data,
              'id': doc.id,
              'fecha_hora': (data['fecha_hora'] as Timestamp).toDate(),
            };
          }).toList());
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      setState(() => _isLoadingMore = false);
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
      appBar: AppBar(
        title: const Text('Historial General'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInitialData,
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              setState(() => _selectedFilter = value);
              await _loadInitialData();
            },
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
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros
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
          
          // Listado
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollEndNotification &&
                    notification.metrics.extentAfter == 0 &&
                    _hasMoreData) {
                  _loadMoreData();
                }
                return false;
              },
              child: ListView.builder(
                itemCount: _attendanceData.length + (_hasMoreData ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= _attendanceData.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  
                  final record = _attendanceData[index];
                  return _buildAttendanceItem(record);
                },
              ),
            ),
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

  Widget _buildAttendanceItem(Map<String, dynamic> record) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Icon(
          record['tipo'] == 'entrada' ? Icons.login : Icons.logout,
          color: record['tipo'] == 'entrada' ? Colors.green : Colors.red,
        ),
        title: Text(record['nombre_completo'] ?? 'Sin nombre'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${record['siglas_facultad']} - ${record['siglas_escuela']}'),
            Text(
              DateFormat('dd/MM/yyyy HH:mm').format(record['fecha_hora']),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        trailing: Text(
          record['tipo'].toString().toUpperCase(),
          style: TextStyle(
            color: record['tipo'] == 'entrada' ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<void> _exportToCsv() async {
    // Implementación básica de exportación
    try {
      String csvContent = "Nombre,DNI,Código,Facultad,Escuela,Tipo,Fecha,Hora\n";
      
      for (var record in _attendanceData) {
        final date = DateFormat('dd/MM/yyyy').format(record['fecha_hora']);
        final time = DateFormat('HH:mm').format(record['fecha_hora']);
        
        csvContent += '"${record['nombre_completo']}",'
                     '"${record['dni']}",'
                     '"${record['codigo_universitario']}",'
                     '"${record['siglas_facultad']}",'
                     '"${record['siglas_escuela']}",'
                     '"${record['tipo']}",'
                     '"$date","$time"\n';
      }

      // Aquí deberías implementar la lógica para guardar el archivo
      // Por ejemplo usando el paquete share_plus para compartir
      debugPrint(csvContent);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Datos preparados para exportar (ver consola)')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al exportar: $e')),
      );
    }
  }
}