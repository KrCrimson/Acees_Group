import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import 'dart:typed_data';

// Asegura que la clase esté exportada correctamente
class PendingAllExitScreen extends StatefulWidget {
  const PendingAllExitScreen({Key? key}) : super(key: key);

  @override
  State<PendingAllExitScreen> createState() => _PendingAllExitScreenState();
}

class _PendingAllExitScreenState extends State<PendingAllExitScreen> {
  // Obtiene alumnos cuyo último registro es una entrada sin salida
  Stream<List<Map<String, dynamic>>> _getAlumnosSinSalida() async* {
    final snapshot = await FirebaseFirestore.instance
        .collection('asistencias')
        .orderBy('fecha_hora', descending: true)
        .get();
    final Map<String, Map<String, dynamic>> ultimoRegistroPorDni = {};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final dni = data['dni'] ?? '';
      if (dni.isEmpty) continue;
      if (!ultimoRegistroPorDni.containsKey(dni)) {
        ultimoRegistroPorDni[dni] = data;
      }
    }
    // Solo los que su último registro es 'entrada'
    final pendientes = ultimoRegistroPorDni.values.where((e) => e['tipo'] == 'entrada').toList();
    yield pendientes;
  }

  Future<void> _exportToCsv(List<Map<String, dynamic>> alumnos) async {
    try {
      String csvContent = "Nombre,DNI,Fecha,Facultad,Puerta\n";
      for (var data in alumnos) {
        final fecha = (data['fecha_hora'] as Timestamp?)?.toDate();
        csvContent += '"${data['nombre'] ?? ''}",'
                      '"${data['dni'] ?? ''}",'
                      '"${fecha != null ? DateFormat('dd/MM/yyyy HH:mm').format(fecha) : ''}",'
                      '"${data['facultad'] ?? ''}",'
                      '"${data['puerta'] ?? ''}"\n';
      }
      final bytes = utf8.encode(csvContent);
      final file = XFile.fromData(
        Uint8List.fromList(bytes),
        mimeType: 'text/csv',
        name: 'alumnos_pendientes_salida_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
      );
      await Share.shareXFiles([file], text: 'Alumnos pendientes de salida');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al exportar: \\${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.red[700]?.withOpacity(0.92),
        elevation: 8,
        title: Text(
          'Alumnos sin salida registrada',
          style: GoogleFonts.lato(
            textStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFCDD2),
              Color(0xFFB71C1C),
            ],
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _getAlumnosSinSalida(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.celebration, color: Colors.green[300], size: 60),
                      const SizedBox(height: 12),
                      Text(
                        '¡No hay alumnos pendientes de salida!',
                        style: GoogleFonts.lato(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }
              final alumnos = snapshot.data!;
              return ListView.builder(
                itemCount: alumnos.length,
                padding: const EdgeInsets.symmetric(vertical: 16),
                itemBuilder: (context, index) {
                  final data = alumnos[index];
                  final fecha = (data['fecha_hora'] as Timestamp?)?.toDate();
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(18),
                      border: Border(
                        left: BorderSide(color: Colors.red[700]!, width: 7),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red[200]!.withOpacity(0.18),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      leading: CircleAvatar(
                        backgroundColor: Colors.red[100],
                        radius: 28,
                        child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 32),
                      ),
                      title: Text(
                        data['nombre'] ?? 'Desconocido',
                        style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 19, color: Colors.red[900]),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 2),
                          Text('DNI: ${data['dni'] ?? '-'}', style: GoogleFonts.lato(fontSize: 15, color: Colors.blueGrey[800])),
                          Text('Fecha: ${fecha != null ? DateFormat('dd/MM/yyyy HH:mm').format(fecha) : '-'}', style: GoogleFonts.lato(fontSize: 15, color: Colors.indigo[700])),
                          Text('Facultad: ${data['facultad'] ?? '-'} | Puerta: ${data['puerta'] ?? '-'}', style: GoogleFonts.lato(fontSize: 15, color: Colors.deepPurple)),
                        ],
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '¡Sin salida!',
                          style: GoogleFonts.lato(fontWeight: FontWeight.bold, color: Colors.red[800], fontSize: 13),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
      floatingActionButton: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _getAlumnosSinSalida(),
        builder: (context, snapshot) {
          final alumnos = snapshot.data ?? [];
          return FloatingActionButton.extended(
            backgroundColor: Colors.redAccent,
            icon: const Icon(Icons.download, color: Colors.white),
            label: const Text('Exportar CSV', style: TextStyle(color: Colors.white)),
            onPressed: alumnos.isEmpty ? null : () => _exportToCsv(alumnos),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
