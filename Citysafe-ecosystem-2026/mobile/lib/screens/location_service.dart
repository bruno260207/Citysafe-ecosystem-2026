import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationService {
  static const double _dangerRadiusMeters = 500.0;
  static const int _minUrgency = 3;

  static const String _latKey = 'user_lat';
  static const String _lngKey = 'user_lng';

  /// Solicita permiso y guarda la posición actual en SharedPreferences.
  Future<bool> requestAndSavePosition() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      return false;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_latKey, position.latitude);
      await prefs.setDouble(_lngKey, position.longitude);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Lee la posición guardada. Devuelve null si no hay ninguna.
  Future<Map<String, double>?> getSavedPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_latKey);
    final lng = prefs.getDouble(_lngKey);
    if (lat == null || lng == null) return null;
    return {'lat': lat, 'lng': lng};
  }

  /// Borra la posición guardada (al hacer logout).
  Future<void> clearPosition() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_latKey);
    await prefs.remove(_lngKey);
  }

  /// Verifica si el usuario está dentro de una zona peligrosa.
  /// Excluye los incidentes del propio usuario si se pasa [currentUserId].
  Future<bool> isInsideDangerZone(
    List<dynamic> incidents, {
    int? currentUserId,
  }) async {
    final position = await getSavedPosition();
    if (position == null) return false;

    final userLat = position['lat']!;
    final userLng = position['lng']!;

    for (final incident in incidents) {
      // Excluir incidentes del propio usuario
      if (currentUserId != null && incident['user_id'] == currentUserId) {
        continue;
      }

      final urgency = incident['urgency'] as int? ?? 0;
      if (urgency < _minUrgency) continue;

      final incLat = (incident['latitude'] as num?)?.toDouble();
      final incLng = (incident['longitude'] as num?)?.toDouble();
      if (incLat == null || incLng == null) continue;

      final distance = _haversine(userLat, userLng, incLat, incLng);
      if (distance <= _dangerRadiusMeters) return true;
    }
    return false;
  }

  /// Fórmula Haversine: distancia en metros entre dos coordenadas GPS.
  double _haversine(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371000; // metros
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) *
        sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRad(double deg) => deg * pi / 180;
}
