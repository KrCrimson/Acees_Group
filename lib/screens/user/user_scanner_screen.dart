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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
        // Navigate to visitor form if DNI is not found or does not exist
        final guardName = await _getGuardName();
        final assignedDoor = await _getAssignedDoor();

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VisitorFormScreen(
              dni: barcode,
              guardName: guardName,
              assignedDoor: assignedDoor,
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
      _showToast("Error: ${e.toString()}");
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
      'puerta': assignedDoor,
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
      appBar: AppBar(
        backgroundColor: Colors.indigo[700],
        title: Text(
          'Registro de Asistencia',
          style: GoogleFonts.lato(
            textStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: ValueListenableBuilder<TorchState>(
              valueListenable: _cameraController.torchState,
              builder: (context, state, _) {
                switch (state) {
                  case TorchState.off:
                    return const Icon(Icons.flash_off, color: Colors.grey);
                  case TorchState.on:
                    return const Icon(Icons.flash_on, color: Colors.yellow);
                }
              },
            ),
            onPressed: () => _cameraController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Cerrar sesión',
            onPressed: _signOut,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.qr_code_scanner), text: 'Asistencias'),
            Tab(icon: Icon(Icons.people), text: 'Externos'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Entrada por: '),
                Switch(
                  value: _isPrincipalEntrance,
                  onChanged: (val) {
                    setState(() {
                      _isPrincipalEntrance = val;
                    });
                  },
                  activeColor: Colors.indigo,
                  inactiveThumbColor: Colors.blueGrey,
                ),
                Text(_isPrincipalEntrance ? 'Principal' : 'Cochera'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                Column(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Stack(
                        children: [
                          MobileScanner(
                            controller: _cameraController,
                            onDetect: (capture) {
                              final barcodes = capture.barcodes;
                              for (final barcode in barcodes) {
                                if (barcode.rawValue != null) {
                                  _handleBarcodeScan(barcode.rawValue!);
                                  break;
                                }
                              }
                            },
                          ),
                          if (_isProcessing)
                            const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        child: _buildStudentInfoSection(),
                      ),
                    ),
                  ],
                ),
                _buildExternalVisitorsSection(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.indigo[700],
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const UserHistoryScreen(),
            ),
          );
        },
        icon: const Icon(Icons.history, color: Colors.white),
        label: Text(
          'Ver Historial',
          style: GoogleFonts.roboto(
            textStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}