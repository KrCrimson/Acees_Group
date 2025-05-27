import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminReportScreen extends StatefulWidget {
  const AdminReportScreen({super.key});

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
    final snapshot = await _firestore.collection('Facultades').get();
    setState(() {
      // Permite siglas con mayúscula inicial
      _facultades = snapshot.docs.map((e) => e['siglas'].toString()).toList();
    });
  }

  Future<void> _fetchEscuelas(String facultad) async {
    if (facultad == 'todas') {
      setState(() => _escuelas = []);
      return;
    }
    final snapshot = await _firestore
        .collection('Escuelas')
        .where('siglas_facultad', isEqualTo: facultad)
        .get();
    setState(() {
      // Permite siglas con mayúscula inicial
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

      // Filtro por rango de fechas
      if (_dateRange != null) {
        final start = DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day, 0, 0, 0);
        final end = DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day, 23, 59, 59, 999);
        query = query
            .where('fecha_hora', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
            .where('fecha_hora', isLessThanOrEqualTo: Timestamp.fromDate(end));
      }

      // Filtro por tipo
      if (_selectedTipo == 'entrada' || _selectedTipo == 'salida') {
        query = query.where('tipo', isEqualTo: _selectedTipo);
      }

      // Filtro por facultad
      if (_selectedFacultad != 'todas') {
        query = query.where('siglas_facultad', isEqualTo: _selectedFacultad);
      }

      // Filtro por escuela
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
        _errorMessage = 'Error: ${e.toString()}';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte de Asistencias'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAsistencias,
          ),
        ],
      ),
      body: Column(
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
    );
  }

  Widget _buildFiltros(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Rango de fechas
          ElevatedButton(
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
      itemBuilder: (context, index) {
        final a = _asistencias[index];
        final fechaHora = DateFormat('dd/MM/yyyy HH:mm').format(a['fecha_hora']);
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: Icon(
              a['tipo'] == 'entrada' ? Icons.login : Icons.logout,
              color: a['tipo'] == 'entrada' ? Colors.green : Colors.red,
            ),
            title: Text('${a['nombre'] ?? ''} ${a['apellido'] ?? ''}'),
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
