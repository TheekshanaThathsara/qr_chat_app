enum MessageType {
  text,
  image,
  file,
  system,
}

class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final bool isRead;
  final String? imageUrl;
  final String? fileName;
  final String? replyToMessageId;
  final String? replyToContent;
  final String? replyToSenderName;
  final bool isDeleted;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.imageUrl,
    this.fileName,
    this.replyToMessageId,
    this.replyToContent,
    this.replyToSenderName,
    this.isDeleted = false,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      conversationId: json['conversationId'],
      senderId: json['senderId'],
      senderName: json['senderName'],
      content: json['content'],
      type: MessageType.values[json['type']],
      timestamp: DateTime.parse(json['timestamp']),
      isRead: json['isRead'] ?? false,
      imageUrl: json['imageUrl'],
      fileName: json['fileName'],
      replyToMessageId: json['replyToMessageId'],
      replyToContent: json['replyToContent'],
      replyToSenderName: json['replyToSenderName'],
      isDeleted: json['isDeleted'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
      'type': type.index,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'imageUrl': imageUrl,
      'fileName': fileName,
      'replyToMessageId': replyToMessageId,
      'replyToContent': replyToContent,
      'replyToSenderName': replyToSenderName,
      'isDeleted': isDeleted,
    };
  }

  Message copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderName,
    String? content,
    MessageType? type,
    DateTime? timestamp,
    bool? isRead,
    String? imageUrl,
    String? fileName,
    String? replyToMessageId,
    String? replyToContent,
    String? replyToSenderName,
    bool? isDeleted,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      imageUrl: imageUrl ?? this.imageUrl,
      fileName: fileName ?? this.fileName,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToContent: replyToContent ?? this.replyToContent,
      replyToSenderName: replyToSenderName ?? this.replyToSenderName,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
