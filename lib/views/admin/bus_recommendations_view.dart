import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';

class BusRecommendationsView extends StatefulWidget {
  @override
  _BusRecommendationsViewState createState() => _BusRecommendationsViewState();
}

class _BusRecommendationsViewState extends State<BusRecommendationsView> {
  bool _loading = true;
  String? _error;
  List<dynamic> _recommendations = [];

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/ml/bus-recommendations');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _recommendations = data['recommendations'] ?? [];
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Error: ${response.statusCode}';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error de conexión: $e';
        _loading = false;
      });
    }
  }

  Widget _buildList() {
    if (_recommendations.isEmpty) {
      return Center(child: Text('No hay recomendaciones disponibles'));
    }

    return ListView.separated(
      physics: NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: _recommendations.length,
      separatorBuilder: (_, __) => Divider(),
      itemBuilder: (context, index) {
        final rec = _recommendations[index];
  final hora = rec['hora'];
        final pred = rec['predicciones'] ?? {};
        final total = pred['total'] ?? 0;
        final entrada = pred['entrada'] ?? 0;
        final salida = pred['salida'] ?? 0;
        final buses = rec['recommendedBuses'] ?? 0;
        final confianza = (rec['confianza'] ?? 0).toString();

        return ListTile(
          leading: CircleAvatar(
            child: Text(hora.toString()),
          ),
          title: Text('Hora: ${hora.toString().padLeft(2, '0')}:00'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total estimado: $total — Entrada: $entrada, Salida: $salida'),
              Text('Confianza: $confianza'),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.directions_bus, color: Theme.of(context).primaryColor),
              SizedBox(height: 4),
              Text('$buses buses', style: TextStyle(fontWeight: FontWeight.bold)),
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
            if (_loading) Center(child: CircularProgressIndicator()),
            if (_error != null) Column(
              children: [
                Text(_error!, style: TextStyle(color: Colors.red)),
                SizedBox(height: 8),
                ElevatedButton(onPressed: _loadRecommendations, child: Text('Reintentar')),
              ],
            ),
            if (!_loading && _error == null) _buildList(),
          ],
        ),
      ),
    );
  }
}
