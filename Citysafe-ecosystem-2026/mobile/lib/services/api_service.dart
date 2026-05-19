import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/incident.dart';
import 'auth_service.dart';

class ApiService {
  final String baseUrl = "http://localhost:8000";

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
      throw Exception('No se pudo conectar con CitySafe. ¿Está el servidor activo?');
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
    } catch (e) {
      return false;
    }
  }
}