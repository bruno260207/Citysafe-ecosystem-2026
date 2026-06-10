import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/incident.dart';
import 'auth_service.dart';

class ApiService {
  static const String baseUrl = AuthService.baseUrl;

  Future<List<Incident>> fetchIncidents() async {
    try {
      final token = await AuthService().getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/incidents'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body);
        return jsonResponse.map((data) => Incident.fromJson(data)).toList();
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('No se pudo conectar con CitySafe.');
    }
  }

  Future<bool> createIncident({
    required String type,
    required String description,
    required double latitude,
    required double longitude,
    required int urgency,
  }) async {
    try {
      final token = await AuthService().getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/incidents'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'type': type,
          'description': description,
          'latitude': latitude,
          'longitude': longitude,
          'urgency': urgency,
        }),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  Future<List<Incident>> fetchCentralIncidents() async {
    try {
      final token = await AuthService().getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/central/incidents'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body);
        return jsonResponse.map((data) => Incident.fromJson(data)).toList();
      } else {
        throw Exception('Error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('No se pudo conectar con el servidor.');
    }
  }

  Future<bool> updateIncidentStatus(int incidentId, String newStatus) async {
    try {
      final token = await AuthService().getToken();
      final response = await http.patch(
        Uri.parse('$baseUrl/central/incidents/$incidentId/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'status': newStatus}),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<StreamSubscription<String>?> listenToIncidentStream({
    required void Function(Incident) onNewIncident,
    void Function(Object)? onError,
  }) async {
    final token = await AuthService().getToken();
    if (token == null) return null;

    final request = http.Request('GET', Uri.parse('$baseUrl/central/stream'));
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'text/event-stream';
    request.headers['Cache-Control'] = 'no-cache';

    try {
      final client = http.Client();
      final streamedResponse = await client.send(request);

      final subscription = streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          if (line.startsWith('data: ')) {
            final raw = line.substring(6).trim();
            if (raw.isEmpty || raw == '{"ping": true}') return;
            try {
              final data = jsonDecode(raw);
              onNewIncident(Incident.fromJson(data));
            } catch (_) {}
          }
        },
        onError: onError,
      );

      return subscription;
    } catch (e) {
      onError?.call(e);
      return null;
    }
  }
}