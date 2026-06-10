import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';

class AddIncidentScreen extends StatefulWidget {
  const AddIncidentScreen({super.key});

  @override
  State<AddIncidentScreen> createState() => _AddIncidentScreenState();
}

class _AddIncidentScreenState extends State<AddIncidentScreen> {
  final _descController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  String _selectedType = 'robo';
  int _urgency = 1;
  bool _isLoading = false;
  bool _isLoadingLocation = false;

  final List<Map<String, dynamic>> _types = [
    {'value': 'robo', 'label': 'Robo', 'icon': Icons.money_off},
    {'value': 'incendio', 'label': 'Incendio', 'icon': Icons.local_fire_department},
    {'value': 'salud', 'label': 'Salud', 'icon': Icons.medical_services},
    {'value': 'sospechoso', 'label': 'Sospechoso', 'icon': Icons.visibility},
    {'value': 'accidente', 'label': 'Accidente', 'icon': Icons.car_crash},
    {'value': 'otros', 'label': 'Otros', 'icon': Icons.warning_amber},
  ];

  @override
  void initState() {
    super.initState();
    _obtenerUbicacion();
  }

  Future<void> _obtenerUbicacion() async {
    setState(() => _isLoadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _mostrarError('El GPS está desactivado. Actívalo o ingresa las coordenadas manualmente.');
        setState(() => _isLoadingLocation = false);
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _mostrarError('Permiso de ubicación denegado. Ingresa las coordenadas manualmente.');
          setState(() => _isLoadingLocation = false);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _mostrarError('Permiso de ubicación bloqueado. Habilítalo en los ajustes del dispositivo.');
        setState(() => _isLoadingLocation = false);
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _latController.text = position.latitude.toStringAsFixed(6);
        _lngController.text = position.longitude.toStringAsFixed(6);
        _isLoadingLocation = false;
      });
    } catch (e) {
      _mostrarError('No se pudo obtener la ubicación. Ingresa las coordenadas manualmente.');
      setState(() => _isLoadingLocation = false);
    }
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red.shade700),
    );
  }

  String _getMensajeEmergencia(String type) {
    switch (type) {
      case 'incendio':
        return 'Mantén la calma, los bomberos ya se dirigen hacia tu zona.';
      case 'salud':
        return 'Mantén la calma, la ambulancia ya se dirige hacia tu zona.';
      case 'accidente':
        return 'Mantén la calma, la policía y una ambulancia ya se dirigen hacia tu zona.';
      default:
        return 'Mantén la calma, la policía ya se dirige hacia tu zona.';
    }
  }

  void _guardar() async {
    if (_latController.text.isEmpty || _lngController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa latitud y longitud')),
      );
      return;
    }

    setState(() => _isLoading = true);

    bool success = await ApiService().createIncident(
      type: _selectedType,
      description: _descController.text,
      latitude: double.parse(_latController.text),
      longitude: double.parse(_lngController.text),
      urgency: _urgency,
    );

    setState(() => _isLoading = false);

    if (success) {
      await _mostrarNotificacionEmergencia(_selectedType);
      if (mounted) Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al reportar, verificar datos.')),
      );
    }
  }

  Future<void> _mostrarNotificacionEmergencia(String type) async {
    final mensaje = _getMensajeEmergencia(type);

    final iconData = switch (type) {
      'incendio'   => Icons.local_fire_department,
      'salud'      => Icons.medical_services,
      'accidente'  => Icons.car_crash,
      'robo'       => Icons.shield,
      'sospechoso' => Icons.visibility,
      _            => Icons.shield,
    };

    final color = switch (type) {
      'incendio'  => const Color(0xFFFF6B35),  // naranja fuego
      'salud'     => const Color(0xFF4CAF50),  // verde
      'accidente' => const Color(0xFFFFB300),  // ámbar
      'robo'      => const Color(0xFFE53935),  // rojo
      'sospechoso'=> const Color(0xFFAB47BC),  // morado
      _           => const Color(0xFF26C6DA),  // cyan (otros)
    };

    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (_) => _EmergencyDialog(
        mensaje: mensaje,
        icon: iconData,
        color: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Reportar Incidente', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tipo de incidente', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _types.map((t) {
                final selected = _selectedType == t['value'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedType = t['value']),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF4FC3F7) : Colors.white10,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(t['icon'], size: 16, color: selected ? Colors.black : Colors.white70),
                        const SizedBox(width: 6),
                        Text(t['label'], style: TextStyle(color: selected ? Colors.black : Colors.white70, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Text('Descripción (opcional)', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Describe el incidente...',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Ubicación', style: TextStyle(color: Colors.white70, fontSize: 13)),
                TextButton.icon(
                  onPressed: _isLoadingLocation ? null : _obtenerUbicacion,
                  icon: _isLoadingLocation
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4FC3F7)),
                        )
                      : const Icon(Icons.my_location, size: 16, color: Color(0xFF4FC3F7)),
                  label: Text(
                    _isLoadingLocation ? 'Obteniendo...' : 'Usar mi ubicación',
                    style: const TextStyle(color: Color(0xFF4FC3F7), fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Latitud', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _latController,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: InputDecoration(
                          hintText: '-12.0464',
                          hintStyle: const TextStyle(color: Colors.white30),
                          filled: true,
                          fillColor: Colors.white10,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Longitud', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _lngController,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: InputDecoration(
                          hintText: '-77.0428',
                          hintStyle: const TextStyle(color: Colors.white30),
                          filled: true,
                          fillColor: Colors.white10,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Nivel de urgencia', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (i) {
                final level = i + 1;
                Color c = level <= 2 ? Colors.green : level == 3 ? Colors.orange : Colors.red;
                return GestureDetector(
                  onTap: () => setState(() => _urgency = level),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _urgency == level ? c : Colors.white10,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _urgency == level ? c : Colors.transparent),
                    ),
                    child: Center(
                      child: Text('$level', style: TextStyle(color: _urgency == level ? Colors.white : Colors.white54, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF4FC3F7)))
                  : ElevatedButton.icon(
                      onPressed: _guardar,
                      icon: const Icon(Icons.send),
                      label: const Text('Enviar Reporte', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4FC3F7),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyDialog extends StatefulWidget {
  final String mensaje;
  final IconData icon;
  final Color color;

  const _EmergencyDialog({
    required this.mensaje,
    required this.icon,
    required this.color,
  });

  @override
  State<_EmergencyDialog> createState() => _EmergencyDialogState();
}

class _EmergencyDialogState extends State<_EmergencyDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 28),
            decoration: BoxDecoration(
              color: const Color(0xFF16213E),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: widget.color.withOpacity(0.5), width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.9, end: 1.1),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeInOut,
                  builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
                  onEnd: () => setState(() {}),
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.color.withOpacity(0.15),
                      border: Border.all(color: widget.color, width: 2.5),
                    ),
                    child: Icon(widget.icon, size: 44, color: widget.color),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '¡Reporte enviado!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.mensaje,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: widget.color,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.color,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      'Entendido',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}