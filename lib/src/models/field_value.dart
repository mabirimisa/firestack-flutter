/// Sentinel values for atomic field-level operations on documents.
///
/// Like Firebase's `FieldValue`, these allow atomic updates without
/// reading the document first.
///
/// ```dart
/// await ref.update({
///   'score': FieldValue.increment(10),
///   'tags': FieldValue.arrayUnion(['new-tag']),
///   'old_field': FieldValue.delete(),
///   'updated_at': FieldValue.serverTimestamp(),
/// });
/// ```
class FieldValue {
  final String _type;
  final dynamic _value;

  const FieldValue._(this._type, [this._value]);

  /// Increment a numeric field by [value]. Use negative to decrement.
  factory FieldValue.increment(num value) => FieldValue._('increment', value);

  /// Decrement a numeric field by [value].
  factory FieldValue.decrement(num value) => FieldValue._('increment', -value);

  /// Add elements to an array field (only if not already present).
  factory FieldValue.arrayUnion(List<dynamic> elements) =>
      FieldValue._('array_union', elements);

  /// Remove elements from an array field.
  factory FieldValue.arrayRemove(List<dynamic> elements) =>
      FieldValue._('array_remove', elements);

  /// Set the field to the server's current timestamp.
  factory FieldValue.serverTimestamp() =>
      const FieldValue._('server_timestamp');

  /// Delete this field from the document.
  factory FieldValue.delete() => const FieldValue._('delete');

  /// Convert to JSON representation for the API.
  Map<String, dynamic> toJson() => {
        '_fieldValue': _type,
        if (_value != null) 'value': _value,
      };

  @override
  String toString() => 'FieldValue($_type${_value != null ? ', $_value' : ''})';
}

/// Encodes a data map, converting any [FieldValue] instances to their
/// JSON representations for the API.
Map<String, dynamic> encodeFieldValues(Map<String, dynamic> data) {
  return data.map((key, value) {
    if (value is FieldValue) {
      return MapEntry(key, value.toJson());
    } else if (value is Map<String, dynamic>) {
      return MapEntry(key, encodeFieldValues(value));
    }
    return MapEntry(key, value);
  });
}
