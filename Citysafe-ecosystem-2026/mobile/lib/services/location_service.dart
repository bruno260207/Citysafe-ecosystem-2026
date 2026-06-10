import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/incident.dart';

const double _kDangerRadiusMeters = 500.0;
const int    _kMinUrgency         = 3;

class LocationService {
  static const _keyLat = 'user_lat';
  static const _keyLng = 'user_lng';

  // ── Permisos y obtención de ubicación ────────────────────────────────────

  Future<Position> requestAndGetPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationException('El GPS está desactivado. Actívalo para continuar.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationException('Permiso de ubicación denegado.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw LocationException(
          'Permiso de ubicación bloqueado. Habilítalo en los ajustes del dispositivo.');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // ── Persistencia ─────────────────────────────────────────────────────────

  Future<void> savePosition(Position position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyLat, position.latitude);
    await prefs.setDouble(_keyLng, position.longitude);
  }

  Future<({double lat, double lng})?> getSavedPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_keyLat);
    final lng = prefs.getDouble(_keyLng);
    if (lat == null || lng == null) return null;
    return (lat: lat, lng: lng);
  }

  Future<void> clearPosition() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLat);
    await prefs.remove(_keyLng);
  }

  // ── Detección de zonas peligrosas ─────────────────────────────────────────

  /// Devuelve true si el usuario está dentro del radio de algún incidente
  /// peligroso que NO fue reportado por él mismo.
  bool isInsideDangerZone({
    required double userLat,
    required double userLng,
    required List<Incident> incidents,
    int? currentUserId,           // <-- ID del usuario logueado
  }) {
    return incidents.any((inc) {
      // Ignorar incidentes del propio usuario
      if (currentUserId != null && inc.userId == currentUserId) return false;

      if (inc.urgency < _kMinUrgency) return false;

      final dist = _distanceMeters(userLat, userLng, inc.latitude, inc.longitude);
      return dist <= _kDangerRadiusMeters;
    });
  }

  double _distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRad(double deg) => deg * pi / 180;
}

class LocationException implements Exception {
  final String message;
  LocationException(this.message);
  @override
  String toString() => message;
}