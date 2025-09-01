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
  User? _currentUser; // Store current user
  bool _isLoading = false;
  bool _isConnected = false;
  StreamSubscription<List<Message>>? _messageSubscription;
  StreamSubscription<List<ChatRoom>>? _roomsSubscription;
  final Map<String, StreamSubscription<List<Message>>>
  _roomMessageSubscriptions = {};
  StreamSubscription<List<ChatRoom>>? _roomsSubscription;
  final Map<String, StreamSubscription<List<Message>>>
  _roomMessageSubscriptions = {};
  bool _isOnline = false;

  List<ChatRoom> get chatRooms => _chatRooms;
  List<Message> get currentMessages => _currentMessages;
  ChatRoom? get currentChatRoom => _currentChatRoom;
  User? get currentUser => _currentUser;
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

  Future<void> clearChatMessages(String chatRoomId) async {
    try {
      await _databaseService.clearChatMessages(chatRoomId);
      // update in-memory lastMessage
      final idx = _chatRooms.indexWhere((r) => r.id == chatRoomId);
      if (idx != -1) {
        final updated = _chatRooms[idx].copyWith(lastMessage: null);
        _chatRooms[idx] = updated;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error clearing messages for $chatRoomId: $e');
    }
  }

  Future<void> togglePinChatRoom(String chatRoomId, bool pin) async {
    try {
      await _databaseService.togglePinChatRoom(chatRoomId, pin);
      final idx = _chatRooms.indexWhere((r) => r.id == chatRoomId);
      if (idx != -1) {
        final updated = _chatRooms[idx].copyWith();
        // copyWith doesn't accept isPinned prior to our changes? It does now.
        _chatRooms[idx] = updated.copyWith();
        // Reload rooms to get latest ordering if pinning affects it
        await loadChatRooms();
      }
    } catch (e) {
      debugPrint('Error pinning chat room $chatRoomId: $e');
    }
  }

  Future<void> initializeChat(User currentUser) async {
    _isLoading = true;
    _currentUser = currentUser; // Store the current user
    notifyListeners();

    try {
      await _databaseService.initializeDatabase();

      // Sync unsynced messages when coming online
      await _syncUnsyncedMessages();

      // Listen to Firebase connection status
      _firebaseService.connectionStatus.listen((isOnline) async {
      _firebaseService.connectionStatus.listen((isOnline) async {
        _isOnline = isOnline;
        if (isOnline) {
          await _syncUnsyncedMessages();
          // Start listening to remote chat room changes and sync them locally
          try {
            _roomsSubscription?.cancel();
            _roomsSubscription = _firebaseService.listenToChatRooms().listen(
              (remoteRooms) async {
                try {
                  // Save/merge each remote room into local DB
                  for (var room in remoteRooms) {
                    try {
                      await _databaseService.saveChatRoom(room);

                      // If the current user is a participant in this room,
                      // fetch messages from Firebase and persist them locally
                      try {
                        // Extract participant ids robustly (User objects or maps)
                        final participants = room.participants
                            .map((p) {
                              try {
                                // If already a User object, access id property directly
                                return p.id;
                              } catch (_) {
                                try {
                                  // Fallback for Map representations
                                  return (p as Map)['id']?.toString() ??
                                      (p as Map)['userId']?.toString();
                                } catch (_) {
                                  return null;
                                }
                              }
                            })
                            .whereType<String>()
                            .toList();

                        debugPrint(
                          'Remote room ${room.id} participants: $participants',
                        );
                        if (participants.contains(currentUser.id)) {
                          final remoteMessages = await _firebaseService
                              .fetchMessages(room.id);
                          for (var msg in remoteMessages) {
                            try {
                              await _databaseService.saveMessage(
                                msg,
                                synced: true,
                              );
                            } catch (e) {
                              debugPrint(
                                'Failed to save remote message locally: $e',
                              );
                            }
                          }

                          // Update chat room lastMessage if needed
                          if (remoteMessages.isNotEmpty) {
                            final latest = remoteMessages.last;
                            final updatedRoom = room.copyWith(
                              lastMessage: latest,
                            );
                            await _databaseService.saveChatRoom(updatedRoom);
                            // If the user currently has this room open, reload messages
                            if (_currentChatRoom?.id == room.id) {
                              await loadMessages(room.id);
                            }
                          }
                        }
                      } catch (e) {
                        debugPrint(
                          'Error fetching messages for room ${room.id}: $e',
                        );
                      }
                    } catch (e) {
                      debugPrint('Failed to save remote chat room locally: $e');
                    }
                  }

                  // Reload chat rooms from local DB to update UI (only for current user)
                  await loadChatRooms();
                } catch (e) {
                  debugPrint('Error processing remote chat rooms: $e');
                }
              },
              onError: (err) {
                debugPrint('Error listening to remote chat rooms: $err');
              },
            );
            // Ensure we have active message listeners for rooms the user is in
            try {
              final localRooms = await _databaseService.getChatRoomsForUser(
                currentUser.id,
              );
              for (var room in localRooms) {
                final participantIds = room.participants
                    .map((p) => p.id)
                    .toList();
                if (participantIds.contains(currentUser.id)) {
                  _ensureRoomMessageListener(room.id);
                }
              }
            } catch (e) {
              debugPrint('Failed to ensure per-room listeners: $e');
            }
          } catch (e) {
            debugPrint('Failed to subscribe to remote chat rooms: $e');
          }
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

  void _ensureRoomMessageListener(String roomId) {
    if (_roomMessageSubscriptions.containsKey(roomId)) return;

    try {
      final sub = _firebaseService
          .listenToMessages(roomId)
          .listen(
            (messages) async {
              bool hasNewMessages = false;
              Message? latestMessage;

              for (var m in messages) {
                try {
                  await _databaseService.saveMessage(m, synced: true);
                  hasNewMessages = true;
                  if (latestMessage == null ||
                      m.timestamp.isAfter(latestMessage.timestamp)) {
                    latestMessage = m;
                  }
                } catch (e) {
                  debugPrint(
                    'Error saving incoming message for room $roomId: $e',
                  );
                }
              }

              // Update chat room's lastMessage if we received new messages
              if (hasNewMessages && latestMessage != null) {
                final roomIndex = _chatRooms.indexWhere(
                  (room) => room.id == roomId,
                );
                if (roomIndex != -1) {
                  final updatedRoom = _chatRooms[roomIndex].copyWith(
                    lastMessage: latestMessage,
                  );
                  _chatRooms[roomIndex] = updatedRoom;
                  await _databaseService.saveChatRoom(updatedRoom);

                  // If this is the current chat room, update it too
                  if (_currentChatRoom?.id == roomId) {
                    _currentChatRoom = updatedRoom;
                  }

                  // Notify listeners to update the chat list UI
                  notifyListeners();
                }
              }

              // If current chat open, reload messages
              if (_currentChatRoom?.id == roomId) {
                await loadMessages(roomId);
              }
            },
            onError: (err) {
              debugPrint('Error listening to messages for $roomId: $err');
            },
          );

      _roomMessageSubscriptions[roomId] = sub;
    } catch (e) {
      debugPrint('Failed to create message listener for $roomId: $e');
    }
  }

  Future<void> loadChatRooms() async {
    try {
      if (_currentUser != null) {
        // Load only chat rooms where the current user is a participant
        _chatRooms = await _databaseService.getChatRoomsForUser(
          _currentUser!.id,
        );
      } else {
        // Fallback to empty list if no current user
        _chatRooms = [];
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading chat rooms: $e');
      try {
        final raw = await _databaseService.getRawChatRooms();
        debugPrint('Raw chat_rooms rows: ${raw.length}');
        for (var r in raw.take(10)) {
          debugPrint(r.toString());
        }
      } catch (er) {
        debugPrint('Failed to dump raw chat rooms: $er');
      }
      try {
        throw e;
      } catch (st, _) {
        debugPrint('Stack trace: $st');
      }
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

      // Try to push updated chat room (with lastMessage) to Firebase so other users see it in their lists
      try {
        await _firebaseService.saveChatRoomToFirebase(updatedChatRoom);
      } catch (e) {
        debugPrint('Failed to save updated chat room to Firebase: $e');
      }

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
    // Cancel per-room subscriptions
    for (var sub in _roomMessageSubscriptions.values) {
      try {
        await sub.cancel();
      } catch (_) {}
    }
    _roomMessageSubscriptions.clear();
    // await _socketService.disconnect(); // Commented out for now
    _isConnected = false;
    notifyListeners();
  }

  /// Get or create a deterministic 1:1 private room between two users.
  /// This ensures both users always end up in the same room when they scan each other's QR codes.
  Future<ChatRoom> getOrCreatePrivateRoomWith(
    User currentUser,
    User otherUser, {
    String? displayName,
  }) async {
    try {
      // Create deterministic room ID by sorting user IDs
      final List<String> sortedIds = [currentUser.id, otherUser.id]..sort();
      final String deterministicRoomId = sortedIds.join('_');

      debugPrint(
        'ChatProvider: Looking for room with ID: $deterministicRoomId',
      );

      // 1. Check local database first
      ChatRoom? existingRoom = await _databaseService
          .getPrivateRoomBetweenUsers(currentUser.id, otherUser.id);

      if (existingRoom != null) {
        debugPrint(
          'ChatProvider: Found existing local room: ${existingRoom.id}',
        );
        // Make sure the room has the deterministic ID
        if (existingRoom.id != deterministicRoomId) {
          // Update room to use deterministic ID
          existingRoom = existingRoom.copyWith(id: deterministicRoomId);
          await _databaseService.saveChatRoom(existingRoom);
        }
        _ensureRoomMessageListener(existingRoom.id);
        await loadChatRooms();
        return existingRoom;
      }

      // 2. Check Firestore for existing room with deterministic ID
      final ChatRoom? remoteRoom = await _firebaseService.fetchChatRoomById(
        deterministicRoomId,
      );
      if (remoteRoom != null) {
        debugPrint('ChatProvider: Found remote room: ${remoteRoom.id}');
        // Save locally and set up listeners
        await _databaseService.saveChatRoom(remoteRoom);
        _ensureRoomMessageListener(remoteRoom.id);
        await loadChatRooms();
        return remoteRoom;
      }

      // 3. Create new deterministic room
      debugPrint(
        'ChatProvider: Creating new deterministic room: $deterministicRoomId',
      );
      final String roomName =
          displayName ??
          (otherUser.username.isNotEmpty ? otherUser.username : 'Private Chat');

      final ChatRoom newRoom = ChatRoom(
        id: deterministicRoomId,
        name: roomName,
        participants: [currentUser, otherUser],
        createdAt: DateTime.now(),
        createdBy: currentUser.id,
        isPrivate: true,
      );

      // Save locally first
      await _databaseService.saveChatRoom(newRoom);

      // Try to save to Firestore (non-fatal if it fails)
      try {
        await _firebaseService.saveChatRoomToFirebase(newRoom);
        debugPrint(
          'ChatProvider: Saved new room to Firestore: $deterministicRoomId',
        );
      } catch (e) {
        debugPrint('ChatProvider: Failed to save room to Firestore: $e');
      }

      // Set up listeners and refresh
      _ensureRoomMessageListener(newRoom.id);
      await loadChatRooms();

      return newRoom;
    } catch (e, stackTrace) {
      debugPrint('ChatProvider: Error in getOrCreatePrivateRoomWith: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _roomsSubscription?.cancel();
    for (var sub in _roomMessageSubscriptions.values) {
      try {
        sub.cancel();
      } catch (_) {}
    }
    _roomMessageSubscriptions.clear();
    _socketService.disconnect();
    super.dispose();
  }
}
