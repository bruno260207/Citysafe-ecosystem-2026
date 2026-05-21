class Incident {
  final int id;
  final String type;
  final String? description;
  final double latitude;
  final double longitude;
  final int urgency;
  final String status;
  final int userId;
  final DateTime createdAt;
  final String? reporterEmail;

  Incident({
    required this.id,
    required this.type,
    this.description,
    required this.latitude,
    required this.longitude,
    required this.urgency,
    this.status = 'pendiente',
    required this.userId,
    required this.createdAt,
    this.reporterEmail,
  });

  factory Incident.fromJson(Map<String, dynamic> json) {
    return Incident(
      id: json['id'],
      type: json['type'],
      description: json['description'],
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      urgency: json['urgency'],
      status: json['status'] ?? 'pendiente',
      userId: json['user_id'],
      createdAt: DateTime.parse(json['created_at']),
      reporterEmail: json['reporter_email'],
    );
  }

  Incident copyWith({String? status}) {
    return Incident(
      id: id,
      type: type,
      description: description,
      latitude: latitude,
      longitude: longitude,
      urgency: urgency,
      status: status ?? this.status,
      userId: userId,
      createdAt: createdAt,
      reporterEmail: reporterEmail,
    );
  }
}