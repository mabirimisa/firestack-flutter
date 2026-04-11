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

  bool get isActive => status == 'active';
  bool get isVerified => emailVerifiedAt != null;

  @override
  String toString() => 'FirestackUser(id: $id, name: $name, email: $email)';
}
