import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../config/api_config.dart';

class BusRecommendationsView extends StatefulWidget {
  @override
  _BusRecommendationsViewState createState() => _BusRecommendationsViewState();
}

class _BusRecommendationsViewState extends State<BusRecommendationsView> {
  bool _loading = false;
  String? _error;
  List<dynamic> _recommendations = [];
  String _debugLog = 'Debug Log:\n';

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  void _addToDebugLog(String message) {
    setState(() {
      _debugLog += '${DateTime.now().toString().substring(11, 19)}: $message\n';
    });
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    _addToDebugLog('Cargando recomendaciones...');

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/ml/bus-recommendations'),
        headers: {'Content-Type': 'application/json'},
      );

      _addToDebugLog('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final horarios = data['horarios'];
        
        if (horarios != null && horarios is List) {
          _addToDebugLog('✅ Recomendaciones cargadas: ${horarios.length} horarios');
          setState(() {
            _recommendations = horarios;
            _loading = false;
          });
        } else {
          _addToDebugLog('⚠️ No hay horarios en la respuesta');
          setState(() {
            _recommendations = [];
            _error = data['mensaje'] ?? 'No hay datos disponibles';
            _loading = false;
          });
        }
      } else {
        final errorData = json.decode(response.body);
        final errorMsg = errorData['error'] ?? 'Error desconocido';
        _addToDebugLog('❌ Error ${response.statusCode}: $errorMsg');
        setState(() {
          _error = errorMsg;
          _loading = false;
        });
      }
    } catch (e) {
      _addToDebugLog('❌ Excepción: $e');
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Widget _buildList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: _recommendations.length,
      separatorBuilder: (_, __) => Divider(),
      itemBuilder: (context, index) {
        final rec = _recommendations[index];
        final hora = rec['hora'] ?? 0;
        final entradas = rec['entradas'] ?? 0;
        final salidas = rec['salidas'] ?? 0;
        final total = rec['total'] ?? 0;
        final buses = rec['buses_recomendados'] ?? 0;
        final esPico = rec['es_hora_pico'] ?? false;

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: esPico ? Colors.red : Colors.blue,
            child: Text(hora.toString(), style: TextStyle(color: Colors.white)),
          ),
          title: Text('Hora: ${hora.toString().padLeft(2, '0')}:00',
              style: TextStyle(
                  fontWeight: esPico ? FontWeight.bold : FontWeight.normal)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Entradas: $entradas | Salidas: $salidas'),
              Text('Total: $total personas'),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.directions_bus,
                  color: esPico ? Colors.red : Theme.of(context).primaryColor),
              SizedBox(height: 4),
              Text('$buses buses',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: esPico ? Colors.red : Colors.black)),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadRecommendations,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recomendaciones de Buses',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),

            // Botón simple
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _loading ? null : _loadRecommendations,
                  icon: Icon(Icons.refresh),
                  label: Text('Actualizar'),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Contenido principal
            if (_loading) Center(child: CircularProgressIndicator()),

            if (_error != null)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Error: $_error',
                            style: TextStyle(
                                color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            if (!_loading && _error == null && _recommendations.isNotEmpty)
              _buildList(),

            if (!_loading && _error == null && _recommendations.isEmpty)
              Center(
                child: Text(
                  'No hay recomendaciones disponibles',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),

            SizedBox(height: 24),

            // Terminal de debug
            Text(
              'Debug Terminal:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Container(
              width: double.infinity,
              height: 200,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SingleChildScrollView(
                child: Text(
                  _debugLog,
                  style: TextStyle(
                    color: Colors.green,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
