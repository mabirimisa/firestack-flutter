/// Firestack user model.
class FirestackUser {
  final int id;
  final int projectId;
  final int appId;
  final String name;
  final String email;
  final String? avatar;
  final String? phone;
  final String status;
  final String? emailVerifiedAt;
  final String? lastLoginAt;
  final Map<String, dynamic>? customClaims;
  final Map<String, dynamic>? metadata;
  final String createdAt;
  final String updatedAt;

  const FirestackUser({
    required this.id,
    required this.projectId,
    required this.appId,
    required this.name,
    required this.email,
    this.avatar,
    this.phone,
    required this.status,
    this.emailVerifiedAt,
    this.lastLoginAt,
    this.customClaims,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FirestackUser.fromJson(Map<String, dynamic> json) {
    return FirestackUser(
      id: json['id'] as int,
      projectId: json['project_id'] as int,
      appId: json['app_id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      avatar: json['avatar'] as String?,
      phone: json['phone'] as String?,
      status: json['status'] as String,
      emailVerifiedAt: json['email_verified_at'] as String?,
      lastLoginAt: json['last_login_at'] as String?,
      customClaims: json['custom_claims'] as Map<String, dynamic>?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'project_id': projectId,
        'app_id': appId,
        'name': name,
        'email': email,
        'avatar': avatar,
        'phone': phone,
        'status': status,
        'email_verified_at': emailVerifiedAt,
        'last_login_at': lastLoginAt,
        'custom_claims': customClaims,
        'metadata': metadata,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  /// Parse [createdAt] as a [DateTime].
  DateTime get createdAtDate => DateTime.parse(createdAt);

  /// Parse [updatedAt] as a [DateTime].
  DateTime get updatedAtDate => DateTime.parse(updatedAt);

  /// Parse [emailVerifiedAt] as a [DateTime], or `null`.
  DateTime? get emailVerifiedAtDate =>
      emailVerifiedAt != null ? DateTime.parse(emailVerifiedAt!) : null;

  /// Parse [lastLoginAt] as a [DateTime], or `null`.
  DateTime? get lastLoginAtDate =>
      lastLoginAt != null ? DateTime.parse(lastLoginAt!) : null;

  bool get isActive => status == 'active';
  bool get isPending => status == 'pending';
  bool get isDisabled => status == 'disabled';
  bool get isVerified => emailVerifiedAt != null;

  /// Whether the user has an avatar set.
  bool get hasAvatar => avatar != null && avatar!.isNotEmpty;

  /// Whether the user has a phone number set.
  bool get hasPhone => phone != null && phone!.isNotEmpty;

  /// Check if user has a specific custom claim.
  bool hasClaim(String claim) {
    return customClaims?.containsKey(claim) ?? false;
  }

  /// Get a custom claim value.
  T? getClaim<T>(String claim) {
    return customClaims?[claim] as T?;
  }

  /// Get a metadata value.
  T? getMetadata<T>(String key) {
    return metadata?[key] as T?;
  }

  /// Create a copy with updated fields.
  FirestackUser copyWith({
    int? id,
    int? projectId,
    int? appId,
    String? name,
    String? email,
    String? avatar,
    String? phone,
    String? status,
    String? emailVerifiedAt,
    String? lastLoginAt,
    Map<String, dynamic>? customClaims,
    Map<String, dynamic>? metadata,
    String? createdAt,
    String? updatedAt,
  }) {
    return FirestackUser(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      appId: appId ?? this.appId,
      name: name ?? this.name,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      phone: phone ?? this.phone,
      status: status ?? this.status,
      emailVerifiedAt: emailVerifiedAt ?? this.emailVerifiedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      customClaims: customClaims ?? this.customClaims,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FirestackUser &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'FirestackUser(id: $id, name: $name, email: $email)';
}
