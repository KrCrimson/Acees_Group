import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import 'dart:io';

class AdminReportScreen extends StatefulWidget {
  const AdminReportScreen({Key? key}) : super(key: key);

  @override
  State<AdminReportScreen> createState() => _AdminReportScreenState();
}

class _AdminReportScreenState extends State<AdminReportScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DateTimeRange? _dateRange;
  String _selectedTipo = 'todos';
  String _selectedFacultad = 'todas';
  String _selectedEscuela = 'todas';
  String _selectedTurno = 'todos';
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _asistencias = [];
  List<String> _facultades = [];
  List<String> _escuelas = [];

  @override
  void initState() {
    super.initState();
    _fetchFacultades();
    _loadAsistencias();
  }

  Future<void> _fetchFacultades() async {
    final snapshot = await _firestore.collection('facultades').get();
    setState(() {
      _facultades = snapshot.docs.map((e) => e['siglas'].toString()).toList();
    });
  }

  Future<void> _fetchEscuelas(String facultad) async {
    if (facultad == 'todas') {
      setState(() => _escuelas = []);
      return;
    }
    final snapshot = await _firestore
        .collection('escuelas')
        .where('siglas_facultad', isEqualTo: facultad)
        .get();
    setState(() {
      _escuelas = snapshot.docs.map((e) => e['siglas'].toString()).toList();
    });
  }

  Future<void> _loadAsistencias() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      Query query = _firestore.collection('asistencias')
          .orderBy('fecha_hora', descending: true)
          .limit(200);

      if (_dateRange != null) {
        final start = DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day, 0, 0, 0);
        final end = DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day, 23, 59, 59, 999);
        query = query
            .where('fecha_hora', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
            .where('fecha_hora', isLessThanOrEqualTo: Timestamp.fromDate(end));
      }

      if (_selectedTipo == 'entrada' || _selectedTipo == 'salida') {
        query = query.where('tipo', isEqualTo: _selectedTipo);
      }

      if (_selectedFacultad != 'todas') {
        query = query.where('siglas_facultad', isEqualTo: _selectedFacultad);
      }

      if (_selectedEscuela != 'todas' && _selectedEscuela.isNotEmpty) {
        query = query.where('siglas_escuela', isEqualTo: _selectedEscuela);
      }

      final snapshot = await query.get();

      // Filtro por turno (mañana/tarde) en memoria
      List<Map<String, dynamic>> asistencias = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        data['fecha_hora'] = (data['fecha_hora'] as Timestamp).toDate();
        return data;
      }).toList();

      if (_selectedTurno == 'mañana') {
        asistencias = asistencias.where((a) {
          final hora = (a['fecha_hora'] as DateTime).hour;
          return hora >= 8 && hora < 13;
        }).toList();
      } else if (_selectedTurno == 'tarde') {
        asistencias = asistencias.where((a) {
          final hora = (a['fecha_hora'] as DateTime).hour;
          return hora >= 13 && hora <= 21;
        }).toList();
      }

      setState(() {
        _asistencias = asistencias;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: ${e.toString()}\n'
            'Verifica que la colección y los campos coincidan exactamente en nombre y mayúsculas/minúsculas. '
            'Si el error es de índice, usa el enlace que da el error para crearlo de nuevo.';
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
      await _loadAsistencias();
    }
  }

  Future<void> _exportToCSV() async {
    if (_asistencias.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay datos para exportar.')),
      );
      return;
    }

    final headers = ['Nombre', 'Apellido', 'DNI', 'Facultad', 'Escuela', 'Fecha', 'Tipo'];
    final rows = _asistencias.map((a) {
      return [
        a['nombre'] ?? '',
        a['apellido'] ?? '',
        a['dni'] ?? '',
        a['siglas_facultad'] ?? '',
        a['siglas_escuela'] ?? '',
        DateFormat('dd/MM/yyyy HH:mm').format(a['fecha_hora']),
        a['tipo'] ?? '',
      ];
    }).toList();

    final csvContent = StringBuffer();
    csvContent.writeln(headers.join(','));
    for (var row in rows) {
      csvContent.writeln(row.map((e) => e.toString()).join(','));
    }

    final bytes = utf8.encode(csvContent.toString());
    final fileName = 'reporte_asistencias_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';

    try {
      await Share.shareXFiles([
        XFile.fromData(
          bytes,
          name: fileName,
          mimeType: 'text/csv',
        )
      ], text: 'Reporte de Asistencias');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al exportar: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.indigo[700],
        title: Text(
          'Reporte de Asistencias',
          style: GoogleFonts.lato(
            textStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadAsistencias,
          ),
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: _exportToCSV,
          ),
        ],
      ),
      body: Container(
        color: Colors.grey[100],
        child: Column(
          children: [
            _buildFiltros(context),
            const Divider(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(child: Text(_errorMessage!))
                      : _buildListado(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltros(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
            ),
            onPressed: () => _selectDateRange(context),
            child: Text(
              _dateRange == null
                  ? 'Seleccionar rango'
                  : (_dateRange!.start == _dateRange!.end
                      ? DateFormat('dd/MM/yy').format(_dateRange!.start)
                      : '${DateFormat('dd/MM/yy').format(_dateRange!.start)} - ${DateFormat('dd/MM/yy').format(_dateRange!.end)}'),
            ),
          ),
          const SizedBox(width: 8),
          if (_dateRange != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () async {
                setState(() {
                  _dateRange = null;
                });
                await _loadAsistencias();
              },
            ),
          const SizedBox(width: 8),
          // Tipo
          DropdownButton<String>(
            value: _selectedTipo,
            items: const [
              DropdownMenuItem(value: 'todos', child: Text('Todos')),
              DropdownMenuItem(value: 'entrada', child: Text('Entradas')),
              DropdownMenuItem(value: 'salida', child: Text('Salidas')),
            ],
            onChanged: (value) async {
              setState(() => _selectedTipo = value!);
              await _loadAsistencias();
            },
          ),
          const SizedBox(width: 8),
          // Facultad
          DropdownButton<String>(
            value: _selectedFacultad,
            items: [
              const DropdownMenuItem(value: 'todas', child: Text('Todas las facultades')),
              ..._facultades.map((f) => DropdownMenuItem(value: f, child: Text(f))),
            ],
            onChanged: (value) async {
              setState(() {
                _selectedFacultad = value!;
                _selectedEscuela = 'todas';
              });
              await _fetchEscuelas(_selectedFacultad);
              await _loadAsistencias();
            },
          ),
          const SizedBox(width: 8),
          // Escuela
          DropdownButton<String>(
            value: _selectedEscuela,
            items: [
              const DropdownMenuItem(value: 'todas', child: Text('Todas las escuelas')),
              ..._escuelas.map((e) => DropdownMenuItem(value: e, child: Text(e))),
            ],
            onChanged: (value) async {
              setState(() => _selectedEscuela = value!);
              await _loadAsistencias();
            },
          ),
          const SizedBox(width: 8),
          // Turno
          DropdownButton<String>(
            value: _selectedTurno,
            items: const [
              DropdownMenuItem(value: 'todos', child: Text('Todos los turnos')),
              DropdownMenuItem(value: 'mañana', child: Text('Mañana (8-12)')),
              DropdownMenuItem(value: 'tarde', child: Text('Tarde (13-21)')),
            ],
            onChanged: (value) async {
              setState(() => _selectedTurno = value!);
              await _loadAsistencias();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildListado() {
    if (_asistencias.isEmpty) {
      return const Center(child: Text('No se encontraron asistencias.'));
    }
    return ListView.builder(
      itemCount: _asistencias.length,
      padding: const EdgeInsets.all(8.0),
      itemBuilder: (context, index) {
        final a = _asistencias[index];
        final fechaHora = DateFormat('dd/MM/yyyy HH:mm').format(a['fecha_hora']);
        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          child: ListTile(
            leading: Icon(
              a['tipo'] == 'entrada' ? Icons.login : Icons.logout,
              color: a['tipo'] == 'entrada' ? Colors.green : Colors.red,
            ),
            title: Text(
              '${a['nombre'] ?? ''} ${a['apellido'] ?? ''}',
              style: GoogleFonts.roboto(fontWeight: FontWeight.w500),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DNI: ${a['dni'] ?? ''}'),
                Text('${a['siglas_facultad'] ?? ''} - ${a['siglas_escuela'] ?? ''}'),
                Text(fechaHora, style: const TextStyle(fontSize: 12)),
              ],
            ),
            trailing: Text(
              (a['tipo'] ?? '').toString().toUpperCase(),
              style: TextStyle(
                color: a['tipo'] == 'entrada' ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}
