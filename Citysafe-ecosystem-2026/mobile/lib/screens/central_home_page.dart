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

  // ── FILTROS ────────────────────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _selectedTypes = {}; // vacío = todos los tipos
  int _minUrgency = 1;
  String _sortBy = 'recientes'; // recientes | urgencia_desc | urgencia_asc

  static const Map<String, String> _typeLabels = {
    'robo': 'Robo',
    'incendio': 'Incendio',
    'salud': 'Salud',
    'sospechoso': 'Sospechoso',
    'accidente': 'Accidente',
    'otros': 'Otros',
  };

  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _selectedTypes.isNotEmpty ||
      _minUrgency > 1 ||
      _sortBy != 'recientes';

  int get _activeFilterCount {
    var count = 0;
    if (_searchQuery.isNotEmpty) count++;
    if (_selectedTypes.isNotEmpty) count++;
    if (_minUrgency > 1) count++;
    if (_sortBy != 'recientes') count++;
    return count;
  }

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
    _searchController.dispose();
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

  Future<void> _confirmAndChangeStatus(Incident inc, String newStatus, String actionLabel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Confirmar acción', style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Marcar el incidente de ${inc.type.toUpperCase()} '
          '(urgencia ${inc.urgency}/5) como "$actionLabel"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B6B)),
            child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _changeStatus(inc, newStatus);
    }
  }

  // ── FILTRADO Y ORDEN ───────────────────────────────────────────────────────

  List<Incident> _applyFilters(List<Incident> source) {
    var result = source.where((inc) {
      if (_selectedTypes.isNotEmpty && !_selectedTypes.contains(inc.type)) {
        return false;
      }
      if (inc.urgency < _minUrgency) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matches = inc.type.toLowerCase().contains(q) ||
            (inc.description?.toLowerCase().contains(q) ?? false) ||
            (inc.reporterEmail?.toLowerCase().contains(q) ?? false);
        if (!matches) return false;
      }
      return true;
    }).toList();

    switch (_sortBy) {
      case 'urgencia_desc':
        result.sort((a, b) => b.urgency.compareTo(a.urgency));
        break;
      case 'urgencia_asc':
        result.sort((a, b) => a.urgency.compareTo(b.urgency));
        break;
      case 'recientes':
      default:
        result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }
    return result;
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedTypes.clear();
      _minUrgency = 1;
      _sortBy = 'recientes';
    });
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16213E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Widget sortOption(String value, String label, IconData icon) {
              final selected = _sortBy == value;
              return ListTile(
                leading: Icon(icon, color: selected ? const Color(0xFFFF6B6B) : Colors.white54),
                title: Text(
                  label,
                  style: TextStyle(
                    color: selected ? const Color(0xFFFF6B6B) : Colors.white,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: selected ? const Icon(Icons.check, color: Color(0xFFFF6B6B)) : null,
                onTap: () {
                  setSheetState(() => _sortBy = value);
                  setState(() {});
                },
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 16,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Filtros y orden',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              _selectedTypes.clear();
                              _minUrgency = 1;
                              _sortBy = 'recientes';
                            });
                            setState(() {});
                          },
                          child: const Text('Limpiar', style: TextStyle(color: Colors.white54)),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12, height: 24),

                    // Ordenar
                    const Text('Ordenar', style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
                    sortOption('recientes', 'Más recientes', Icons.schedule),
                    sortOption('urgencia_desc', 'Mayor urgencia', Icons.priority_high),
                    sortOption('urgencia_asc', 'Menor urgencia', Icons.low_priority),

                    const Divider(color: Colors.white12, height: 24),

                    // Tipo de incidente
                    const Text('Tipo de incidente', style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _typeLabels.entries.map((entry) {
                        final selected = _selectedTypes.contains(entry.key);
                        return FilterChip(
                          label: Text(entry.value),
                          selected: selected,
                          showCheckmark: false,
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : Colors.white70,
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                          backgroundColor: const Color(0xFF1A1A2E),
                          selectedColor: const Color(0xFFFF6B6B),
                          side: BorderSide(color: selected ? Colors.transparent : Colors.white24),
                          onSelected: (value) {
                            setSheetState(() {
                              if (value) {
                                _selectedTypes.add(entry.key);
                              } else {
                                _selectedTypes.remove(entry.key);
                              }
                            });
                            setState(() {});
                          },
                        );
                      }).toList(),
                    ),

                    const Divider(color: Colors.white12, height: 24),

                    // Urgencia mínima
                    Row(
                      children: [
                        const Text('Urgencia mínima', style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Text('$_minUrgency/5', style: const TextStyle(color: Color(0xFFFF6B6B), fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Slider(
                      value: _minUrgency.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      activeColor: const Color(0xFFFF6B6B),
                      inactiveColor: Colors.white12,
                      label: '$_minUrgency',
                      onChanged: (value) {
                        setSheetState(() => _minUrgency = value.round());
                        setState(() {});
                      },
                    ),

                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B6B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Aplicar', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: const Color(0xFF16213E),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Buscar por tipo, descripción o correo...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                  prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF1A1A2E),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Material(
                color: _hasActiveFilters ? const Color(0xFFFF6B6B) : const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _showFilterSheet,
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _hasActiveFilters ? Colors.transparent : const Color(0xFFFF6B6B),
                        width: 1.4,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.tune,
                          color: _hasActiveFilters ? Colors.white : const Color(0xFFFF6B6B),
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Filtrar',
                          style: TextStyle(
                            color: _hasActiveFilters ? Colors.white : const Color(0xFFFF6B6B),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_activeFilterCount > 0)
                Positioned(
                  top: -6,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Text(
                      '$_activeFilterCount',
                      style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          if (_hasActiveFilters) ...[
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.filter_alt_off, color: Colors.white38, size: 20),
              tooltip: 'Limpiar filtros',
              onPressed: _clearFilters,
            ),
          ],
        ],
      ),
    );
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
                _confirmAndChangeStatus(inc, 'atendido', 'Atendido');
              }),
            if (inc.status == 'atendido')
              _statusButton('Marcar como Resuelto', Colors.green, () {
                Navigator.pop(context);
                _confirmAndChangeStatus(inc, 'resuelto', 'Resuelto');
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

    final pendientes = _applyFilters(_incidents.where((i) => i.status == 'pendiente').toList());
    final atendidos  = _applyFilters(_incidents.where((i) => i.status == 'atendido').toList());
    final resueltos  = _applyFilters(_incidents.where((i) => i.status == 'resuelto').toList());

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          _buildFilterBar(),
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
      if (_hasActiveFilters) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off, color: Colors.white24, size: 56),
              const SizedBox(height: 16),
              const Text('Ningún incidente coincide con los filtros', style: TextStyle(color: Colors.white54)),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.filter_alt_off, color: Color(0xFFFF6B6B), size: 18),
                label: const Text('Limpiar filtros', style: TextStyle(color: Color(0xFFFF6B6B))),
              ),
            ],
          ),
        );
      }
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
            onStatusChange: (newStatus) => _confirmAndChangeStatus(
              inc,
              newStatus,
              newStatus == 'atendido' ? 'Atendido' : 'Resuelto',
            ),
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

    final allValid = _incidents.where((i) => i.latitude != 0 && i.longitude != 0).toList();
    final validIncidents = _applyFilters(allValid);

    final center = validIncidents.isNotEmpty
        ? LatLng(
            validIncidents.map((i) => i.latitude).reduce((a, b) => a + b) / validIncidents.length,
            validIncidents.map((i) => i.longitude).reduce((a, b) => a + b) / validIncidents.length,
          )
        : (allValid.isNotEmpty
            ? LatLng(
                allValid.map((i) => i.latitude).reduce((a, b) => a + b) / allValid.length,
                allValid.map((i) => i.longitude).reduce((a, b) => a + b) / allValid.length,
              )
            : const LatLng(-12.0464, -77.0428));

    return Column(
      children: [
        _buildFilterBar(),
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
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
              ),
              // Contador de marcadores visibles
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16213E).withOpacity(0.92),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _hasActiveFilters ? const Color(0xFFFF6B6B) : Colors.white24,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.place, size: 14, color: _hasActiveFilters ? const Color(0xFFFF6B6B) : Colors.white54),
                      const SizedBox(width: 5),
                      Text(
                        _hasActiveFilters
                            ? '${validIncidents.length} de ${allValid.length}'
                            : '${validIncidents.length} incidentes',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              if (validIncidents.isEmpty && _hasActiveFilters)
                Positioned(
                  left: 20,
                  right: 20,
                  top: 60,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16213E).withOpacity(0.95),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search_off, color: Colors.white38, size: 20),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Ningún incidente en el mapa coincide con los filtros',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ),
                        TextButton(
                          onPressed: _clearFilters,
                          child: const Text('Limpiar', style: TextStyle(color: Color(0xFFFF6B6B), fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
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