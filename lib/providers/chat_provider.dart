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
  final Map<String, StreamSubscription<User?>>
      _userProfileSubscriptions = {}; // New: Track user profile listeners
  bool _isOnline = false;  List<ChatRoom> get chatRooms => _chatRooms;
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

  Future<void> initializeChat(User currentUser) async {
    _isLoading = true;
    _currentUser = currentUser; // Store the current user
    debugPrint('🔄 ChatProvider: Initializing chat for user ${currentUser.username} (${currentUser.id})');
    notifyListeners();

    try {
      await _databaseService.initializeDatabase();

      // Sync unsynced messages when coming online
      await _syncUnsyncedMessages();

          // Listen to Firebase connection status
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
                              // Check if this is a newly joined room for the current user
                              final existingLocalList = _chatRooms.where((r) => r.id == room.id);
                              final existingLocal = existingLocalList.isNotEmpty ? existingLocalList.first : null;
                              bool isNewParticipation = false;
                              
                              if (existingLocal != null) {
                                final wasParticipant = existingLocal.participants.any((p) => p.id == currentUser.id);
                                final isNowParticipant = participants.contains(currentUser.id);
                                isNewParticipation = !wasParticipant && isNowParticipant;
                              } else {
                                isNewParticipation = true;
                              }
                              
                              // If this is a new participation, ensure message listener is set up
                              if (isNewParticipation) {
                                _ensureRoomMessageListener(room.id);
                                debugPrint('Set up listener for newly joined room: ${room.id}');
                              }
                              
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
          });      await loadChatRooms();
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
                // Filter out empty/blank messages
                if (m.content.trim().isEmpty && m.type != MessageType.system) {
                  continue; // Skip empty non-system messages
                }
                
                // For system messages, also check if content is meaningful
                if (m.type == MessageType.system && m.content.trim().isEmpty) {
                  continue; // Skip empty system messages
                }
                
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
                    // Reload messages for the current room to show all messages
                    await loadMessages(roomId);
                  }

                  // Notify listeners to update the UI
                  notifyListeners();
                }
              }
            },
            onError: (err) {
              debugPrint('Error listening to messages for $roomId: $err');
            },
          );

      _roomMessageSubscriptions[roomId] = sub;
      debugPrint('Set up global message listener for room: $roomId');
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
        debugPrint('Loaded ${_chatRooms.length} chat rooms for user ${_currentUser!.username} (${_currentUser!.id})');
        for (var room in _chatRooms) {
          final participantNames = room.participants.map((p) => '${p.username}(${p.id})').join(', ');
          debugPrint('  Room: ${room.name} (${room.id}) - Participants: [$participantNames]');
        }
        
        // Set up real-time listeners for user profile changes
        // Always refresh listeners to ensure they work after hot reload
        _refreshUserProfileListeners();
        
        notifyListeners();
      } else {
        // Fallback to empty list if no current user
        _chatRooms = [];
        debugPrint('No current user, loaded 0 chat rooms');
        notifyListeners();
      }
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
      final allMessages = await _databaseService.getMessages(chatRoomId);
      
      // Filter out empty/blank messages to prevent blank message display
      _currentMessages = allMessages.where((message) {
        // Keep system messages and non-empty messages
        if (message.type == MessageType.system) {
          return message.content.trim().isNotEmpty;
        }
        // For other message types, ensure content is not empty
        return message.content.trim().isNotEmpty;
      }).toList();
      
      debugPrint('Loaded ${_currentMessages.length} valid messages for room $chatRoomId (filtered from ${allMessages.length} total)');
      
      // Debug: Show last few messages for verification
      if (_currentMessages.isNotEmpty) {
        debugPrint('Recent messages:');
        for (var msg in _currentMessages.take(5)) {
          debugPrint('  ${msg.senderName}: ${msg.content}');
        }
      }
      
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

      debugPrint('🚀 Creating room: ${chatRoom.name} (${chatRoom.id}) by ${creator.username} (${creator.id})');
      debugPrint('🚀 Initial participants: [${creator.username}(${creator.id})]');
      
      await _databaseService.saveChatRoom(chatRoom);
      debugPrint('✅ Saved room to local database');
      
      // Save to Firebase for real-time sync
      try {
        await _firebaseService.saveChatRoomToFirebase(chatRoom);
        debugPrint('✅ Successfully saved new room to Firebase');
        
        // Verify the room was saved correctly to Firebase
        final savedRoom = await _firebaseService.fetchChatRoomById(chatRoom.id);
        if (savedRoom != null) {
          final savedParticipants = savedRoom.participants.map((p) => '${p.username}(${p.id})').join(', ');
          debugPrint('✅ Verified Firebase save - Participants: [$savedParticipants]');
        } else {
          debugPrint('❌ Failed to verify Firebase save - room not found');
        }
      } catch (e) {
        debugPrint('❌ Failed to save new room to Firebase: $e');
      }
      
      _chatRooms.add(chatRoom);
      debugPrint('✅ Added room to local _chatRooms list');
      
      // Set up message listener for this room
      _ensureRoomMessageListener(chatRoom.id);
      
      notifyListeners();

      return chatRoom;
    } catch (e) {
      debugPrint('❌ Error creating chat room: $e');
      rethrow;
    }
  }

  Future<void> joinChatRoom(String chatRoomId, User user) async {
    try {
      debugPrint('🔄 JOIN: User ${user.username} (${user.id}) attempting to join room $chatRoomId');
      
      // First try to get the room from Firebase (most up-to-date)
      ChatRoom? chatRoom = await _firebaseService.fetchChatRoomById(chatRoomId);
      
      // If not found in Firebase, try local database
      if (chatRoom == null) {
        debugPrint('🔍 JOIN: Room $chatRoomId not found in Firebase, trying local database');
        chatRoom = await _databaseService.getChatRoom(chatRoomId);
      }
      
      if (chatRoom != null) {
        final room = chatRoom; // Explicit non-null assignment for flow analysis
        debugPrint('✅ JOIN: Found room: ${room.name} with ${room.participants.length} participants');
        final currentParticipants = room.participants.map((p) => '${p.username}(${p.id})').join(', ');
        debugPrint('🔍 JOIN: Current participants: [$currentParticipants]');
        
        final updatedParticipants = [...room.participants];
        bool participantsChanged = false;
        
        // Add the joining user if not already present
        if (!updatedParticipants.any((p) => p.id == user.id)) {
          updatedParticipants.add(user);
          participantsChanged = true;
          debugPrint('✅ JOIN: Adding ${user.username} to room participants');
        }
        
        // CRITICAL FIX: Ensure room creator is also a participant
        if (room.createdBy.isNotEmpty && !updatedParticipants.any((p) => p.id == room.createdBy)) {
          // Fetch creator user data and add them
          try {
            final creatorData = await _firebaseService.fetchUserById(room.createdBy);
            if (creatorData != null) {
              updatedParticipants.add(creatorData);
              participantsChanged = true;
              debugPrint('✅ JOIN: Re-added room creator ${creatorData.username} (${creatorData.id}) as participant');
            }
          } catch (e) {
            debugPrint('❌ JOIN: Failed to fetch creator data: $e');
          }
        }

        if (participantsChanged) {
          final updatedChatRoom = room.copyWith(
            participants: updatedParticipants,
          );

          // Save to local database
          await _databaseService.saveChatRoom(updatedChatRoom);
          debugPrint('✅ JOIN: Saved updated room to local database');
          
          // Save to Firebase for real-time sync
          try {
            await _firebaseService.saveChatRoomToFirebase(updatedChatRoom);
            debugPrint('✅ JOIN: Successfully updated room participants in Firebase');
            
            // Verify the update was saved correctly
            final verifyRoom = await _firebaseService.fetchChatRoomById(chatRoomId);
            if (verifyRoom != null) {
              final verifyParticipants = verifyRoom.participants.map((p) => '${p.username}(${p.id})').join(', ');
              debugPrint('✅ JOIN: Verified Firebase update - Participants: [$verifyParticipants]');
            }
          } catch (e) {
            debugPrint('❌ JOIN: Failed to save updated room to Firebase: $e');
          }

          final index = _chatRooms.indexWhere((room) => room.id == chatRoomId);
          if (index != -1) {
            _chatRooms[index] = updatedChatRoom;
            debugPrint('✅ JOIN: Updated room in local _chatRooms list');
          } else {
            _chatRooms.add(updatedChatRoom);
            debugPrint('✅ JOIN: Added room to local _chatRooms list');
          }

          // Force reload chat rooms for all users to ensure sync
          await loadChatRooms();
          debugPrint('✅ JOIN: Force reloaded chat rooms for sync');

          // Set up message listener for this room
          _ensureRoomMessageListener(chatRoomId);
          
          _socketService.joinRoom(chatRoomId);
          notifyListeners();
          
          // Send a system message to notify that a user joined
          try {
            final joinMessage = Message(
              id: _uuid.v4(),
              content: '${user.username} joined the room',
              senderId: 'system',
              senderName: 'System',
              conversationId: chatRoomId,
              timestamp: DateTime.now(),
              type: MessageType.system,
            );
            await _databaseService.saveMessage(joinMessage, synced: false);
            debugPrint('✅ JOIN: Saved join message for ${user.username}');
            
            // Try to save to Firebase
            try {
              await _firebaseService.sendMessageToFirebase(joinMessage);
            } catch (e) {
              debugPrint('❌ JOIN: Failed to save join message to Firebase: $e');
            }
          } catch (e) {
            debugPrint('❌ JOIN: Failed to create join message: $e');
          }
        } else {
          debugPrint('ℹ️ JOIN: ${user.username} is already a participant in room ${room.name}');
          // Still force reload to ensure sync
          await loadChatRooms();
          debugPrint('✅ JOIN: Force reloaded chat rooms for sync (no changes needed)');
        }
      } else {
        debugPrint('❌ JOIN: Chat room $chatRoomId not found');
        throw Exception('Chat room not found');
      }
    } catch (e) {
      debugPrint('❌ JOIN: Error joining chat room: $e');
      rethrow;
    }
  }

  Future<ChatRoom?> getChatRoomById(String roomId) async {
    try {
      // First try Firebase for most up-to-date data
      ChatRoom? room = await _firebaseService.fetchChatRoomById(roomId);
      
      // If not found in Firebase, try local database
      if (room == null) {
        room = await _databaseService.getChatRoom(roomId);
      }
      
      return room;
    } catch (e) {
      debugPrint('Error getting chat room by ID: $e');
      return null;
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

    // Validate content to prevent empty messages
    final trimmedContent = content.trim();
    if (trimmedContent.isEmpty && type == MessageType.text) {
      debugPrint('Skipping empty text message');
      return;
    }

    try {
      final message = Message(
        id: _uuid.v4(),
        conversationId: _currentChatRoom!.id,
        senderId: sender.id,
        senderName: sender.username,
        content: trimmedContent, // Use trimmed content
        type: type,
        timestamp: DateTime.now(),
        imageUrl: imageUrl,
        fileName: fileName,
      );

      debugPrint('Sending message: ${message.senderName}: ${message.content}');

      // Always save to SQLite first (for offline support)
      await _databaseService.saveMessage(message, synced: false);
      
      // Add to current messages immediately for instant UI update
      _currentMessages.add(message);
      
      // Try to send to Firebase if online
      if (_isOnline) {
        try {
          await _firebaseService.sendMessageToFirebase(message);
          // Mark as synced if successful
          await _databaseService.markMessageAsSynced(message.id);
          debugPrint('Message sent to Firebase successfully');
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
      // Always load messages from local database first
      loadMessages(chatRoom.id);

      // Set up real-time listener to Firebase for this specific room
      // This ensures messages are updated in real-time when the room is open
      _messageSubscription = _firebaseService
          .listenToMessages(chatRoom.id)
          .listen(
            (firebaseMessages) async {
              // Save all Firebase messages to local database
              for (var message in firebaseMessages) {
                // Filter out empty/blank messages
                if (message.content.trim().isEmpty && message.type != MessageType.system) {
                  continue; // Skip empty non-system messages
                }
                
                // For system messages, also check if content is meaningful
                if (message.type == MessageType.system && message.content.trim().isEmpty) {
                  continue; // Skip empty system messages
                }
                
                try {
                  await _databaseService.saveMessage(message, synced: true);
                } catch (e) {
                  debugPrint('Error saving Firebase message locally: $e');
                }
              }
              
              // Reload messages from local database to update UI
              // This ensures all messages (including those from other users) are displayed
              await loadMessages(chatRoom.id);
            },
            onError: (error) {
              debugPrint('Error listening to Firebase messages: $error');
              // On error, try to reload from local database
              loadMessages(chatRoom.id);
            },
          );
      
      debugPrint('Set up real-time listener for room: ${chatRoom.id}');
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

  /// Update user information in all chat rooms they participate in
  Future<void> updateUserInChatRooms(User updatedUser) async {
    try {
      debugPrint('🔄 ChatProvider: Updating user ${updatedUser.username} (${updatedUser.id}) in all chat rooms');
      
      bool hasUpdates = false;
      
      // Update user in local chat rooms list
      for (int i = 0; i < _chatRooms.length; i++) {
        final room = _chatRooms[i];
        final participants = room.participants;
        bool roomUpdated = false;
        
        for (int j = 0; j < participants.length; j++) {
          if (participants[j].id == updatedUser.id) {
            participants[j] = updatedUser;
            roomUpdated = true;
            break;
          }
        }
        
        if (roomUpdated) {
          final updatedRoom = room.copyWith(participants: participants);
          _chatRooms[i] = updatedRoom;
          hasUpdates = true;
          
          // Save updated room to local database
          await _databaseService.saveChatRoom(updatedRoom);
          
          // Try to save to Firebase for sync with other users
          try {
            await _firebaseService.saveChatRoomToFirebase(updatedRoom);
          } catch (e) {
            debugPrint('❌ Failed to sync updated room to Firebase: $e');
          }
          
          debugPrint('✅ Updated user info in room: ${room.name}');
        }
      }
      
      // Update current chat room if it contains the user
      if (_currentChatRoom != null) {
        final currentParticipants = _currentChatRoom!.participants;
        bool currentRoomUpdated = false;
        
        for (int i = 0; i < currentParticipants.length; i++) {
          if (currentParticipants[i].id == updatedUser.id) {
            currentParticipants[i] = updatedUser;
            currentRoomUpdated = true;
            break;
          }
        }
        
        if (currentRoomUpdated) {
          _currentChatRoom = _currentChatRoom!.copyWith(participants: currentParticipants);
          hasUpdates = true;
        }
      }
      
      if (hasUpdates) {
        notifyListeners();
        debugPrint('✅ ChatProvider: Successfully updated user info in chat rooms');
      }
      
    } catch (e) {
      debugPrint('❌ ChatProvider: Error updating user in chat rooms: $e');
    }
  }

  /// Set up real-time listeners for user profile changes
  void _setupUserProfileListeners() {
    try {
      debugPrint('🔄 ChatProvider: _setupUserProfileListeners called');
      // Get all unique user IDs from chat rooms (excluding current user)
      final Set<String> userIds = <String>{};
      for (final room in _chatRooms) {
        for (final participant in room.participants) {
          if (participant.id != _currentUser?.id) {
            userIds.add(participant.id);
          }
        }
      }

      debugPrint('🔄 ChatProvider: Setting up profile listeners for ${userIds.length} users: ${userIds.toList()}');

      // Set up listeners for each unique user
      for (final userId in userIds) {
        if (!_userProfileSubscriptions.containsKey(userId)) {
          final subscription = _firebaseService.listenToUser(userId).listen(
            (updatedUser) {
              if (updatedUser != null) {
                debugPrint('🔄 ChatProvider: Received real-time update for user ${updatedUser.username} (${updatedUser.id})');
                // Update user info in all relevant chat rooms
                updateUserInChatRooms(updatedUser);
              }
            },
            onError: (error) {
              debugPrint('❌ ChatProvider: Error listening to user $userId: $error');
            },
          );
          _userProfileSubscriptions[userId] = subscription;
          debugPrint('✅ ChatProvider: Set up profile listener for user: $userId');
        }
      }
    } catch (e) {
      debugPrint('❌ ChatProvider: Error setting up user profile listeners: $e');
    }
  }

  /// Clean up old user profile listeners and set up new ones
  void _refreshUserProfileListeners() {
    debugPrint('🔄 ChatProvider: _refreshUserProfileListeners called - cleaning up ${_userProfileSubscriptions.length} existing listeners');
    // Cancel existing subscriptions
    for (final subscription in _userProfileSubscriptions.values) {
      subscription.cancel();
    }
    _userProfileSubscriptions.clear();
    
    // Set up new listeners
    _setupUserProfileListeners();
  }

  /// Public method to refresh user profile listeners (useful after hot reload)
  void refreshUserProfileListeners() {
    debugPrint('🔄 ChatProvider: Manually refreshing user profile listeners...');
    _refreshUserProfileListeners();
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
    
    // Clean up user profile subscriptions
    for (var sub in _userProfileSubscriptions.values) {
      try {
        sub.cancel();
      } catch (_) {}
    }
    _userProfileSubscriptions.clear();
    
    _socketService.disconnect();
    super.dispose();
  }
}
