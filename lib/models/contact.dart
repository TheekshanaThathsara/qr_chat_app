class Contact {
  final String id;
  final String userId;
  final String username;
  final String? profileImage;
  final DateTime addedAt;
  final bool isBlocked;

  Contact({
    required this.id,
    required this.userId,
    required this.username,
    this.profileImage,
    required this.addedAt,
    this.isBlocked = false,
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'],
      userId: json['userId'],
      username: json['username'],
      profileImage: json['profileImage'],
      addedAt: DateTime.parse(json['addedAt']),
      isBlocked: json['isBlocked'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'username': username,
      'profileImage': profileImage,
      'addedAt': addedAt.toIso8601String(),
      'isBlocked': isBlocked,
    };
  }

  Contact copyWith({
    String? id,
    String? userId,
    String? username,
    String? profileImage,
    DateTime? addedAt,
    bool? isBlocked,
  }) {
    return Contact(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      profileImage: profileImage ?? this.profileImage,
      addedAt: addedAt ?? this.addedAt,
      isBlocked: isBlocked ?? this.isBlocked,
    );
  }
}
