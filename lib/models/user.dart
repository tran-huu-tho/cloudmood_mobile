class UserModel {
  final int id;
  final String fullName;
  final String email;
  final String password;
  final String? avatar;
  final bool role; // true for Admin, false for Regular User
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.password,
    this.avatar,
    required this.role,
    required this.createdAt,
  });

  // Convert to Map for serialization (e.g. for mock database storage)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'password': password,
      'avatar': avatar,
      'role': role,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Parse from Map (deserialization)
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as int,
      fullName: map['fullName'] as String,
      email: map['email'] as String,
      password: map['password'] as String? ?? '',
      avatar: map['avatar'] as String?,
      role: map['role'] as bool,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  // Helper method to copy with modified fields
  UserModel copyWith({
    int? id,
    String? fullName,
    String? email,
    String? password,
    String? avatar,
    bool? role,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      password: password ?? this.password,
      avatar: avatar ?? this.avatar,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
