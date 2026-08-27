/// Represents a Home Assistant state entity fetched from /api/states.
class HaEntity {
  const HaEntity({
    required this.entityId,
    required this.state,
    required this.attributes,
    required this.lastChanged,
    required this.lastUpdated,
    this.area = 'TODAS',
  });

  factory HaEntity.fromJson(Map<String, dynamic> json) {
    return HaEntity(
      entityId: json['entity_id'] as String? ?? '',
      state: json['state'] as String? ?? 'unknown',
      attributes: json['attributes'] as Map<String, dynamic>? ?? {},
      lastChanged: json['last_changed'] as String? ?? '',
      lastUpdated: json['last_updated'] as String? ?? '',
    );
  }

  HaEntity copyWith({
    String? entityId,
    String? state,
    Map<String, dynamic>? attributes,
    String? lastChanged,
    String? lastUpdated,
    String? area,
  }) {
    return HaEntity(
      entityId: entityId ?? this.entityId,
      state: state ?? this.state,
      attributes: attributes ?? this.attributes,
      lastChanged: lastChanged ?? this.lastChanged,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      area: area ?? this.area,
    );
  }

  final String entityId;
  final String state;
  final Map<String, dynamic> attributes;
  final String lastChanged;
  final String lastUpdated;
  final String area;

  /// Returns the friendly name if available, otherwise fallback to entityId.
  String get friendlyName => attributes['friendly_name'] as String? ?? entityId;

  /// Utility to check the domain of the entity (e.g. 'light', 'person').
  String get domain => entityId.split('.').first;
}
