import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../services/firebase_service.dart';
import '../services/database_service.dart';

class ConversationProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final DatabaseService _databaseService = DatabaseService();

  List<Conversation> _conversations = [];
  List<Message> _currentMessages = [];
  String? _currentConversationId;
  bool _isLoading = false;
  StreamSubscription<List<Message>>? _messagesSubscription;
  StreamSubscription<List<Conversation>>? _conversationsSubscription;

  List<Conversation> get conversations => _conversations;
  List<Message> get currentMessages => _currentMessages;
  String? get currentConversationId => _currentConversationId;
  bool get isLoading => _isLoading;

  // Load all conversations for the current user with real-time updates
  Future<void> loadConversations(String currentUserId) async {
    _isLoading = true;
    notifyListeners();

    try {
      print('📱 ConversationProvider: Loading conversations for user: $currentUserId');
      
      // Cancel previous subscription if exists
      await _conversationsSubscription?.cancel();
      
      // Load from local database first for immediate display
      List<Conversation> localConversations = await _databaseService.getConversationsForUser(currentUserId);
      print('📱 ConversationProvider: Loaded ${localConversations.length} conversations from local DB');
      
      _conversations = localConversations;
      _isLoading = false;
      notifyListeners();

      // Set up real-time listener for Firebase updates
      _conversationsSubscription = _firebaseService.listenToConversations(currentUserId).listen(
        (List<Conversation> conversations) async {
          print('🔥 ConversationProvider: Real-time conversations update received: ${conversations.length} conversations');
          
          // Merge new conversations with existing ones to avoid duplicates
          Map<String, Conversation> conversationMap = {};
          
          // Add existing conversations to map
          for (Conversation existing in _conversations) {
            conversationMap[existing.id] = existing;
          }
          
          // Add/update with new conversations
          for (Conversation newConv in conversations) {
            conversationMap[newConv.id] = newConv;
          }
          
          // Update conversations list with deduplicated data
          _conversations = conversationMap.values.toList();
          
          // Sort by last message time
          _conversations.sort((a, b) {
            if (a.lastMessageTime == null && b.lastMessageTime == null) return 0;
            if (a.lastMessageTime == null) return 1;
            if (b.lastMessageTime == null) return -1;
            return b.lastMessageTime!.compareTo(a.lastMessageTime!);
          });
          
          notifyListeners();
          
          // Save to local database for offline access
          for (Conversation conversation in conversations) {
            await _databaseService.insertOrUpdateConversation(conversation);
          }
        },
        onError: (error) {
          print('❌ ConversationProvider: Real-time conversations listener error: $error');
        },
      );

      // Also sync once manually to ensure we have the latest data
      await _syncConversationsFromFirebase(currentUserId);
      
    } catch (e) {
      print('❌ ConversationProvider: Error loading conversations: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sync conversations from Firebase
  Future<void> _syncConversationsFromFirebase(String currentUserId) async {
    try {
      List<Conversation> remoteConversations = await _firebaseService.getConversationsForUser(currentUserId);
      print('📱 ConversationProvider: Synced ${remoteConversations.length} conversations from Firebase');

      // Update local database
      for (Conversation conversation in remoteConversations) {
        await _databaseService.insertOrUpdateConversation(conversation);
      }

      // Reload from local database to ensure consistency
      _conversations = await _databaseService.getConversationsForUser(currentUserId);
      notifyListeners();
      
    } catch (e) {
      print('❌ ConversationProvider: Error syncing conversations from Firebase: $e');
    }
  }

  // Start or get existing conversation with another user
  Future<Conversation?> startConversation(User currentUser, User otherUser) async {
    try {
      print('💬 ConversationProvider: Starting conversation between ${currentUser.username} and ${otherUser.username}');
      
      String conversationId = Conversation.generateConversationId(currentUser.id, otherUser.id);
      
      // Check if conversation already exists locally
      Conversation? existingConversation;
      try {
        existingConversation = _conversations.firstWhere(
          (c) => c.id == conversationId,
        );
      } catch (e) {
        existingConversation = null;
      }

      // If found locally, return it
      if (existingConversation != null) {
        print('💬 ConversationProvider: Found existing conversation locally: $conversationId');
        return existingConversation;
      }

      // Check if conversation exists in Firebase
      Conversation? remoteConversation = await _firebaseService.getConversationById(conversationId);
      if (remoteConversation != null) {
        print('💬 ConversationProvider: Found existing conversation in Firebase: $conversationId');
        
        // Add to local list and save to local database
        _conversations.add(remoteConversation);
        await _databaseService.insertOrUpdateConversation(remoteConversation);
        notifyListeners();
        
        return remoteConversation;
      }

      // Create new conversation if it doesn't exist anywhere

      // Create new conversation
      Conversation newConversation = Conversation(
        id: conversationId,
        user1Id: currentUser.id,
        user2Id: otherUser.id,
        user1Name: currentUser.username,
        user2Name: otherUser.username,
        user1ProfileImage: currentUser.profileImage,
        user2ProfileImage: otherUser.profileImage,
        createdAt: DateTime.now(),
      );

      // Save to Firebase first
      await _firebaseService.createConversation(newConversation);
      
      // Save to local database
      await _databaseService.insertOrUpdateConversation(newConversation);

      // Add to local list and notify immediately
      _conversations.add(newConversation);
      notifyListeners();

      print('✅ ConversationProvider: Created new conversation: $conversationId');
      
      // Force reload conversations for both users to ensure sync
      await loadConversations(currentUser.id);
      
      return newConversation;
      
    } catch (e) {
      print('❌ ConversationProvider: Error starting conversation: $e');
      return null;
    }
  }

  // Force refresh conversations
  Future<void> refreshConversations(String currentUserId) async {
    try {
      print('🔄 ConversationProvider: Force refreshing conversations for user: $currentUserId');
      
      // Reload from Firebase
      await _syncConversationsFromFirebase(currentUserId);
      
      // Also trigger the listener to update
      notifyListeners();
      
    } catch (e) {
      print('❌ ConversationProvider: Error refreshing conversations: $e');
    }
  }

  // Load messages for a specific conversation with real-time updates
  Future<void> loadMessages(String conversationId) async {
    try {
      print('💬 ConversationProvider: Loading messages for conversation: $conversationId');
      
      // Cancel previous subscription if exists
      await _messagesSubscription?.cancel();
      
      _currentConversationId = conversationId;
      _isLoading = true;
      notifyListeners();

      // Load from local database first for immediate display
      List<Message> localMessages = await _databaseService.getMessagesForConversation(conversationId);
      print('💬 ConversationProvider: Loaded ${localMessages.length} messages from local DB');
      
      _currentMessages = localMessages;
      _isLoading = false;
      notifyListeners();

      // Set up real-time listener for Firebase updates
      _messagesSubscription = _firebaseService.listenToMessages(conversationId).listen(
        (List<Message> messages) async {
          print('🔥 ConversationProvider: Real-time update received: ${messages.length} messages');
          
          // Update current messages
          _currentMessages = messages;
          notifyListeners();
          
          // Save to local database for offline access
          for (Message message in messages) {
            await _databaseService.insertMessage(message);
          }
          
          // Update conversation's last message if this is the current conversation
          if (messages.isNotEmpty && _currentConversationId == conversationId) {
            final lastMessage = messages.last;
            await _updateConversationLastMessage(
              conversationId, 
              lastMessage.content, 
              lastMessage.timestamp
            );
          }
        },
        onError: (error) {
          print('❌ ConversationProvider: Real-time listener error: $error');
        },
      );
      
    } catch (e) {
      print('❌ ConversationProvider: Error loading messages: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // Send a message
  Future<void> sendMessage(String conversationId, String senderId, String senderName, String content, {MessageType type = MessageType.text}) async {
    try {
      print('📤 ConversationProvider: Sending message to conversation: $conversationId');
      
      Message message = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        conversationId: conversationId,
        senderId: senderId,
        senderName: senderName,
        content: content,
        type: type,
        timestamp: DateTime.now(),
      );

      // Add to local list immediately for instant UI update
      _currentMessages.add(message);
      notifyListeners();

      // Save to Firebase and local database
      await _firebaseService.sendMessage(message);
      await _databaseService.insertMessage(message);

      // Update conversation's last message
      await _updateConversationLastMessage(conversationId, content, DateTime.now());

      print('✅ ConversationProvider: Message sent successfully');
      
    } catch (e) {
      print('❌ ConversationProvider: Error sending message: $e');
      // Remove from local list if failed
      _currentMessages.removeWhere((m) => m.content == content && m.senderId == senderId);
      notifyListeners();
    }
  }

  // Update conversation's last message
  Future<void> _updateConversationLastMessage(String conversationId, String lastMessage, DateTime timestamp) async {
    try {
      // Find and update the conversation
      int index = _conversations.indexWhere((c) => c.id == conversationId);
      if (index != -1) {
        _conversations[index] = _conversations[index].copyWith(
          lastMessage: lastMessage,
          lastMessageTime: timestamp,
        );
        
        // Sort conversations by last message time
        _conversations.sort((a, b) {
          if (a.lastMessageTime == null && b.lastMessageTime == null) return 0;
          if (a.lastMessageTime == null) return 1;
          if (b.lastMessageTime == null) return -1;
          return b.lastMessageTime!.compareTo(a.lastMessageTime!);
        });
        
        notifyListeners();

        // Update in databases
        await _firebaseService.updateConversation(_conversations[index]);
        await _databaseService.insertOrUpdateConversation(_conversations[index]);
      }
    } catch (e) {
      print('❌ ConversationProvider: Error updating conversation last message: $e');
    }
  }

  // Clear current conversation and stop real-time listening
  void clearCurrentConversation() {
    _messagesSubscription?.cancel();
    _messagesSubscription = null;
    _currentConversationId = null;
    _currentMessages.clear();
    notifyListeners();
  }

  // Stop listening to conversations
  void stopConversationsListener() {
    _conversationsSubscription?.cancel();
    _conversationsSubscription = null;
  }

  // Dispose method to clean up resources
  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _conversationsSubscription?.cancel();
    super.dispose();
  }

  // Get conversation by ID
  Conversation? getConversationById(String conversationId) {
    try {
      return _conversations.firstWhere((c) => c.id == conversationId);
    } catch (e) {
      return null;
    }
  }
}
