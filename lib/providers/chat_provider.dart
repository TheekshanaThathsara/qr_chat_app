import 'package:flutter/foundation.dart';
import 'package:instant_chat_app/models/chat_room.dart';
import 'package:instant_chat_app/models/message.dart';
import 'package:instant_chat_app/models/user.dart';
import 'package:instant_chat_app/services/database_service.dart';
import 'package:instant_chat_app/services/socket_service.dart';
import 'package:instant_chat_app/services/firebase_service.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';

class ChatProvider with ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  final SocketService _socketService = SocketService();
  final FirebaseService _firebaseService = FirebaseService();
  final Uuid _uuid = const Uuid();

  List<ChatRoom> _chatRooms = [];
  List<Message> _currentMessages = [];
  ChatRoom? _currentChatRoom;
  bool _isLoading = false;
  bool _isConnected = false;
  StreamSubscription<List<Message>>? _messageSubscription;
  bool _isOnline = false;

  List<ChatRoom> get chatRooms => _chatRooms;
  List<Message> get currentMessages => _currentMessages;
  ChatRoom? get currentChatRoom => _currentChatRoom;
  bool get isLoading => _isLoading;
  bool get isConnected => _isConnected;
  bool get isOnline => _isOnline;

  Future<void> deleteChatRoom(String chatRoomId) async {
    try {
      await _databaseService.deleteChatRoom(chatRoomId);
      _chatRooms.removeWhere((room) => room.id == chatRoomId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting chat room: $e');
    }
  }

  Future<void> initializeChat(User currentUser) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _databaseService.initializeDatabase();

      // Sync unsynced messages when coming online
      await _syncUnsyncedMessages();

      // Listen to Firebase connection status
      _firebaseService.connectionStatus.listen((isOnline) {
        _isOnline = isOnline;
        if (isOnline) {
          _syncUnsyncedMessages();
        }
        notifyListeners();
      });

      await loadChatRooms();
      _isConnected = false; // Set to false since no socket connection
    } catch (e) {
      debugPrint('Error initializing chat: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadChatRooms() async {
    try {
      _chatRooms = await _databaseService.getChatRooms();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading chat rooms: $e');
    }
  }

  Future<void> loadMessages(String chatRoomId) async {
    try {
      _currentMessages = await _databaseService.getMessages(chatRoomId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading messages: $e');
    }
  }

  Future<ChatRoom> createChatRoom({
    required String name,
    String? description,
    required User creator,
    bool isPrivate = false,
  }) async {
    try {
      final chatRoom = ChatRoom(
        id: _uuid.v4(),
        name: name,
        description: description,
        participants: [creator],
        createdAt: DateTime.now(),
        createdBy: creator.id,
        isPrivate: isPrivate,
        qrCode: _uuid.v4(), // Generate QR code data
      );

      await _databaseService.saveChatRoom(chatRoom);
      _chatRooms.add(chatRoom);
      notifyListeners();

      return chatRoom;
    } catch (e) {
      debugPrint('Error creating chat room: $e');
      rethrow;
    }
  }

  Future<void> joinChatRoom(String chatRoomId, User user) async {
    try {
      final chatRoom = await _databaseService.getChatRoom(chatRoomId);
      if (chatRoom != null) {
        final updatedParticipants = [...chatRoom.participants];
        if (!updatedParticipants.any((p) => p.id == user.id)) {
          updatedParticipants.add(user);

          final updatedChatRoom = chatRoom.copyWith(
            participants: updatedParticipants,
          );

          await _databaseService.saveChatRoom(updatedChatRoom);

          final index = _chatRooms.indexWhere((room) => room.id == chatRoomId);
          if (index != -1) {
            _chatRooms[index] = updatedChatRoom;
          } else {
            _chatRooms.add(updatedChatRoom);
          }

          _socketService.joinRoom(chatRoomId);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error joining chat room: $e');
      rethrow;
    }
  }

  Future<void> sendMessage({
    required String content,
    required User sender,
    MessageType type = MessageType.text,
    String? imageUrl,
    String? fileName,
  }) async {
    if (_currentChatRoom == null) return;

    try {
      final message = Message(
        id: _uuid.v4(),
        chatRoomId: _currentChatRoom!.id,
        senderId: sender.id,
        senderName: sender.username,
        content: content,
        type: type,
        timestamp: DateTime.now(),
        imageUrl: imageUrl,
        fileName: fileName,
      );

      // Always save to SQLite first (for offline support)
      await _databaseService.saveMessage(message, synced: false);
      _currentMessages.add(message);

      // Try to send to Firebase if online
      if (_isOnline) {
        try {
          await _firebaseService.sendMessageToFirebase(message);
          // Mark as synced if successful
          await _databaseService.markMessageAsSynced(message.id);
        } catch (e) {
          debugPrint('Failed to send to Firebase, will sync later: $e');
        }
      }

      // Update last message in chat room
      final updatedChatRoom = _currentChatRoom!.copyWith(lastMessage: message);
      await _databaseService.saveChatRoom(updatedChatRoom);

      final index = _chatRooms.indexWhere(
        (room) => room.id == _currentChatRoom!.id,
      );
      if (index != -1) {
        _chatRooms[index] = updatedChatRoom;
      }

      _socketService.sendMessage(message);
      notifyListeners();
    } catch (e) {
      debugPrint('Error sending message: $e');
      rethrow;
    }
  }

  void setCurrentChatRoom(ChatRoom? chatRoom) {
    // Cancel previous subscription if any
    _messageSubscription?.cancel();

    _currentChatRoom = chatRoom;
    if (chatRoom != null) {
      loadMessages(chatRoom.id);

      // Listen to Firebase messages in real-time when online
      if (_isOnline) {
        _messageSubscription = _firebaseService
            .listenToMessages(chatRoom.id)
            .listen(
              (firebaseMessages) async {
                // Update local SQLite with Firebase messages
                for (var message in firebaseMessages) {
                  await _databaseService.saveMessage(message, synced: true);
                }
                // Reload messages from SQLite for consistency
                await loadMessages(chatRoom.id);
              },
              onError: (error) {
                debugPrint('Error listening to Firebase messages: $error');
              },
            );
      }
    }
    notifyListeners();
  }

  Future<void> _syncUnsyncedMessages() async {
    try {
      final unsyncedMessages = await _databaseService.getUnsyncedMessages();
      if (unsyncedMessages.isNotEmpty) {
        await _firebaseService.syncUnsyncedMessages(unsyncedMessages);
        // Mark all as synced
        for (var message in unsyncedMessages) {
          await _databaseService.markMessageAsSynced(message.id);
        }
        debugPrint('Synced ${unsyncedMessages.length} unsynced messages');
      }
    } catch (e) {
      debugPrint('Error syncing unsynced messages: $e');
    }
  }

  // Commented out socket-related methods for now
  /*
  void _onMessageReceived(Message message) {
    if (_currentChatRoom?.id == message.chatRoomId) {
      _currentMessages.add(message);
    }

    // Update last message in chat room
    final index = _chatRooms.indexWhere(
      (room) => room.id == message.chatRoomId,
    );
    if (index != -1) {
      _chatRooms[index] = _chatRooms[index].copyWith(lastMessage: message);
    }

    _databaseService.saveMessage(message);
    notifyListeners();
  }

  void _onUserJoined(String userId, String chatRoomId) {
    debugPrint('User $userId joined room $chatRoomId');
    // Handle user joined logic
  }

  void _onUserLeft(String userId, String chatRoomId) {
    debugPrint('User $userId left room $chatRoomId');
    // Handle user left logic
  }

  void _onConnectionChanged(bool isConnected) {
    _isConnected = isConnected;
    notifyListeners();
  }
  */

  Future<void> disconnect() async {
    _messageSubscription?.cancel();
    // await _socketService.disconnect(); // Commented out for now
    _isConnected = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _socketService.disconnect();
    super.dispose();
  }
}
