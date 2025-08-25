class User {
  final int? id;
  final String email;
  final String? profileImagePath;
  final DateTime? createdAt;

  User({
    this.id,
    required this.email,
    this.profileImagePath,
    this.createdAt,
  });

  // Conversion vers JSON pour l'API
  Map<String, dynamic> toJson() {
    return {
      'account_id': id,
      'email': email,
      'profile_image': profileImagePath,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  // Création depuis JSON (réponse API)
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['account_id'],
      email: json['email'],
      profileImagePath: json['profile_image'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  // Conversion vers Map pour SQLite local
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'profile_image_path': profileImagePath,
      'created_at': createdAt?.millisecondsSinceEpoch,
    };
  }

  // Création depuis Map (SQLite local)
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      email: map['email'],
      profileImagePath: map['profile_image_path'],
      createdAt: map['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at'])
          : null,
    );
  }

  // Méthode copyWith pour modifications
  User copyWith({
    int? id,
    String? email,
    String? profileImagePath,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      profileImagePath: profileImagePath ?? this.profileImagePath,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'User{id: $id, email: $email, profileImagePath: $profileImagePath}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User &&
        other.id == id &&
        other.email == email &&
        other.profileImagePath == profileImagePath;
  }

  @override
  int get hashCode {
    return id.hashCode ^ email.hashCode ^ profileImagePath.hashCode;
  }
}
