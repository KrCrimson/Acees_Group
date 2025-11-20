import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../viewmodels/deep_search_viewmodel.dart';
import '../../models/decision_manual_model.dart';

class DeepSearchView extends StatelessWidget {
  const DeepSearchView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DeepSearchViewModel()..loadFullHistory(),
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text(
            'Búsqueda Profunda',
            style: GoogleFonts.lato(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.indigo[700],
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Consumer<DeepSearchViewModel>(
          builder: (context, viewModel, child) {
            return Column(
              children: [
                _buildFiltersSection(context, viewModel),
                Expanded(
                  child: viewModel.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildResultsList(viewModel),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFiltersSection(BuildContext context, DeepSearchViewModel viewModel) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barra de búsqueda
          TextField(
            onChanged: viewModel.setSearchQuery,
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o DNI...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          
          // Filtros de Fecha
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(
                    viewModel.startDate == null
                        ? 'Rango de Fechas'
                        : '${viewModel.startDate!.day}/${viewModel.startDate!.month} - ${viewModel.endDate?.day}/${viewModel.endDate?.month}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      initialDateRange: viewModel.startDate != null && viewModel.endDate != null
                          ? DateTimeRange(start: viewModel.startDate!, end: viewModel.endDate!)
                          : null,
                    );
                    if (picked != null) {
                      viewModel.setDateRange(picked.start, picked.end);
                    }
                  },
                ),
              ),
              if (viewModel.startDate != null)
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => viewModel.setDateRange(null, null),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Filtros de Facultad y Escuela
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: viewModel.selectedFacultySiglas,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Facultad',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todas')),
                    ...viewModel.facultades.map((f) => DropdownMenuItem(
                      value: f['siglas'],
                      child: Text(
                        f['siglas']!,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )),
                  ],
                  onChanged: viewModel.setFaculty,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: viewModel.selectedSchoolSiglas,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Escuela',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todas')),
                    ...viewModel.escuelasDisponibles.map((e) => DropdownMenuItem(
                      value: e['siglas'],
                      child: Text(
                        e['siglas']!,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )),
                  ],
                  onChanged: viewModel.selectedFacultySiglas == null 
                      ? null // Deshabilitar si no hay facultad seleccionada
                      : viewModel.setSchool,
                ),
              ),
            ],
          ),
          
          if (viewModel.selectedFacultySiglas != null || viewModel.startDate != null || viewModel.decisions.length != viewModel.decisions.length) // Simple check logic
             Padding(
               padding: const EdgeInsets.only(top: 8.0),
               child: Align(
                 alignment: Alignment.centerRight,
                 child: TextButton(
                   onPressed: viewModel.clearFilters,
                   child: const Text('Limpiar Filtros', style: TextStyle(color: Colors.red)),
                 ),
               ),
             ),
        ],
      ),
    );
  }

  Widget _buildResultsList(DeepSearchViewModel viewModel) {
    if (viewModel.decisions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No se encontraron resultados',
              style: GoogleFonts.lato(fontSize: 16, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: viewModel.decisions.length,
      itemBuilder: (context, index) {
        final decision = viewModel.decisions[index];
        return _buildDecisionCard(decision);
      },
    );
  }

  Widget _buildDecisionCard(DecisionManualModel decision) {
    // Reutilizamos el diseño de tarjeta existente o uno similar
    Color iconColor = decision.autorizado ? Colors.green[700]! : Colors.red[700]!;
    IconData icon = decision.autorizado ? Icons.check_circle : Icons.cancel;
    if (decision.tipoAcceso == 'salida') {
      icon = Icons.logout;
      iconColor = Colors.blue[700]!;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.1),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(
          decision.estudianteNombre,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DNI: ${decision.estudianteDni}'),
            Text(
              '${decision.datosEstudiante?['facultad'] ?? '-'} / ${decision.datosEstudiante?['escuela'] ?? '-'}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            Text(
              '${decision.timestamp.day}/${decision.timestamp.month}/${decision.timestamp.year} ${decision.timestamp.hour}:${decision.timestamp.minute.toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 12, color: Colors.grey[800]),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              decision.tipoAcceso.toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: iconColor,
                fontSize: 12,
              ),
            ),
            if (!decision.autorizado)
              const Text(
                'DENEGADO',
                style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }
}
