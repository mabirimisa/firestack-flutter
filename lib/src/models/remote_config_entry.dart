/// Firestack remote config entry.
class RemoteConfigEntry {
  final String key;
  final dynamic value;
  final String type;
  final bool isFeatureFlag;
  final String environment;
  final String? description;

  const RemoteConfigEntry({
    required this.key,
    required this.value,
    required this.type,
    required this.isFeatureFlag,
    required this.environment,
    this.description,
  });

  factory RemoteConfigEntry.fromJson(Map<String, dynamic> json) {
    return RemoteConfigEntry(
      key: json['key'] as String,
      value: json['value'],
      type: json['type'] as String? ?? 'string',
      isFeatureFlag: json['is_feature_flag'] as bool? ?? false,
      environment: json['environment'] as String? ?? 'production',
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'value': value,
        'type': type,
        'is_feature_flag': isFeatureFlag,
        'environment': environment,
        'description': description,
      };

  /// Get value as String.
  String get asString => value?.toString() ?? '';

  /// Get value as int.
  int get asInt =>
      value is int ? value as int : int.tryParse(value.toString()) ?? 0;

  /// Get value as double.
  double get asDouble => value is double
      ? value as double
      : double.tryParse(value.toString()) ?? 0.0;

  /// Get value as bool.
  bool get asBool {
    if (value is bool) return value as bool;
    final s = value.toString().toLowerCase();
    return s == 'true' || s == '1';
  }

  /// Get value as Map (for JSON type).
  Map<String, dynamic>? get asMap =>
      value is Map ? Map<String, dynamic>.from(value as Map) : null;

  @override
  String toString() => 'RemoteConfigEntry(key: $key, value: $value)';
}
