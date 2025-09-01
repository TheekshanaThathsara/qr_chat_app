import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
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
  final bool isPinned;
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
  this.isPinned = false,
    this.qrCode,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    // id/name
    final id = json['id']?.toString() ?? '';
    final name = json['name']?.toString() ?? '';
    final description = json['description']?.toString();

    // participants may be stored as List<Map>, List<String(json)>, or a JSON string
    List<dynamic> participantsRaw = [];
    try {
      final p = json['participants'];
      if (p == null) {
        participantsRaw = [];
      } else if (p is String) {
        participantsRaw = jsonDecode(p) as List<dynamic>;
      } else if (p is List) {
        participantsRaw = p;
      } else {
        participantsRaw = [];
      }
    } catch (_) {
      participantsRaw = [];
    }

    final participants = <User>[];
    for (var item in participantsRaw) {
      try {
        if (item is Map) {
          participants.add(User.fromJson(Map<String, dynamic>.from(item)));
        } else if (item is String) {
          final decoded = jsonDecode(item);
          if (decoded is Map) {
            participants.add(User.fromJson(Map<String, dynamic>.from(decoded)));
          }
        }
      } catch (_) {
        // ignore malformed participant
      }
    }

    // lastMessage may be Map or JSON string
    dynamic lastMessageJson;
    try {
      final lm = json['lastMessage'] ?? json['last_message'];
      if (lm == null) {
        lastMessageJson = null;
      } else if (lm is String) {
        lastMessageJson = jsonDecode(lm);
      } else if (lm is Map) {
        lastMessageJson = lm;
      } else {
        lastMessageJson = null;
      }
    } catch (_) {
      lastMessageJson = null;
    }

    Message? lastMessage;
    try {
      if (lastMessageJson != null) {
        lastMessage = Message.fromJson(
          Map<String, dynamic>.from(lastMessageJson),
        );
      }
    } catch (_) {
      lastMessage = null;
    }

    // createdAt may be ISO string or Firestore Timestamp
    DateTime createdAt;
    try {
      final ca = json['createdAt'] ?? json['created_at'];
      if (ca is Timestamp) {
        createdAt = ca.toDate();
      } else if (ca is String) {
        createdAt = DateTime.parse(ca);
      } else if (ca is DateTime) {
        createdAt = ca;
      } else {
        createdAt = DateTime.now();
      }
    } catch (_) {
      createdAt = DateTime.now();
    }

    final createdBy = json['createdBy'] ?? json['created_by'] ?? '';
    final isPrivate = json['isPrivate'] ?? json['is_private'] ?? false;
    final qrCode = json['qrCode'] ?? json['qr_code'];

    return ChatRoom(
      id: id,
      name: name,
      description: description,
      participants: participants,
      lastMessage: lastMessage,
      createdAt: createdAt,
      createdBy: createdBy?.toString() ?? '',
      isPrivate: isPrivate is bool ? isPrivate : (isPrivate == 1),
      qrCode: qrCode?.toString(),
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
  'isPinned': isPinned,
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
  bool? isPinned,
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
  isPinned: isPinned ?? this.isPinned,
      qrCode: qrCode ?? this.qrCode,
    );
  }

  int get participantCount => participants.length;


  bool get hasUnreadMessages => lastMessage != null && !lastMessage!.isRead;
}
