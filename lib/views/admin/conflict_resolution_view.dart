import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/sync_service.dart';
import '../../widgets/custom_button.dart';

class ConflictResolutionView extends StatefulWidget {
  final List<ConflictData> conflicts;
  final Function(List<ConflictData>) onConflictsResolved;

  const ConflictResolutionView({
    Key? key,
    required this.conflicts,
    required this.onConflictsResolved,
  }) : super(key: key);

  @override
  State<ConflictResolutionView> createState() => _ConflictResolutionViewState();
}

class _ConflictResolutionViewState extends State<ConflictResolutionView> {
  final List<ConflictData> _resolvedConflicts = [];
  final Map<String, ConflictResolution> _resolutions = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Resolver Conflictos de Sincronización'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Consumer<SyncService>(
        builder: (context, syncService, child) {
          if (widget.conflicts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 80, color: Colors.green),
                  SizedBox(height: 16),
                  Text(
                    'No hay conflictos pendientes',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Header con información de conflictos
              Container(
                padding: EdgeInsets.all(16),
                color: Colors.orange[50],
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange[700]),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Conflictos de Sincronización Detectados',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[700],
                            ),
                          ),
                          Text(
                            '${widget.conflicts.length} elementos necesitan resolución manual',
                            style: TextStyle(color: Colors.orange[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Lista de conflictos
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: widget.conflicts.length,
                  itemBuilder: (context, index) {
                    final conflict = widget.conflicts[index];
                    return _buildConflictCard(conflict, index);
                  },
                ),
              ),

              // Botones de acción
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _resolveAllWithServer,
                            child: Text('Usar Datos del Servidor'),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _resolveAllWithLocal,
                            child: Text('Usar Datos Locales'),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    CustomButton(
                      text: 'Aplicar Resoluciones',
                      width: double.infinity,
                      onPressed:
                          _resolutions.length == widget.conflicts.length
                              ? _applyResolutions
                              : null,
                      isLoading: syncService.isLoading,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildConflictCard(ConflictData conflict, int index) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header del conflicto
            Row(
              children: [
                Icon(Icons.merge_type, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${conflict.collection} - ${conflict.id}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Chip(
                  label: Text(
                    conflict.conflictType,
                    style: TextStyle(fontSize: 12, color: Colors.white),
                  ),
                  backgroundColor: Colors.red[400],
                ),
              ],
            ),

            SizedBox(height: 12),

            // Información de timestamps
            Row(
              children: [
                Expanded(
                  child: _buildTimestampInfo(
                    'Servidor',
                    conflict.serverTimestamp,
                    Colors.blue,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildTimestampInfo(
                    'Local',
                    conflict.localTimestamp,
                    Colors.green,
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            // Comparación de datos
            _buildDataComparison(conflict),

            SizedBox(height: 16),

            // Opciones de resolución
            Text(
              'Seleccionar resolución:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            _buildResolutionOptions(conflict),
          ],
        ),
      ),
    );
  }

  Widget _buildTimestampInfo(String label, DateTime timestamp, Color color) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 12,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '${timestamp.day}/${timestamp.month} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
            style: TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildDataComparison(ConflictData conflict) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cambios detectados:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          SizedBox(height: 8),
          ...conflict.serverData.keys
              .where(
                (key) => conflict.serverData[key] != conflict.localData[key],
              )
              .take(3)
              .map((key) => _buildFieldComparison(key, conflict)),
        ],
      ),
    );
  }

  Widget _buildFieldComparison(String field, ConflictData conflict) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$field:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              'Servidor: ${conflict.serverData[field]} | Local: ${conflict.localData[field]}',
              style: TextStyle(fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResolutionOptions(ConflictData conflict) {
    return Column(
      children: [
        RadioListTile<ConflictResolution>(
          title: Text(
            'Usar datos del servidor',
            style: TextStyle(fontSize: 14),
          ),
          subtitle: Text(
            'Los datos remotos sobrescribirán los locales',
            style: TextStyle(fontSize: 12),
          ),
          value: ConflictResolution.serverWins,
          groupValue: _resolutions[conflict.id],
          onChanged:
              (value) => setState(() => _resolutions[conflict.id] = value!),
          dense: true,
        ),
        RadioListTile<ConflictResolution>(
          title: Text('Usar datos locales', style: TextStyle(fontSize: 14)),
          subtitle: Text(
            'Los datos locales sobrescribirán los remotos',
            style: TextStyle(fontSize: 12),
          ),
          value: ConflictResolution.clientWins,
          groupValue: _resolutions[conflict.id],
          onChanged:
              (value) => setState(() => _resolutions[conflict.id] = value!),
          dense: true,
        ),
        RadioListTile<ConflictResolution>(
          title: Text('Fusionar datos', style: TextStyle(fontSize: 14)),
          subtitle: Text(
            'Combinar ambos conjuntos de datos automáticamente',
            style: TextStyle(fontSize: 12),
          ),
          value: ConflictResolution.merge,
          groupValue: _resolutions[conflict.id],
          onChanged:
              (value) => setState(() => _resolutions[conflict.id] = value!),
          dense: true,
        ),
      ],
    );
  }

  void _resolveAllWithServer() {
    setState(() {
      for (var conflict in widget.conflicts) {
        _resolutions[conflict.id] = ConflictResolution.serverWins;
      }
    });
  }

  void _resolveAllWithLocal() {
    setState(() {
      for (var conflict in widget.conflicts) {
        _resolutions[conflict.id] = ConflictResolution.clientWins;
      }
    });
  }

  void _applyResolutions() async {
    final syncService = Provider.of<SyncService>(context, listen: false);

    try {
      for (var conflict in widget.conflicts) {
        final resolution = _resolutions[conflict.id];
        if (resolution != null) {
          await syncService.resolveConflict(conflict.id, resolution);
          _resolvedConflicts.add(conflict);
        }
      }

      // Notificar que los conflictos han sido resueltos
      widget.onConflictsResolved(_resolvedConflicts);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Conflictos resueltos exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al resolver conflictos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
