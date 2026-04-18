/// Firestack user model.
class FirestackUser {
  final int id;
  final String name;
  final String email;
  final String? avatar;
  final String? phone;
  final String status;
  final String? emailVerifiedAt;
  final String? lastLoginAt;
  final String createdAt;
  final String updatedAt;

  const FirestackUser({
    required this.id,
    required this.name,
    required this.email,
    this.avatar,
    this.phone,
    required this.status,
    this.emailVerifiedAt,
    this.lastLoginAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FirestackUser.fromJson(Map<String, dynamic> json) {
    return FirestackUser(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      avatar: json['avatar'] as String?,
      phone: json['phone'] as String?,
      status: json['status'] as String,
      emailVerifiedAt: json['email_verified_at'] as String?,
      lastLoginAt: json['last_login_at'] as String?,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'avatar': avatar,
        'phone': phone,
        'status': status,
        'email_verified_at': emailVerifiedAt,
        'last_login_at': lastLoginAt,
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
  bool get isVerified => emailVerifiedAt != null;

  /// Whether the user has an avatar set.
  bool get hasAvatar => avatar != null && avatar!.isNotEmpty;

  /// Whether the user has a phone number set.
  bool get hasPhone => phone != null && phone!.isNotEmpty;

  /// Create a copy with updated fields.
  FirestackUser copyWith({
    int? id,
    String? name,
    String? email,
    String? avatar,
    String? phone,
    String? status,
    String? emailVerifiedAt,
    String? lastLoginAt,
    String? createdAt,
    String? updatedAt,
  }) {
    return FirestackUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      phone: phone ?? this.phone,
      status: status ?? this.status,
      emailVerifiedAt: emailVerifiedAt ?? this.emailVerifiedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
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
