import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/incident.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'role_selection_screen.dart';

class CentralHomePage extends StatefulWidget {
  const CentralHomePage({super.key});

  @override
  State<CentralHomePage> createState() => _CentralHomePageState();
}

class _CentralHomePageState extends State<CentralHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Incident> _incidents = [];
  bool _loading = true;
  String? _error;
  StreamSubscription<String>? _sseSubscription;

  // Notificación flotante
  Incident? _toastIncident;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadIncidents();
    _connectSSE();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _sseSubscription?.cancel();
    _toastTimer?.cancel();
    super.dispose();
  }

  // ── CARGA INICIAL ──────────────────────────────────────────────────────────

  Future<void> _loadIncidents() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService().fetchCentralIncidents();
      data.sort((a, b) {
        final statusOrder = {'pendiente': 0, 'atendido': 1, 'resuelto': 2};
        final s = statusOrder[a.status]!.compareTo(statusOrder[b.status]!);
        if (s != 0) return s;
        return b.urgency.compareTo(a.urgency);
      });
      setState(() {
        _incidents = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ── SSE ────────────────────────────────────────────────────────────────────

  Future<void> _connectSSE() async {
    final sub = await ApiService().listenToIncidentStream(
      onNewIncident: (incident) {
        if (!mounted) return;
        setState(() {
          final exists = _incidents.any((i) => i.id == incident.id);
          if (!exists) _incidents.insert(0, incident);
          _toastIncident = incident;
        });
        _startToastTimer();
      },
      onError: (_) {},
    );
    _sseSubscription = sub;
  }

  void _startToastTimer() {
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _toastIncident = null);
    });
  }

  // ── CAMBIAR ESTADO ─────────────────────────────────────────────────────────

  Future<void> _changeStatus(Incident incident, String newStatus) async {
    final ok = await ApiService().updateIncidentStatus(incident.id, newStatus);
    if (!mounted) return;
    if (ok) {
      setState(() {
        final idx = _incidents.indexWhere((i) => i.id == incident.id);
        if (idx != -1) {
          _incidents[idx] = _incidents[idx].copyWith(status: newStatus);
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al actualizar el estado')),
      );
    }
  }

  // ── HELPERS ────────────────────────────────────────────────────────────────

  Color _urgencyColor(int u) {
    if (u <= 2) return Colors.green;
    if (u == 3) return Colors.orange;
    return Colors.red;
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'pendiente': return Colors.orange;
      case 'atendido':  return Colors.blue;
      case 'resuelto':  return Colors.green;
      default:          return Colors.grey;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'robo':      return Icons.money_off;
      case 'incendio':  return Icons.local_fire_department;
      case 'salud':     return Icons.medical_services;
      case 'sospechoso':return Icons.visibility;
      case 'accidente': return Icons.car_crash;
      default:          return Icons.warning;
    }
  }

  // ── MODAL DETALLE ──────────────────────────────────────────────────────────

  void _showDetail(Incident inc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16213E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_typeIcon(inc.type), color: _urgencyColor(inc.urgency), size: 28),
                const SizedBox(width: 12),
                Text(
                  inc.type.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(inc.status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    inc.status.toUpperCase(),
                    style: TextStyle(
                      color: _statusColor(inc.status),
                      fontWeight: FontWeight.bold, fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (inc.description != null && inc.description!.isNotEmpty) ...[
              Text(inc.description!, style: const TextStyle(color: Colors.white70, fontSize: 15)),
              const SizedBox(height: 12),
            ],
            _detailRow(Icons.location_on, '${inc.latitude.toStringAsFixed(5)}, ${inc.longitude.toStringAsFixed(5)}'),
            _detailRow(Icons.access_time, inc.createdAt.toLocal().toString().substring(0, 16)),
            _detailRow(Icons.warning_amber, 'Urgencia: ${inc.urgency}/5'),
            if (inc.reporterEmail != null) _detailRow(Icons.person, inc.reporterEmail!),
            const SizedBox(height: 20),
            if (inc.status == 'pendiente')
              _statusButton('Marcar como Atendido', Colors.blue, () {
                Navigator.pop(context);
                _changeStatus(inc, 'atendido');
              }),
            if (inc.status == 'atendido')
              _statusButton('Marcar como Resuelto', Colors.green, () {
                Navigator.pop(context);
                _changeStatus(inc, 'resuelto');
              }),
            if (inc.status == 'resuelto')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('✓ Incidente resuelto', style: TextStyle(color: Colors.green)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white60, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _statusButton(String label, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Row(
          children: [
            Icon(Icons.radio_button_checked, color: Color(0xFFFF6B6B)),
            SizedBox(width: 8),
            Text(
              'Central CitySafe',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white54),
            onPressed: _loadIncidents,
            tooltip: 'Actualizar',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white54),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              await AuthService().logout();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
                (route) => false,
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFF6B6B),
          labelColor: const Color(0xFFFF6B6B),
          unselectedLabelColor: Colors.white38,
          tabs: [
            Tab(
              icon: const Icon(Icons.list_alt),
              text: 'Incidentes (${_incidents.length})',
            ),
            const Tab(icon: Icon(Icons.map), text: 'Mapa'),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildList(),
              _buildMap(),
            ],
          ),
          if (_toastIncident != null) _buildToast(_toastIncident!),
        ],
      ),
    );
  }

  // ── LISTA CON SUB-TABS ─────────────────────────────────────────────────────

  Widget _buildList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B6B)));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            const Text('Sin conexión al servidor', style: TextStyle(color: Colors.white)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadIncidents, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    final pendientes = _incidents.where((i) => i.status == 'pendiente').toList();
    final atendidos  = _incidents.where((i) => i.status == 'atendido').toList();
    final resueltos  = _incidents.where((i) => i.status == 'resuelto').toList();

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          // Sub-TabBar
          Container(
            color: const Color(0xFF16213E),
            child: TabBar(
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white38,
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: [
                _subTab('Pendiente', pendientes.length, Colors.orange),
                _subTab('Atendido',  atendidos.length,  Colors.blue),
                _subTab('Resuelto',  resueltos.length,  Colors.green),
              ],
            ),
          ),
          // Sub-TabBarView
          Expanded(
            child: TabBarView(
              children: [
                _buildStatusList(pendientes, 'pendiente'),
                _buildStatusList(atendidos,  'atendido'),
                _buildStatusList(resueltos,  'resuelto'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Tab _subTab(String label, int count, Color color) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text('$label ($count)', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildStatusList(List<Incident> incidents, String status) {
    if (incidents.isEmpty) {
      final messages = {
        'pendiente': ('check_circle', Colors.green,   'Sin incidentes pendientes'),
        'atendido':  ('hourglass_empty', Colors.blue, 'Ningún incidente en atención'),
        'resuelto':  ('emoji_events', Colors.amber,   'Aún no hay incidentes resueltos'),
      };
      final info = messages[status]!;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              status == 'pendiente' ? Icons.check_circle
                  : status == 'atendido' ? Icons.hourglass_empty
                  : Icons.emoji_events,
              color: info.$2,
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(info.$3, style: const TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadIncidents,
      color: const Color(0xFFFF6B6B),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: incidents.length,
        itemBuilder: (context, index) {
          final inc = incidents[index];
          return _IncidentCard(
            incident: inc,
            urgencyColor: _urgencyColor(inc.urgency),
            statusColor: _statusColor(inc.status),
            typeIcon: _typeIcon(inc.type),
            onTap: () => _showDetail(inc),
            onStatusChange: (newStatus) => _changeStatus(inc, newStatus),
          );
        },
      ),
    );
  }

  // ── MAPA ───────────────────────────────────────────────────────────────────

  Widget _buildMap() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B6B)));
    }

    final validIncidents = _incidents
        .where((i) => i.latitude != 0 && i.longitude != 0)
        .toList();

    final center = validIncidents.isNotEmpty
        ? LatLng(
            validIncidents.map((i) => i.latitude).reduce((a, b) => a + b) / validIncidents.length,
            validIncidents.map((i) => i.longitude).reduce((a, b) => a + b) / validIncidents.length,
          )
        : const LatLng(-12.0464, -77.0428);

    return FlutterMap(
      options: MapOptions(initialCenter: center, initialZoom: 13),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.mobile',
        ),
        MarkerLayer(
          markers: validIncidents.map((inc) {
            return Marker(
              point: LatLng(inc.latitude, inc.longitude),
              width: 44,
              height: 44,
              child: GestureDetector(
                onTap: () => _showDetail(inc),
                child: Container(
                  decoration: BoxDecoration(
                    color: _urgencyColor(inc.urgency),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: _urgencyColor(inc.urgency).withOpacity(0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Icon(_typeIcon(inc.type), color: Colors.white, size: 22),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── TOAST ──────────────────────────────────────────────────────────────────

  Widget _buildToast(Incident inc) {
    return Positioned(
      top: 12,
      left: 16,
      right: 16,
      child: Material(
        borderRadius: BorderRadius.circular(14),
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F3460),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFF6B6B), width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 10),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.notifications_active, color: Color(0xFFFF6B6B), size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '⚠ Nuevo incidente reportado',
                      style: TextStyle(
                        color: Color(0xFFFF6B6B),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '${inc.type.toUpperCase()} — Urgencia ${inc.urgency}/5',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                onPressed: () => setState(() => _toastIncident = null),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── WIDGET TARJETA ─────────────────────────────────────────────────────────────

class _IncidentCard extends StatelessWidget {
  final Incident incident;
  final Color urgencyColor;
  final Color statusColor;
  final IconData typeIcon;
  final VoidCallback onTap;
  final void Function(String) onStatusChange;

  const _IncidentCard({
    required this.incident,
    required this.urgencyColor,
    required this.statusColor,
    required this.typeIcon,
    required this.onTap,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF16213E),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: urgencyColor.withOpacity(0.3), width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: urgencyColor.withOpacity(0.15),
                    child: Icon(typeIcon, color: urgencyColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          incident.type.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15,
                          ),
                        ),
                        if (incident.reporterEmail != null)
                          Text(
                            incident.reporterEmail!,
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: urgencyColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'U${incident.urgency}',
                      style: TextStyle(
                        color: urgencyColor, fontWeight: FontWeight.bold, fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              if (incident.description != null && incident.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  incident.description!,
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.4)),
                    ),
                    child: Text(
                      incident.status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor, fontWeight: FontWeight.bold, fontSize: 11,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (incident.status == 'pendiente')
                    _quickStatusBtn('Atender', Colors.blue, () => onStatusChange('atendido')),
                  if (incident.status == 'atendido')
                    _quickStatusBtn('Resolver', Colors.green, () => onStatusChange('resuelto')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickStatusBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Text(
          label,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}