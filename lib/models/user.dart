class User {
  final String id;
  final String username;
  final String email;
  final String? profileImage;
  final DateTime lastSeen;
  final bool isOnline;

  User({
  required this.id,
  required this.username,
  required this.email,
  this.profileImage,
  required this.lastSeen,
  this.isOnline = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'] ?? '',
      profileImage: json['profileImage'],
      lastSeen: DateTime.parse(json['lastSeen']),
      isOnline: json['isOnline'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'profileImage': profileImage,
      'lastSeen': lastSeen.toIso8601String(),
      'isOnline': isOnline,
    };
  }

  User copyWith({
    String? id,
    String? username,
    String? email,
    String? profileImage,
    DateTime? lastSeen,
    bool? isOnline,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      profileImage: profileImage ?? this.profileImage,
      lastSeen: lastSeen ?? this.lastSeen,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}
