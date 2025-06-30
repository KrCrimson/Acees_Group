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
import 'dart:async'; // Para Timer
import 'dart:math'; // Para funciones matemáticas

class UserScannerScreen extends StatefulWidget {
  const UserScannerScreen({super.key});

  @override
  State<UserScannerScreen> createState() => _UserScannerScreenState();
}

class _UserScannerScreenState extends State<UserScannerScreen> with TickerProviderStateMixin {
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

  // Variables para el screensaver
  bool _isScreensaverActive = false;
  DateTime _lastActivityTime = DateTime.now();
  Timer? _inactivityTimer;
  Timer? _doorUpdateTimer;
  late AnimationController _screensaverAnimationController;
  late Animation<double> _fadeAnimation;
  static const Duration _inactivityTimeout = Duration(minutes: 5); // 5 minutos de inactividad
  static const Duration _doorUpdateInterval = Duration(minutes: 10); // Actualizar cada 10 minutos

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadGuardInfo();
    _initializeScreensaver();
  }

  void _initializeScreensaver() {
    // Inicializar la animación del screensaver
    _screensaverAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _screensaverAnimationController,
      curve: Curves.easeInOut,
    ));

    // Inicializar timer de inactividad
    _resetInactivityTimer();
    
    // Inicializar timer de actualización automática de puerta
    _startDoorUpdateTimer();
  }

  void _resetInactivityTimer() {
    if (!mounted) return;
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_inactivityTimeout, _activateScreensaver);
    _lastActivityTime = DateTime.now();
  }

  void _startDoorUpdateTimer() {
    _doorUpdateTimer = Timer.periodic(_doorUpdateInterval, (timer) {
      if (!_isScreensaverActive) {
        _loadGuardInfo(); // Actualizar información de puerta cada cierto tiempo
      }
    });
  }

  void _activateScreensaver() {
    if (!mounted) return;
    setState(() {
      _isScreensaverActive = true;
    });
    _screensaverAnimationController.forward();
  }

  void _deactivateScreensaver() {
    if (!mounted) return;
    setState(() {
      _isScreensaverActive = false;
    });
    _screensaverAnimationController.reverse();
    _resetInactivityTimer();
  }

  void _registerUserActivity() {
    _lastActivityTime = DateTime.now(); // Actualizar el tiempo de última actividad
    debugPrint('Actividad registrada: $_lastActivityTime');
    if (_isScreensaverActive) {
      _deactivateScreensaver();
    } else {
      _resetInactivityTimer();
    }
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
    _inactivityTimer?.cancel();
    _doorUpdateTimer?.cancel();
    _screensaverAnimationController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcodeScan(String barcode) async {
    // Registrar actividad del usuario
    _registerUserActivity();
    
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _registerUserActivity, // Registrar actividad en cualquier toque
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: Stack(
          children: [
            // Contenido principal
            _buildMainContent(),
            // Screensaver superpuesto
            if (_isScreensaverActive) _buildScreensaver(),
          ],
        ),
        floatingActionButton: _isScreensaverActive ? null : FloatingActionButton(
          backgroundColor: Colors.redAccent,
          tooltip: 'Cerrar sesión',
          child: const Icon(Icons.logout, color: Colors.white),
          onPressed: () {
            _registerUserActivity();
            _signOut();
          },
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  Widget _buildMainContent() {
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
              _registerUserActivity(); // Registrar actividad
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
                          onPressed: () {
                            _registerUserActivity(); // Registrar actividad al presionar
                            _loadGuardInfo();
                          },
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

  Widget _buildScreensaver() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.indigo.shade900,
                  Colors.purple.shade800,
                  Colors.deepPurple.shade900,
                ],
              ),
            ),
            child: GestureDetector(
              onTap: _deactivateScreensaver,
              child: Stack(
                children: [
                  // Animated background elements
                  Positioned.fill(
                    child: _buildAnimatedBackground(),
                  ),
                  // Main content
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // App logo or icon
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.1),
                            border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
                          ),
                          child: Icon(
                            Icons.security,
                            size: 80,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        // Title
                        Text(
                          'Sistema de Control de Accesos',
                          style: GoogleFonts.lato(
                            fontSize: 28,
                            fontWeight: FontWeight.w300,
                            color: Colors.white.withOpacity(0.9),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        
                        // Guard info
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Guardia de Servicio',
                                style: GoogleFonts.lato(
                                  fontSize: 16,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _guardName,
                                style: GoogleFonts.lato(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Puerta: $_assignedDoor',
                                style: GoogleFonts.lato(
                                  fontSize: 16,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        // Current time
                        StreamBuilder<DateTime>(
                          stream: Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return Container();
                            final now = snapshot.data!;
                            return Column(
                              children: [
                                Text(
                                  DateFormat('HH:mm:ss').format(now),
                                  style: GoogleFonts.lato(
                                    fontSize: 48,
                                    fontWeight: FontWeight.w300,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  DateFormat('EEEE, d MMMM yyyy', 'es').format(now),
                                  style: GoogleFonts.lato(
                                    fontSize: 18,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 48),
                        
                        // Instructions
                        Text(
                          'Toca la pantalla o escanea un código para continuar',
                          style: GoogleFonts.lato(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.6),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedBackground() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(seconds: 10),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Stack(
          children: [
            // Floating circles animation
            ...List.generate(6, (index) {
              final angle = (value * 2 * 3.14159) + (index * 3.14159 / 3);
              final size = 80.0 + (index * 20);
              final opacity = 0.1 - (index * 0.015);
              
              return Positioned(
                left: MediaQuery.of(context).size.width * 0.5 + (100 + index * 30) * cos(angle) - size / 2,
                top: MediaQuery.of(context).size.height * 0.5 + (100 + index * 30) * sin(angle) - size / 2,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(opacity),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}