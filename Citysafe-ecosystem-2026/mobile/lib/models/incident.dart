class Incident {
  final int id;
  final String type;
  final String? description;
  final double latitude;
  final double longitude;
  final int urgency;
  final int userId;
  final DateTime createdAt;

  Incident({
    required this.id,
    required this.type,
    this.description,
    required this.latitude,
    required this.longitude,
    required this.urgency,
    required this.userId,
    required this.createdAt,
  });

  factory Incident.fromJson(Map<String, dynamic> json) {
    return Incident(
      id: json['id'],
      type: json['type'],
      description: json['description'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      urgency: json['urgency'],
      userId: json['user_id'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}