import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:instant_chat_app/models/message.dart';
import 'package:instant_chat_app/models/chat_room.dart';
import 'package:instant_chat_app/models/conversation.dart';
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

  Future<ChatRoom?> fetchChatRoomById(String roomId) async {
    try {
      final DocumentSnapshot doc = await _firestore
          .collection('chat_rooms')
          .doc(roomId)
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        return ChatRoom.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching chat room by ID: $e');
      return null;
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
        'conversationId': message.conversationId,
        'senderId': message.senderId,
        'senderName': message.senderName,
        'content': message.content,
        'type': message.type.index,
        'timestamp': message.timestamp.toIso8601String(),
        'isRead': message.isRead,
        'imageUrl': message.imageUrl,
        'fileName': message.fileName,
      });
    } catch (e) {
      debugPrint('Error sending message to Firebase: $e');
      rethrow;
    }
  }

  Stream<List<Message>> listenToMessages(String conversationId) {
    print('Setting up Firebase listener for conversation: $conversationId');
    
    try {
      return FirebaseFirestore.instance
          .collection('messages')
          .where('conversationId', isEqualTo: conversationId)
          // TEMPORARILY REMOVING orderBy due to Firebase index issues
          // .orderBy('timestamp')
          .snapshots()
          .map((snapshot) {
        print('Firebase listener received ${snapshot.docs.length} messages for conversation: $conversationId');
        
        List<Message> messages = snapshot.docs.map((doc) {
          Map<String, dynamic> data = doc.data();
          return Message.fromJson(data);
        }).toList();
        
        // Sort manually by timestamp
        messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        
        print('Firebase messages for conversation $conversationId: ${messages.length}');
        return messages;
      });
    } catch (e) {
      print('Error setting up Firebase listener: $e');
      return Stream.value([]);
    }
  }

  Future<List<Message>> fetchMessages(String conversationId) async {
    try {
      final querySnapshot = await _firestore
          .collection('messages')
          .where('conversationId', isEqualTo: conversationId)
          .get();

      final messages = querySnapshot.docs.map((doc) {
        final raw = <String, dynamic>{};
        try {
          raw.addAll(doc.data());
        } catch (_) {}

        final normalized = <String, dynamic>{
          'id': raw['id'] ?? doc.id,
          'conversationId': raw['conversationId'] ?? raw['conversation_id'],
          'senderId': raw['senderId'] ?? raw['sender_id'],
          'senderName':
              raw['senderName'] ?? raw['sender_name'] ?? raw['sender'],
          'content': raw['content'] ?? '',
          'type': raw['type'] is int
              ? raw['type']
              : int.tryParse(raw['type']?.toString() ?? '') ?? 0,
          'timestamp': raw['timestamp'] is String
              ? raw['timestamp']
              : (raw['timestamp']?.toString() ??
                    DateTime.now().toIso8601String()),
          'isRead': raw['isRead'] == true || raw['is_read'] == 1,
          'imageUrl': raw['imageUrl'] ?? raw['image_url'],
          'fileName': raw['fileName'] ?? raw['file_name'],
        };

        return Message.fromJson(normalized);
      }).toList();
      
      // Sort messages by timestamp in memory
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      return messages;
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
          'conversationId': message.conversationId,
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

  /// Fetch a single user document by id (one-shot).
  Future<User?> fetchUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      return User.fromJson(doc.data()!);
    } catch (e) {
      debugPrint('Error fetching user from Firebase: $e');
      return null;
    }
  }

  // Conversation operations
  Future<void> createConversation(Conversation conversation) async {
    try {
      await _firestore.collection('conversations').doc(conversation.id).set(conversation.toJson());
    } catch (e) {
      debugPrint('Error creating conversation in Firebase: $e');
      rethrow;
    }
  }

  Future<Conversation?> getConversationById(String conversationId) async {
    try {
      final doc = await _firestore.collection('conversations').doc(conversationId).get();
      if (doc.exists && doc.data() != null) {
        return Conversation.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting conversation from Firebase: $e');
      return null;
    }
  }

  Future<void> updateConversation(Conversation conversation) async {
    try {
      await _firestore.collection('conversations').doc(conversation.id).update(conversation.toJson());
    } catch (e) {
      debugPrint('Error updating conversation in Firebase: $e');
      rethrow;
    }
  }

  // Real-time listener for conversations
  Stream<List<Conversation>> listenToConversations(String userId) {
    print('Setting up Firebase listener for conversations of user: $userId');
    
    try {
      // Create a stream that combines both user1 and user2 queries
      return Stream.periodic(const Duration(seconds: 2))
          .asyncMap((_) async {
        List<Conversation> conversations = [];
        
        try {
          // Get conversations where user is user1
          final snapshot1 = await _firestore
              .collection('conversations')
              .where('user1Id', isEqualTo: userId)
              .get();
          
          for (var doc in snapshot1.docs) {
            try {
              conversations.add(Conversation.fromJson(doc.data()));
            } catch (e) {
              debugPrint('Error parsing conversation: $e');
            }
          }
          
          // Get conversations where user is user2
          final snapshot2 = await _firestore
              .collection('conversations')
              .where('user2Id', isEqualTo: userId)
              .get();
              
          for (var doc in snapshot2.docs) {
            try {
              final conversation = Conversation.fromJson(doc.data());
              // Check if this conversation is not already in the list
              if (!conversations.any((c) => c.id == conversation.id)) {
                conversations.add(conversation);
              }
            } catch (e) {
              debugPrint('Error parsing conversation: $e');
            }
          }
        } catch (e) {
          debugPrint('Error fetching conversations: $e');
        }
        
        // Sort by created time (latest first) since lastMessageTime might be null for new conversations
        conversations.sort((a, b) {
          if (a.lastMessageTime != null && b.lastMessageTime != null) {
            return b.lastMessageTime!.compareTo(a.lastMessageTime!);
          } else if (a.lastMessageTime != null) {
            return -1;
          } else if (b.lastMessageTime != null) {
            return 1;
          } else {
            return b.createdAt.compareTo(a.createdAt);
          }
        });
        
        print('Firebase listener received ${conversations.length} conversations for user: $userId');
        return conversations;
      }).distinct((previous, next) {
        // Only emit if the conversation list actually changed
        if (previous.length != next.length) return false;
        for (int i = 0; i < previous.length; i++) {
          if (previous[i].id != next[i].id || 
              previous[i].lastMessageTime != next[i].lastMessageTime) {
            return false;
          }
        }
        return true;
      });
    } catch (e) {
      debugPrint('Error setting up Firebase listener: $e');
      return Stream.value([]);
    }
  }

  Future<List<Conversation>> getConversationsForUser(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('conversations')
          .where('user1Id', isEqualTo: userId)
          .get();
      
      final querySnapshot2 = await _firestore
          .collection('conversations')
          .where('user2Id', isEqualTo: userId)
          .get();

      List<Conversation> conversations = [];
      
      // Add conversations where user is user1
      for (var doc in querySnapshot.docs) {
        try {
          conversations.add(Conversation.fromJson(doc.data()));
        } catch (e) {
          debugPrint('Error parsing conversation: $e');
        }
      }
      
      // Add conversations where user is user2
      for (var doc in querySnapshot2.docs) {
        try {
          conversations.add(Conversation.fromJson(doc.data()));
        } catch (e) {
          debugPrint('Error parsing conversation: $e');
        }
      }

      return conversations;
    } catch (e) {
      debugPrint('Error fetching conversations for user: $e');
      return [];
    }
  }

  Future<List<Message>> getMessagesForConversation(String conversationId) async {
    try {
      final querySnapshot = await _firestore
          .collection('messages')
          .where('conversationId', isEqualTo: conversationId)
          .orderBy('timestamp', descending: false)
          .get();

      return querySnapshot.docs
          .map((doc) => Message.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching messages for conversation: $e');
      return [];
    }
  }

  Future<void> sendMessage(Message message) async {
    try {
      await _firestore.collection('messages').doc(message.id).set(message.toJson());
    } catch (e) {
      debugPrint('Error sending message to Firebase: $e');
      rethrow;
    }
  }

  // Check connection status
  Stream<bool> get connectionStatus {
    return _connectivityService.connectivityStream;
  }
}
