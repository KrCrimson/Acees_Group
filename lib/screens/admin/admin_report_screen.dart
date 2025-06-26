import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.indigo.withOpacity(0.9),
        elevation: 8,
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
            icon: const Icon(Icons.refresh, color: Colors.amber),
            tooltip: 'Refrescar',
            onPressed: _loadAsistencias,
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
                    child: _buildFiltros(context),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _errorMessage != null
                          ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                          : _buildListado(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFiltros(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              elevation: 2,
            ),
            icon: const Icon(Icons.date_range),
            onPressed: () => _selectDateRange(context),
            label: Text(
              _dateRange == null
                  ? 'Seleccionar rango'
                  : (_dateRange!.start == _dateRange!.end
                      ? DateFormat('dd/MM/yy').format(_dateRange!.start)
                      : '${DateFormat('dd/MM/yy').format(_dateRange!.start)} - ${DateFormat('dd/MM/yy').format(_dateRange!.end)}'),
            ),
          ),
          const SizedBox(width: 8),
          if (_dateRange != null)
            ActionChip(
              label: const Text('Limpiar'),
              avatar: const Icon(Icons.clear, size: 18),
              backgroundColor: Colors.red[100],
              onPressed: () async {
                setState(() {
                  _dateRange = null;
                });
                await _loadAsistencias();
              },
            ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _selectedTipo,
            dropdownColor: Colors.white,
            style: GoogleFonts.lato(color: Colors.indigo[900]),
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
          DropdownButton<String>(
            value: _selectedFacultad,
            dropdownColor: Colors.white,
            style: GoogleFonts.lato(color: Colors.indigo[900]),
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
          DropdownButton<String>(
            value: _selectedEscuela,
            dropdownColor: Colors.white,
            style: GoogleFonts.lato(color: Colors.indigo[900]),
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
          DropdownButton<String>(
            value: _selectedTurno,
            dropdownColor: Colors.white,
            style: GoogleFonts.lato(color: Colors.indigo[900]),
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
      return Center(
        child: Text('No hay asistencias registradas.',
            style: GoogleFonts.lato(fontSize: 18, color: Colors.white)),
      );
    }
    return ListView.builder(
      itemCount: _asistencias.length,
      itemBuilder: (context, index) {
        final asistencia = _asistencias[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: asistencia['tipo'] == 'entrada' ? Colors.green[200] : Colors.red[200],
                child: Icon(
                  asistencia['tipo'] == 'entrada' ? Icons.login : Icons.logout,
                  color: asistencia['tipo'] == 'entrada' ? Colors.green[900] : Colors.red[900],
                ),
              ),
              title: Text(
                '${asistencia['nombre']} ${asistencia['apellido']}',
                style: GoogleFonts.lato(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DNI: ${asistencia['dni']}'),
                  Text('Facultad: ${asistencia['siglas_facultad'] ?? '-'}'),
                  Text('Escuela: ${asistencia['siglas_escuela'] ?? '-'}'),
                  Text('Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(asistencia['fecha_hora'])}'),
                  Text('Tipo: ${asistencia['tipo']}'),
                  Text('Registrado por: ${asistencia['registrado_por']?['nombre'] ?? '-'}'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
