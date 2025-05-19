import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'user_history_screen.dart';

class UserScannerScreen extends StatefulWidget {
  const UserScannerScreen({super.key});

  @override
  State<UserScannerScreen> createState() => _UserScannerScreenState();
}

class _UserScannerScreenState extends State<UserScannerScreen> {
  final MobileScannerController _cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    detectionTimeoutMs: 1000,
  );
  
  bool _isProcessing = false;
  DateTime? _lastScanTime;
  Map<String, dynamic>? _currentStudent;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _scanCooldown = const Duration(seconds: 3);

  Future<void> _handleBarcodeScan(String barcode) async {
    if (_isProcessing || 
        (_lastScanTime != null && 
         DateTime.now().difference(_lastScanTime!) < _scanCooldown)) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final student = await _fetchStudentData(barcode);
      if (student == null) {
        _showToast("Alumno no encontrado");
        return;
      }

      setState(() => _currentStudent = student);
      await _registerAttendance(student);
      _showToast("Asistencia registrada");
      
    } catch (e) {
      _showToast("Error: ${e.toString()}");
    } finally {
      setState(() {
        _isProcessing = false;
        _lastScanTime = DateTime.now();
      });
    }
  }

  Future<Map<String, dynamic>?> _fetchStudentData(String barcode) async {
    final snapshot = await _firestore.collection('alumnos')
        .where(Filter.or(
          Filter('dni', isEqualTo: barcode),
          Filter('codigo_universitario', isEqualTo: barcode),
        ))
        .limit(1)
        .get();

    return snapshot.docs.isEmpty ? null : snapshot.docs.first.data();
  }

  Future<void> _registerAttendance(Map<String, dynamic> student) async {
  try {
    final attendanceType = await _determineAttendanceType(student['dni']);
    final now = DateTime.now();
    
    await _firestore.collection('asistencias').add({
      // Datos del alumno
      'dni': student['dni'],
      'codigo_universitario': student['codigo_universitario'],
      'nombre': student['nombre'],
      'apellido': student['apellido'],
      
      // Siglas
      'siglas_facultad': student['siglas_facultad'],
      'siglas_escuela': student['siglas_escuela'],
      
      // Campos nuevos
      'fecha': Timestamp.fromDate(now), // Fecha completa
      'hora': DateFormat('HH:mm').format(now), // Hora separada
      'tipo': attendanceType,
      'estado': 'activo',
      
      // Campo adicional para búsquedas
      'fecha_hora': Timestamp.fromDate(now), // Mantener para consultas
    });

    _showToast('Asistencia registrada: ${attendanceType.toUpperCase()}');
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

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro de Asistencia'),
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
        ],
      ),
      body: Column(
        children: [
          // Sección del escáner
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
                        break; // Procesar solo el primer código
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

          // Sección de información
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: _buildInfoSection(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const GeneralHistoryScreen(),
          ),
        );
      },
      icon: const Icon(Icons.history),
      label: const Text('Ver Historial'),
      backgroundColor: Colors.blue,
    ),
    floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildInfoSection() {
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
        const SizedBox(height: 16),
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
}