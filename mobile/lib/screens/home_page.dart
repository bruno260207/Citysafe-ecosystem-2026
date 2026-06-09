import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/incident.dart';
import 'add_incident_screen.dart';
import 'map_screen.dart';
import 'role_selection_screen.dart'; 

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<Incident>> futureIncidents;

  @override
  void initState() {
    super.initState();
    futureIncidents = ApiService().fetchIncidents();
  }

  void _refresh() {
    setState(() {
      futureIncidents = ApiService().fetchIncidents();
    });
  }

  Color _urgencyColor(int urgency) {
    if (urgency <= 2) return Colors.green;
    if (urgency == 3) return Colors.orange;
    return Colors.red;
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'robo': return Icons.money_off;
      case 'incendio': return Icons.local_fire_department;
      case 'salud': return Icons.medical_services;
      case 'sospechoso': return Icons.visibility;
      case 'vandalismo': return Icons.broken_image;
      case 'accidente': return Icons.car_crash;
      default: return Icons.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Row(
          children: [
            Icon(Icons.shield, color: Color(0xFF4FC3F7)),
            SizedBox(width: 8),
            Text('CitySafe', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.map, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MapScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white54),
            onPressed: () async {
              await AuthService().logout();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                // ↓ CAMBIO: ahora va a RoleSelectionScreen, no LoginScreen
                MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Incident>>(
        future: futureIncidents,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF4FC3F7)));
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off, color: Colors.red, size: 64),
                  const SizedBox(height: 16),
                  const Text('No se pudo conectar al servidor', style: TextStyle(color: Colors.white)),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _refresh, child: const Text('Reintentar')),
                ],
              ),
            );
          }
          final incidents = snapshot.data!;
          if (incidents.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 64),
                  SizedBox(height: 16),
                  Text('No hay incidentes registrados', style: TextStyle(color: Colors.white)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: incidents.length,
              itemBuilder: (context, index) {
                final inc = incidents[index];
                return Card(
                  color: const Color(0xFF16213E),
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _urgencyColor(inc.urgency).withOpacity(0.2),
                      child: Icon(_typeIcon(inc.type), color: _urgencyColor(inc.urgency)),
                    ),
                    title: Text(
                      inc.type.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (inc.description != null)
                          Text(inc.description!, style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 4),
                        Text(
                          '📍 ${inc.latitude.toStringAsFixed(4)}, ${inc.longitude.toStringAsFixed(4)}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        Text(
                          '🕐 ${inc.createdAt.toLocal().toString().substring(0, 16)}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _urgencyColor(inc.urgency).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'U${inc.urgency}',
                        style: TextStyle(color: _urgencyColor(inc.urgency), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddIncidentScreen()),
          );
          if (result == true) _refresh();
        },
        backgroundColor: const Color(0xFF4FC3F7),
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_alert),
        label: const Text('Reportar', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}