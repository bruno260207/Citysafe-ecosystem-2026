import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/incident.dart';
import '../services/api_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<Incident> _incidents = [];
  bool _isLoading = true;
  bool _showHeatmap = true;

  @override
  void initState() {
    super.initState();
    _loadIncidents();
  }

  Future<void> _loadIncidents() async {
    try {
      final incidents = await ApiService().fetchIncidents();
      setState(() {
        _incidents = incidents;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al cargar incidentes')),
        );
      }
    }
  }

  // Agrupa incidentes cercanos en zonas (radio ~500m)
  List<_Zone> _calcularZonas() {
    List<_Zone> zonas = [];

    for (final inc in _incidents) {
      bool encontrado = false;
      for (final zona in zonas) {
        final dist = _distancia(inc.latitude, inc.longitude, zona.lat, zona.lng);
        if (dist < 0.005) { // ~500 metros
          zona.incidentes.add(inc);
          encontrado = true;
          break;
        }
      }
      if (!encontrado) {
        zonas.add(_Zone(inc.latitude, inc.longitude, [inc]));
      }
    }
    return zonas;
  }

  double _distancia(double lat1, double lng1, double lat2, double lng2) {
    return ((lat1 - lat2).abs() + (lng1 - lng2).abs());
  }

  Color _colorZona(_Zone zona) {
    final count = zona.incidentes.length;
    final avgUrgency = zona.incidentes.map((i) => i.urgency).reduce((a, b) => a + b) / count;

    if (count >= 3 || avgUrgency >= 4) return Colors.red;
    if (count == 2 || avgUrgency >= 3) return Colors.orange;
    return Colors.green;
  }

  double _radioZona(_Zone zona) {
    final count = zona.incidentes.length;
    if (count >= 3) return 600;
    if (count == 2) return 450;
    return 300;
  }

  @override
  Widget build(BuildContext context) {
    final zonas = _calcularZonas();

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Mapa de Calor', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Toggle entre mapa de calor y marcadores
          IconButton(
            icon: Icon(
              _showHeatmap ? Icons.location_on : Icons.blur_on,
              color: Colors.white,
            ),
            tooltip: _showHeatmap ? 'Ver marcadores' : 'Ver mapa de calor',
            onPressed: () => setState(() => _showHeatmap = !_showHeatmap),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadIncidents();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(-12.0464, -77.0428),
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.citysafe.app',
              ),

              // MAPA DE CALOR — círculos por zona
              if (_showHeatmap)
                CircleLayer(
                  circles: zonas.map((zona) {
                    final color = _colorZona(zona);
                    return CircleMarker(
                      point: LatLng(zona.lat, zona.lng),
                      radius: _radioZona(zona),
                      color: color.withOpacity(0.35),
                      borderColor: color.withOpacity(0.8),
                      borderStrokeWidth: 2,
                      useRadiusInMeter: true,
                    );
                  }).toList(),
                ),

              // MARCADORES individuales
              if (!_showHeatmap)
                MarkerLayer(
                  markers: _incidents.map((inc) {
                    return Marker(
                      point: LatLng(inc.latitude, inc.longitude),
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              backgroundColor: const Color(0xFF16213E),
                              title: Text(inc.type.toUpperCase(), style: const TextStyle(color: Colors.white)),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (inc.description != null)
                                    Text(inc.description!, style: const TextStyle(color: Colors.white70)),
                                  const SizedBox(height: 8),
                                  Text('Urgencia: ${inc.urgency}', style: TextStyle(color: _urgencyColor(inc.urgency))),
                                  Text('📍 ${inc.latitude.toStringAsFixed(4)}, ${inc.longitude.toStringAsFixed(4)}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                  Text('🕐 ${inc.createdAt.toLocal().toString().substring(0, 16)}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cerrar', style: TextStyle(color: Color(0xFF4FC3F7))),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Icon(Icons.location_on, color: _urgencyColor(inc.urgency), size: 36),
                      ),
                    );
                  }).toList(),
                ),

              // SIEMPRE muestra puntos pequeños encima de las zonas
              if (_showHeatmap)
                MarkerLayer(
                  markers: _incidents.map((inc) {
                    return Marker(
                      point: LatLng(inc.latitude, inc.longitude),
                      width: 16,
                      height: 16,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _urgencyColor(inc.urgency),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),

          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Color(0xFF4FC3F7))),

          // Leyenda
          Positioned(
            bottom: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF16213E).withOpacity(0.92),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _showHeatmap ? 'Zonas de riesgo' : 'Marcadores',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  if (_showHeatmap) ...[
                    _leyendaItem(Colors.red, 'Alta concentración / Urgencia 4-5'),
                    _leyendaItem(Colors.orange, 'Concentración media / Urgencia 3'),
                    _leyendaItem(Colors.green, 'Baja concentración / Urgencia 1-2'),
                  ] else ...[
                    _leyendaItem(Colors.green, 'Urgencia 1-2'),
                    _leyendaItem(Colors.orange, 'Urgencia 3'),
                    _leyendaItem(Colors.red, 'Urgencia 4-5'),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '${_incidents.length} incidentes • ${zonas.length} zonas',
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _urgencyColor(int urgency) {
    if (urgency <= 2) return Colors.green;
    if (urgency == 3) return Colors.orange;
    return Colors.red;
  }

  Widget _leyendaItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color.withOpacity(0.7), shape: BoxShape.circle, border: Border.all(color: color))),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}

class _Zone {
  final double lat;
  final double lng;
  final List<Incident> incidentes;

  _Zone(this.lat, this.lng, this.incidentes);
}