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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al cargar incidentes')),
      );
    }
  }

  Color _urgencyColor(int urgency) {
    if (urgency <= 2) return Colors.green;
    if (urgency == 3) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Mapa de Incidentes', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
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
                            title: Text(
                              inc.type.toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
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
                      child: Icon(
                        Icons.location_on,
                        color: _urgencyColor(inc.urgency),
                        size: 36,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF4FC3F7)),
            ),
          Positioned(
            bottom: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF16213E).withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Leyenda', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  SizedBox(height: 6),
                  Row(children: [Icon(Icons.location_on, color: Colors.green, size: 16), SizedBox(width: 4), Text('Urgencia 1-2', style: TextStyle(color: Colors.white70, fontSize: 11))]),
                  Row(children: [Icon(Icons.location_on, color: Colors.orange, size: 16), SizedBox(width: 4), Text('Urgencia 3', style: TextStyle(color: Colors.white70, fontSize: 11))]),
                  Row(children: [Icon(Icons.location_on, color: Colors.red, size: 16), SizedBox(width: 4), Text('Urgencia 4-5', style: TextStyle(color: Colors.white70, fontSize: 11))]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}