import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/presencia_model.dart';
import '../../models/decision_manual_model.dart';
import '../../services/autorizacion_service.dart';
import 'deep_search_view.dart';
import 'registro_visita_view.dart';


class PresenciaDashboardView extends StatefulWidget {
  final String guardiaId;
  final String guardiaNombre;

  const PresenciaDashboardView({
    Key? key,
    required this.guardiaId,
    required this.guardiaNombre,
  }) : super(key: key);

  @override
  State<PresenciaDashboardView> createState() => _PresenciaDashboardViewState();
}

class _PresenciaDashboardViewState extends State<PresenciaDashboardView>
    with TickerProviderStateMixin {
  final AutorizacionService _autorizacionService = AutorizacionService();

  late TabController _tabController;
  late TextEditingController _searchController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController = TextEditingController();
    _cargarDatos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);

    try {
      await Future.wait([
        _autorizacionService.cargarPresenciaActual(),
        _autorizacionService.cargarHistorialDecisiones(widget.guardiaId),
      ]);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al cargar datos: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Control de Presencia',
          style: GoogleFonts.lato(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargarDatos),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Presencia'),
            Tab(icon: Icon(Icons.history), text: 'Decisiones'),
            Tab(icon: Icon(Icons.analytics), text: 'Estadísticas'),
          ],
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                controller: _tabController,
                children: [
                  _buildPresenciaTab(),
                  _buildDecisionesTab(),
                  _buildEstadisticasTab(),
                ],
              ),
    );
  }

  Widget _buildPresenciaTab() {
    return AnimatedBuilder(
      animation: _autorizacionService,
      builder: (context, child) {
        final presencias = _autorizacionService.presenciaActual;
        final personasEnCampus = _autorizacionService.personasEnCampus;
        final personasLargoTiempo = _autorizacionService.personasLargoTiempo;

        return RefreshIndicator(
          onRefresh: _cargarDatos,
          child: CustomScrollView(
            slivers: [
              // Header con estadísticas rápidas
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'En Campus',
                          personasEnCampus.toString(),
                          Icons.people,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Largo Tiempo',
                          personasLargoTiempo.length.toString(),
                          Icons.access_time,
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Lista de personas en campus
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Personas en Campus',
                    style: GoogleFonts.lato(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
              ),

              presencias.isEmpty
                  ? SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No hay personas en el campus',
                            style: GoogleFonts.lato(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  : SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final presencia = presencias[index];
                      return _buildPresenciaCard(presencia);
                    }, childCount: presencias.length),
                  ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDecisionesTab() {
    return AnimatedBuilder(
      animation: _autorizacionService,
      builder: (context, child) {
        // Usar la lista filtrada en lugar de la lista cruda
        final decisiones = _autorizacionService.decisionesFiltradas;

        return RefreshIndicator(
          onRefresh: _cargarDatos,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Decisiones Recientes (24h)',
                        style: GoogleFonts.lato(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      // Barra de búsqueda
                      TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          _autorizacionService.setSearchQuery(value);
                        },
                        decoration: InputDecoration(
                          hintText: 'Buscar por nombre o DNI...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _autorizacionService.setSearchQuery('');
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Botón de Búsqueda Profunda
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const DeepSearchView(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.filter_list),
                          label: const Text('Búsqueda Profunda y Filtros'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),


                    ],
                  ),
                ),
              ),

              decisiones.isEmpty
                  ? SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No se encontraron resultados',
                            style: GoogleFonts.lato(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  : SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final decision = decisiones[index];
                      return _buildDecisionCard(decision);
                    }, childCount: decisiones.length),
                  ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEstadisticasTab() {
    return AnimatedBuilder(
      animation: _autorizacionService,
      builder: (context, child) {
        final stats = _autorizacionService.estadisticasDecisiones;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Estadísticas del Guardia',
                style: GoogleFonts.lato(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 20),

              // Tarjetas de estadísticas
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total Decisiones',
                      stats['total'].toString(),
                      Icons.fact_check,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      'Autorizadas',
                      stats['autorizadas'].toString(),
                      Icons.check_circle,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Denegadas',
                      stats['denegadas'].toString(),
                      Icons.cancel,
                      Colors.red,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      'Tasa Aprobación',
                      (stats['total'] ?? 0) > 0
                          ? '${(((stats['autorizadas'] ?? 0) / (stats['total'] ?? 1)) * 100).round()}%'
                          : '0%',
                      Icons.trending_up,
                      Colors.purple,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // Información del guardia
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.indigo[100],
                            child: Icon(
                              Icons.person,
                              color: Colors.indigo[700],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.guardiaNombre,
                                  style: GoogleFonts.lato(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'ID: ${widget.guardiaId}',
                                  style: GoogleFonts.lato(
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.lato(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: GoogleFonts.lato(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresenciaCard(PresenciaModel presencia) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              presencia.llevaVariasHoras
                  ? Colors.orange[100]
                  : Colors.green[100],
          child: Icon(
            Icons.person,
            color:
                presencia.llevaVariasHoras
                    ? Colors.orange[700]
                    : Colors.green[700],
          ),
        ),
        title: Text(presencia.estudianteNombre),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DNI: ${presencia.estudianteDni}'),
            Text('${presencia.facultad} - ${presencia.escuela}'),
            Text(
              'Entrada: ${presencia.puntoEntrada} - ${presencia.tiempoFormateado}',
            ),
          ],
        ),
        trailing: Icon(
          presencia.llevaVariasHoras ? Icons.warning : Icons.check_circle,
          color: presencia.llevaVariasHoras ? Colors.orange : Colors.green,
        ),
      ),
    );
  }

  Widget _buildDecisionCard(DecisionManualModel decision) {
    // Determinar estilo visual
    Color bgColor;
    Color iconColor;
    IconData icon;
    
    if (decision.tipoAcceso == 'salida') {
      // SALIDA: Rojo
      bgColor = Colors.red[50]!;
      iconColor = Colors.red[700]!;
      icon = Icons.logout;
    } else if (!decision.autorizado) {
      // ENTRADA DENEGADA: Amarillo/Naranja
      bgColor = Colors.orange[50]!;
      iconColor = Colors.orange[800]!;
      icon = Icons.warning_amber_rounded;
    } else {
      // ENTRADA AUTORIZADA: Verde
      bgColor = Colors.green[50]!;
      iconColor = Colors.green[700]!;
      icon = Icons.login;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: bgColor, // Color de fondo suave para toda la tarjeta
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.white,
          child: Icon(icon, color: iconColor),
        ),
        title: Text(
          decision.estudianteNombre,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DNI: ${decision.estudianteDni}'),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: iconColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    decision.tipoAcceso.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: iconColor,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  decision.autorizado ? 'AUTORIZADO' : 'DENEGADO',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: decision.autorizado ? Colors.green[700] : Colors.red[700],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            if (decision.razon.isNotEmpty) 
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Razón: ${decision.razon}',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            Text(
              decision.tiempoTranscurrido,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: decision.tipoAcceso == 'entrada' 
            ? PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.grey[700]),
                onSelected: (value) {
                  if (value == 'cambiar_estado') {
                    _mostrarDialogoCambioEstado(decision);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'cambiar_estado',
                    child: Row(
                      children: [
                        Icon(
                          decision.autorizado ? Icons.block : Icons.check_circle,
                          color: decision.autorizado ? Colors.red : Colors.green,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(decision.autorizado ? 'Denegar Acceso' : 'Autorizar Acceso'),
                      ],
                    ),
                  ),
                ],
              )
            : null, // No hay acciones para salidas
      ),
    );
  }

  void _mostrarDialogoCambioEstado(DecisionManualModel decision) {
    // Si está autorizado, vamos a denegar -> mostrar lista de razones
    // Si está denegado, vamos a autorizar -> confirmar y razón opcional
    
    if (decision.autorizado) {
      // CAMBIAR A DENEGADO
      final razones = [
        'Estado de ebriedad',
        'Otro',
        'Comportamiento agresivo',
        'Documento de identidad inválido',
        'Suspensión académica vigente',
        'Falta de uniforme/vestimenta inadecuada',
        'Portar objetos prohibidos',
        'Intento de suplantación de identidad',
        'Deuda administrativa pendiente',
        'Ingreso fuera de horario permitido',
        'Acompañante no autorizado',
        'Negativa a revisión de seguridad',
      ];

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Denegar Acceso (Corrección)'),
          content: Container(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: razones.length,
              separatorBuilder: (context, index) => Divider(),
              itemBuilder: (context, index) {
                final razon = razones[index];
                return ListTile(
                  title: Text(razon),
                  leading: Icon(Icons.block, color: Colors.red[300]),
                  onTap: () {
                    Navigator.pop(context);
                    _ejecutarCambioEstado(decision, 'denegado', razon);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar'),
            ),
          ],
        ),
      );
    } else {
      // CAMBIAR A AUTORIZADO
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Autorizar Acceso (Corrección)'),
          content: Text('¿Está seguro de cambiar el estado a AUTORIZADO?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _ejecutarCambioEstado(decision, 'autorizado', 'Corrección manual de guardia');
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: Text('Autorizar'),
            ),
          ],
        ),
      );
    }
  }

  void _ejecutarCambioEstado(DecisionManualModel decision, String nuevoEstado, String razon) async {
    try {
      await _autorizacionService.actualizarEstadoAsistencia(
        decision.id,
        nuevoEstado,
        razon,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Estado actualizado correctamente'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Recargar datos para reflejar cambios
      _cargarDatos();
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }



}
