import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:instant_chat_app/models/message.dart';
import 'package:instant_chat_app/models/chat_room.dart';
import 'package:instant_chat_app/models/user.dart';
import 'package:instant_chat_app/services/connectivity_service.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ConnectivityService _connectivityService = ConnectivityService();

  // Chat Room operations
  Future<void> saveChatRoomToFirebase(ChatRoom chatRoom) async {
    try {
      await _firestore.collection('chat_rooms').doc(chatRoom.id).set({
        'id': chatRoom.id,
        'name': chatRoom.name,
        'description': chatRoom.description,
        'participants': chatRoom.participants.map((u) => u.toJson()).toList(),
        'lastMessage': chatRoom.lastMessage?.toJson(),
        'createdAt': chatRoom.createdAt.toIso8601String(),
        'createdBy': chatRoom.createdBy,
        'isPrivate': chatRoom.isPrivate,
        'qrCode': chatRoom.qrCode,
      });
    } catch (e) {
      debugPrint('Error saving chat room to Firebase: $e');
      rethrow;
    }
  }

  Stream<List<ChatRoom>> listenToChatRooms() {
    return _firestore
        .collection('chat_rooms')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatRoom.fromJson(doc.data()))
              .toList(),
        );
  }

  // Message operations
  Future<void> sendMessageToFirebase(Message message) async {
    try {
      await _firestore.collection('messages').doc(message.id).set({
        'id': message.id,
        'chatRoomId': message.chatRoomId,
        'senderId': message.senderId,
        'senderName': message.senderName,
        'content': message.content,
        'type': message.type.index,
        'timestamp': message.timestamp.toIso8601String(),
        'isRead': message.isRead,
        'imageUrl': message.imageUrl,
        'fileName': message.fileName,
        'synced': true, // Mark as synced when sent to Firebase
      });
    } catch (e) {
      debugPrint('Error sending message to Firebase: $e');
      rethrow;
    }
  }

  Stream<List<Message>> listenToMessages(String chatRoomId) {
    return _firestore
        .collection('messages')
        .where('chatRoomId', isEqualTo: chatRoomId)
        .orderBy('timestamp')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Message.fromJson(doc.data())).toList(),
        );
  }

  Future<List<Message>> fetchMessages(String chatRoomId) async {
    try {
      final querySnapshot = await _firestore
          .collection('messages')
          .where('chatRoomId', isEqualTo: chatRoomId)
          .orderBy('timestamp')
          .get();

      return querySnapshot.docs
          .map((doc) => Message.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching messages from Firebase: $e');
      return [];
    }
  }

  // Sync unsynced messages to Firebase (for offline support)
  Future<void> syncUnsyncedMessages(List<Message> unsyncedMessages) async {
    try {
      WriteBatch batch = _firestore.batch();

      for (Message message in unsyncedMessages) {
        DocumentReference docRef = _firestore
            .collection('messages')
            .doc(message.id);
        batch.set(docRef, {
          'id': message.id,
          'chatRoomId': message.chatRoomId,
          'senderId': message.senderId,
          'senderName': message.senderName,
          'content': message.content,
          'type': message.type.index,
          'timestamp': message.timestamp.toIso8601String(),
          'isRead': message.isRead,
          'imageUrl': message.imageUrl,
          'fileName': message.fileName,
          'synced': true,
        });
      }

      await batch.commit();
      debugPrint('Synced ${unsyncedMessages.length} messages to Firebase');
    } catch (e) {
      debugPrint('Error syncing messages to Firebase: $e');
      rethrow;
    }
  }

  // User operations
  Future<void> saveUserToFirebase(User user) async {
    try {
      debugPrint('🔥 FIRESTORE: Saving user to Firebase...');
      debugPrint('🔥 FIRESTORE: User ID: ${user.id}');
      debugPrint('🔥 FIRESTORE: Username: ${user.username}');
      debugPrint('🔥 FIRESTORE: Email: ${user.email}');

      await _firestore
          .collection('users')
          .doc(user.id)
          .set({
            'id': user.id,
            'username': user.username,
            'email': user.email,
            'profileImage': user.profileImage,
            'lastSeen': user.lastSeen.toIso8601String(),
            'isOnline': user.isOnline,
          })
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              debugPrint('🔥 FIRESTORE: Save user operation timed out');
              throw 'Failed to save user data to Firebase - timeout';
            },
          );

      debugPrint('🔥 FIRESTORE: User saved successfully to Firebase');
    } catch (e) {
      debugPrint('🔥 FIRESTORE: Error saving user to Firebase: $e');
      rethrow;
    }
  }

  Stream<User?> listenToUser(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? User.fromJson(doc.data()!) : null);
  }

  // Check connection status
  Stream<bool> get connectionStatus {
    return _connectivityService.connectivityStream;
  }
}
