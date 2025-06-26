import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'user_history_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts
import 'visitor_form_screen.dart'; // Import the visitor form screen
import 'dart:convert';
import 'package:http/http.dart' as http;

class UserScannerScreen extends StatefulWidget {
  const UserScannerScreen({super.key});

  @override
  State<UserScannerScreen> createState() => _UserScannerScreenState();
}

class _UserScannerScreenState extends State<UserScannerScreen> with SingleTickerProviderStateMixin {
  final MobileScannerController _cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    detectionTimeoutMs: 1000,
  );
  late TabController _tabController;
  bool _isProcessing = false;
  DateTime? _lastScanTime;
  Map<String, dynamic>? _currentStudent;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _scanCooldown = const Duration(seconds: 3);
  bool _isPrincipalEntrance = true; // true = Principal, false = Cochera
  final FlutterTts _flutterTts = FlutterTts();

  String _guardName = '';
  String _assignedDoor = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadGuardInfo();
  }

  Future<void> _loadGuardInfo() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final userDoc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(currentUser.uid)
        .get();
    setState(() {
      _guardName = '${userDoc.data()?['nombre'] ?? 'Desconocido'} ${userDoc.data()?['apellido'] ?? ''}';
      _assignedDoor = userDoc.data()?['puerta_acargo'] ?? 'Sin asignar';
    });
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _flutterTts.stop();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcodeScan(String barcode) async {
    if (_isProcessing || 
        (_lastScanTime != null && 
         DateTime.now().difference(_lastScanTime!) < _scanCooldown)) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final student = await _fetchStudentData(barcode);
      if (!mounted) return;

      if (student == null || student['dni'] == null) {
        // Buscar nombre externo en BD o API
        String? externalName;
        bool foundExtern = false;
        final extSnap = await _firestore.collection('externos')
            .where('dni', isEqualTo: barcode)
            .limit(1)
            .get();
        if (extSnap.docs.isNotEmpty) {
          externalName = extSnap.docs.first.data()['nombre'] as String?;
          foundExtern = true;
        } else {
          // Consultar API externa
          try {
            final response = await http.get(
              Uri.parse('https://api.apis.net.pe/v1/dni?numero=$barcode'),
              headers: {'Authorization': 'Bearer apis-token-16172.YnjI01QPbvQ2cuf5U3nsb5qOUgiLZ7tW'},
            );
            if (response.statusCode == 200) {
              final data = json.decode(response.body);
              externalName = data['nombre'] ?? '';
              if (externalName != null && externalName.isNotEmpty) {
                foundExtern = true;
              }
            } else {
              _showToast("No se pudo consultar el DNI en la API externa.");
            }
          } catch (e) {
            _showToast("Error de red al consultar API externa.");
          }
        }
        if (!foundExtern) {
          _showToast("DNI no encontrado en la base de datos ni en la API externa.");
          setState(() {
            _isProcessing = false;
            _lastScanTime = DateTime.now();
          });
          return;
        }
        final guardName = await _getGuardName();
        final assignedDoor = await _getAssignedDoor();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VisitorFormScreen(
              dni: barcode,
              guardName: guardName,
              assignedDoor: assignedDoor,
              nombre: externalName, // <-- Pasa el nombre aquí
            ),
          ),
        );
        return;
      }

      setState(() => _currentStudent = student);
      await _registerAttendance(student);
      _showToast("Asistencia registrada");
      // Reproducir nombre y apellido por bocinas
      await _speakStudentInfo(student);
      
    } catch (e) {
      _showToast("Error: [200b][200b${e.toString()}");
    } finally {
      setState(() {
        _isProcessing = false;
        _lastScanTime = DateTime.now();
      });
    }
  }

  Future<String> _getGuardName() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return 'Desconocido';

    final userDoc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(currentUser.uid)
        .get();

    final guardName = '${userDoc.data()?['nombre'] ?? 'Desconocido'} ${userDoc.data()?['apellido'] ?? 'Desconocido'}';
    return guardName;
  }

  Future<String> _getAssignedDoor() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return 'Sin asignar';

    final userDoc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(currentUser.uid)
        .get();

    return userDoc.data()?['puerta_acargo'] ?? 'Sin asignar';
  }

  Future<Map<String, dynamic>?> _fetchStudentData(String barcode) async {
    final snapshot = await _firestore.collection('alumnos')
        .where(Filter.or(
          Filter('dni', isEqualTo: barcode),
          Filter('codigo_universitario', isEqualTo: barcode),
        ))
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      debugPrint('Student not found with barcode: $barcode');
      return null;
    }
    return snapshot.docs.first.data();
  }

  Future<void> _registerAttendance(Map<String, dynamic> student) async {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception('Usuario no autenticado');

    final userDoc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(currentUser.uid)
        .get();

    final attendanceType = await _determineAttendanceType(student['dni']);
    final now = DateTime.now();

    // Fetch the guard's assigned door
    final guardSnapshot = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(currentUser.uid)
        .get();

    final guardData = guardSnapshot.data();
    final assignedDoor = guardData?['puerta_acargo'] ?? 'Sin asignar';

    // Registro en la colección 'asistencias'
    await _firestore.collection('asistencias').add({
      'dni': student['dni'],
      'codigo_universitario': student['codigo_universitario'],
      'nombre': student['nombre'],
      'apellido': student['apellido'],
      'siglas_facultad': student['siglas_facultad'],
      'siglas_escuela': student['siglas_escuela'],
      'fecha': Timestamp.fromDate(now),
      'hora': DateFormat('HH:mm').format(now),
      'tipo': attendanceType,
      'entrada_tipo': _isPrincipalEntrance ? 'principal' : 'cochera',
      'estado': 'activo',
      'fecha_hora': Timestamp.fromDate(now),
      'registrado_por': {
        'uid': currentUser.uid,
        'nombre': userDoc.data()?['nombre'] ?? 'Desconocido',
        'apellido': userDoc.data()?['apellido'] ?? 'Desconocido',
        'email': currentUser.email,
        'rango': userDoc.data()?['rango'] ?? 'Desconocido',
      },
      'puerta': assignedDoor, // Include the assigned door
    });

    // Registro en la colección 'registros' para historial de usuarios
    await _firestore.collection('registros').add({
      'registrador_uid': currentUser.uid,
      'registrador_nombre': userDoc.data()?['nombre'] ?? 'Desconocido',
      'registrador_apellido': userDoc.data()?['apellido'] ?? 'Desconocido',
      'registrador_email': currentUser.email,
      'alumno_dni': student['dni'],
      'alumno_nombre': student['nombre'],
      'alumno_apellido': student['apellido'],
      'tipo_asistencia': attendanceType,
      'entrada_tipo': _isPrincipalEntrance ? 'principal' : 'cochera',
      'fecha_hora': Timestamp.fromDate(now),
    });

    _showToast('Asistencia registrada: ${attendanceType.toUpperCase()} - ${_isPrincipalEntrance ? 'Principal' : 'Cochera'}');
  } catch (e) {
    _showToast('Error al registrar: ${e.toString()}');
    rethrow;
  }
}


  Future<String> _determineAttendanceType(String dni) async {
    final snapshot = await _firestore.collection('asistencias')
        .where('dni', isEqualTo: dni)
        .orderBy('fecha_hora', descending: true)
        .limit(1)
        .get();

    return snapshot.docs.isEmpty 
        ? 'entrada' 
        : (snapshot.docs.first.data()['tipo'] == 'entrada' ? 'salida' : 'entrada');
  }

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.CENTER,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.black54,
      textColor: Colors.white,
    );
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      // Add a small delay before navigating
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cerrar sesión: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _speakStudentInfo(Map<String, dynamic> student) async {
    final nombre = student['nombre'] ?? '';
    final apellido = student['apellido'] ?? '';
    final facultad = student['siglas_facultad'] ?? '';
    final escuela = student['siglas_escuela'] ?? '';
    final texto =
        'Asistencia registrada para $nombre $apellido, de la facultad $facultad, de la escuela $escuela';
    await _flutterTts.setLanguage('es-ES');
    await _flutterTts.setSpeechRate(0.5); // Slower speech rate
    await _flutterTts.speak(texto);
  }

  Widget _buildStudentInfoSection() {
    if (_currentStudent == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_scanner, size: 40, color: Colors.blue),
            SizedBox(height: 16),
            Text(
              'Escanea un código de barras de estudiante',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${_currentStudent!['nombre']} ${_currentStudent!['apellido']}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Chip(
              label: Text(_currentStudent!['siglas_facultad']),
              backgroundColor: Colors.blue[50],
            ),
            const SizedBox(width: 8),
            Chip(
              label: Text(_currentStudent!['siglas_escuela']),
              backgroundColor: Colors.green[50],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Entrada: ${_isPrincipalEntrance ? 'Cochera' : 'Principal'}',
          style: TextStyle(
            fontSize: 16,
            color: _isPrincipalEntrance ? Colors.blue : Colors.orange,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        if (_lastScanTime != null)
          Text(
            'Último registro: ${DateFormat('HH:mm:ss').format(_lastScanTime!)}',
            style: const TextStyle(color: Colors.grey),
          ),
        if (_isProcessing)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }

  Widget _buildExternalVisitorsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('externos').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No hay registros de externos.'));
        }

        final externalVisitors = snapshot.data!.docs;

        return ListView.builder(
          itemCount: externalVisitors.length,
          itemBuilder: (context, index) {
            final visitor = externalVisitors[index].data() as Map<String, dynamic>;
            return ListTile(
              leading: const Icon(Icons.person, color: Colors.blue),
              title: Text(visitor['nombre'] ?? 'Desconocido'),
              subtitle: Text('DNI: ${visitor['dni'] ?? 'Sin DNI'}'),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.indigo.withOpacity(0.9),
        elevation: 8,
        title: Text(
          'Escáner de Accesos',
          style: GoogleFonts.lato(
            textStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.amber),
            tooltip: 'Historial',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const UserHistoryScreen()),
              );
            },
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
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person, color: Colors.indigo, size: 28),
                            const SizedBox(width: 8),
                            Text(
                              _guardName,
                              style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.indigo[900]),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(Icons.door_front_door, color: Colors.teal, size: 26),
                            const SizedBox(width: 6),
                            Text(
                              _assignedDoor,
                              style: GoogleFonts.lato(fontSize: 16, color: Colors.teal[800], fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.sync, color: Colors.blueGrey),
                          tooltip: 'Actualizar puerta',
                          onPressed: _loadGuardInfo,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Center(
                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(28),
                    child: Container(
                      width: 340,
                      height: 420,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: MobileScanner(
                              controller: _cameraController,
                              onDetect: (BarcodeCapture capture) {
                                final barcode = capture.barcodes.first;
                                if (barcode.rawValue != null) {
                                  _handleBarcodeScan(barcode.rawValue!);
                                }
                              },
                            ),
                          ),
                          if (_isProcessing)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(color: Colors.amber),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (_currentStudent != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.badge, color: Colors.indigo, size: 28),
                              const SizedBox(width: 8),
                              Text(
                                _currentStudent!['nombre'] ?? '-',
                                style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.indigo[900]),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.credit_card, color: Colors.blueGrey, size: 22),
                              const SizedBox(width: 6),
                              Text(
                                'DNI: ${_currentStudent!['dni'] ?? '-'}',
                                style: GoogleFonts.lato(fontSize: 16, color: Colors.blueGrey[700]),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.school, color: Colors.green, size: 22),
                              const SizedBox(width: 6),
                              Text(
                                'Código: ${_currentStudent!['codigo_universitario'] ?? '-'}',
                                style: GoogleFonts.lato(fontSize: 16, color: Colors.green[700]),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.redAccent,
        tooltip: 'Cerrar sesión',
        child: const Icon(Icons.logout, color: Colors.white),
        onPressed: _signOut,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}