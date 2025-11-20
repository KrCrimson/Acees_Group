import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../viewmodels/registro_visita_viewmodel.dart';

class RegistroVisitaView extends StatelessWidget {
  const RegistroVisitaView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RegistroVisitaViewModel(),
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text(
            'Registrar Visita Externa',
            style: GoogleFonts.lato(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.indigo[700],
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Consumer<RegistroVisitaViewModel>(
          builder: (context, viewModel, child) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tarjeta de Búsqueda DNI
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Identificación',
                            style: GoogleFonts.lato(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo[900],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  keyboardType: TextInputType.number,
                                  maxLength: 8,
                                  decoration: InputDecoration(
                                    labelText: 'DNI',
                                    hintText: 'Ingrese 8 dígitos',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    counterText: '',
                                    prefixIcon: const Icon(Icons.badge),
                                  ),
                                  onChanged: viewModel.setDni,
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: viewModel.isLoading ? null : viewModel.buscarDni,
                                icon: viewModel.isLoading 
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.search),
                                label: const Text('Buscar'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                  backgroundColor: Colors.indigo,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Checkbox Manual
                          CheckboxListTile(
                            title: const Text('Ingreso Manual de Datos'),
                            subtitle: const Text('Activar si no hay conexión con RENIEC'),
                            value: viewModel.isManualMode,
                            onChanged: (val) => viewModel.toggleManualMode(val ?? false),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            activeColor: Colors.indigo,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),

                  // Tarjeta de Datos Personales
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Datos del Visitante',
                            style: GoogleFonts.lato(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo[900],
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            key: ValueKey(viewModel.isManualMode),
                            enabled: viewModel.isManualMode,
                            decoration: InputDecoration(
                              labelText: 'Nombre Completo',
                              hintText: 'Nombres y Apellidos',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              prefixIcon: const Icon(Icons.person),
                              filled: !viewModel.isManualMode,
                              fillColor: viewModel.isManualMode ? null : Colors.grey[100],
                            ),
                            controller: TextEditingController(text: viewModel.nombreCompleto)
                              ..selection = TextSelection.collapsed(offset: viewModel.nombreCompleto.length),
                            onChanged: viewModel.setNombreCompleto,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Tarjeta de Detalle de Visita
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Detalle de la Visita',
                            style: GoogleFonts.lato(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo[900],
                            ),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: viewModel.selectedRazon,
                            decoration: InputDecoration(
                              labelText: 'Motivo de Visita',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              prefixIcon: const Icon(Icons.assignment),
                            ),
                            items: viewModel.razones.map((razon) {
                              return DropdownMenuItem(
                                value: razon,
                                child: Text(razon),
                              );
                            }).toList(),
                            onChanged: viewModel.setRazon,
                          ),

                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Mensaje de Error
                  if (viewModel.errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              viewModel.errorMessage!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Botón de Registro
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: viewModel.isLoading 
                          ? null 
                          : () async {
                              final success = await viewModel.registrarVisita();
                              if (success && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Visita registrada correctamente'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                Navigator.pop(context);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: viewModel.isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'REGISTRAR INGRESO',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
