class Conversation {
  final String id;
  final String user1Id;
  final String user2Id;
  final String user1Name;
  final String user2Name;
  final String? user1ProfileImage;
  final String? user2ProfileImage;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final DateTime createdAt;
  final Map<String, int> unreadCounts;

  Conversation({
    required this.id,
    required this.user1Id,
    required this.user2Id,
    required this.user1Name,
    required this.user2Name,
    this.user1ProfileImage,
    this.user2ProfileImage,
    this.lastMessage,
    this.lastMessageTime,
    required this.createdAt,
    this.unreadCounts = const {},
  });

  // Get the other user's name for the current user
  String getOtherUserName(String currentUserId) {
    return currentUserId == user1Id ? user2Name : user1Name;
  }

  // Get the other user's ID for the current user
  String getOtherUserId(String currentUserId) {
    return currentUserId == user1Id ? user2Id : user1Id;
  }

  // Get the other user's profile image for the current user
  String? getOtherUserProfileImage(String currentUserId) {
    return currentUserId == user1Id ? user2ProfileImage : user1ProfileImage;
  }

  // Get unread count for current user
  int getUnreadCount(String currentUserId) {
    return unreadCounts[currentUserId] ?? 0;
  }

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'],
      user1Id: json['user1Id'],
      user2Id: json['user2Id'],
      user1Name: json['user1Name'],
      user2Name: json['user2Name'],
      user1ProfileImage: json['user1ProfileImage'],
      user2ProfileImage: json['user2ProfileImage'],
      lastMessage: json['lastMessage'],
      lastMessageTime: json['lastMessageTime'] != null 
          ? DateTime.parse(json['lastMessageTime'])
          : null,
      createdAt: DateTime.parse(json['createdAt']),
      unreadCounts: Map<String, int>.from(json['unreadCounts'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user1Id': user1Id,
      'user2Id': user2Id,
      'user1Name': user1Name,
      'user2Name': user2Name,
      'user1ProfileImage': user1ProfileImage,
      'user2ProfileImage': user2ProfileImage,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'unreadCounts': unreadCounts,
    };
  }

  Conversation copyWith({
    String? id,
    String? user1Id,
    String? user2Id,
    String? user1Name,
    String? user2Name,
    String? user1ProfileImage,
    String? user2ProfileImage,
    String? lastMessage,
    DateTime? lastMessageTime,
    DateTime? createdAt,
    Map<String, int>? unreadCounts,
  }) {
    return Conversation(
      id: id ?? this.id,
      user1Id: user1Id ?? this.user1Id,
      user2Id: user2Id ?? this.user2Id,
      user1Name: user1Name ?? this.user1Name,
      user2Name: user2Name ?? this.user2Name,
      user1ProfileImage: user1ProfileImage ?? this.user1ProfileImage,
      user2ProfileImage: user2ProfileImage ?? this.user2ProfileImage,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      createdAt: createdAt ?? this.createdAt,
      unreadCounts: unreadCounts ?? this.unreadCounts,
    );
  }

  // Generate conversation ID from two user IDs (consistent ordering)
  static String generateConversationId(String userId1, String userId2) {
    List<String> sortedIds = [userId1, userId2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }
}
