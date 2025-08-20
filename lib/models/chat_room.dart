import 'package:instant_chat_app/models/user.dart';
import 'package:instant_chat_app/models/message.dart';

class ChatRoom {
  final String id;
  final String name;
  final String? description;
  final List<User> participants;
  final Message? lastMessage;
  final DateTime createdAt;
  final String createdBy;
  final bool isPrivate;
  final String? qrCode;

  ChatRoom({
    required this.id,
    required this.name,
    this.description,
    required this.participants,
    this.lastMessage,
    required this.createdAt,
    required this.createdBy,
    this.isPrivate = false,
    this.qrCode,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      participants: (json['participants'] as List)
          .map((user) => User.fromJson(user))
          .toList(),
      lastMessage: json['lastMessage'] != null
          ? Message.fromJson(json['lastMessage'])
          : null,
      createdAt: DateTime.parse(json['createdAt']),
      createdBy: json['createdBy'],
      isPrivate: json['isPrivate'] ?? false,
      qrCode: json['qrCode'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'participants': participants.map((user) => user.toJson()).toList(),
      'lastMessage': lastMessage?.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
      'isPrivate': isPrivate,
      'qrCode': qrCode,
    };
  }

  ChatRoom copyWith({
    String? id,
    String? name,
    String? description,
    List<User>? participants,
    Message? lastMessage,
    DateTime? createdAt,
    String? createdBy,
    bool? isPrivate,
    String? qrCode,
  }) {
    return ChatRoom(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      isPrivate: isPrivate ?? this.isPrivate,
      qrCode: qrCode ?? this.qrCode,
    );
  }

  int get participantCount => participants.length;
  
  bool get hasUnreadMessages => lastMessage != null && !lastMessage!.isRead;
}
