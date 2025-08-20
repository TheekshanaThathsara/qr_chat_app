import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:instant_chat_app/models/message.dart';
import 'package:instant_chat_app/models/user.dart';
import 'package:flutter/foundation.dart';

class SocketService {
  io.Socket? _socket;
  User? _currentUser;
  bool _isConnected = false;

  // Callbacks
  Function(Message)? onMessageReceived;
  Function(String, String)? onUserJoined;
  Function(String, String)? onUserLeft;
  Function(bool)? onConnectionChanged;

  bool get isConnected => _isConnected;

  Future<void> connect(User user) async {
    try {
      _currentUser = user;

      // For demo purposes, we'll use a local server
      // In production, replace with your actual server URL
      _socket = io.io('http://localhost:3000', <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
      });

      _socket!.connect();

      _socket!.onConnect((_) {
        debugPrint('Connected to server');
        _isConnected = true;
        onConnectionChanged?.call(true);

        // Join user to their own room for direct messages
        _socket!.emit('join_user_room', user.id);
      });

      _socket!.onDisconnect((_) {
        debugPrint('Disconnected from server');
        _isConnected = false;
        onConnectionChanged?.call(false);
      });

      _socket!.on('message_received', (data) {
        try {
          final message = Message.fromJson(data);
          onMessageReceived?.call(message);
        } catch (e) {
          debugPrint('Error parsing received message: $e');
        }
      });

      _socket!.on('user_joined', (data) {
        final userId = data['userId'];
        final chatRoomId = data['chatRoomId'];
        onUserJoined?.call(userId, chatRoomId);
      });

      _socket!.on('user_left', (data) {
        final userId = data['userId'];
        final chatRoomId = data['chatRoomId'];
        onUserLeft?.call(userId, chatRoomId);
      });

      _socket!.onConnectError((data) {
        debugPrint('Connection error: $data');
        _isConnected = false;
        onConnectionChanged?.call(false);
      });
    } catch (e) {
      debugPrint('Error connecting to server: $e');
      _isConnected = false;
      onConnectionChanged?.call(false);
    }
  }

  void sendMessage(Message message) {
    if (_socket != null && _isConnected) {
      _socket!.emit('send_message', message.toJson());
    } else {
      debugPrint('Socket not connected, cannot send message');
    }
  }

  void joinRoom(String chatRoomId) {
    if (_socket != null && _isConnected && _currentUser != null) {
      _socket!.emit('join_room', {
        'chatRoomId': chatRoomId,
        'userId': _currentUser!.id,
        'username': _currentUser!.username,
      });
    }
  }

  void leaveRoom(String chatRoomId) {
    if (_socket != null && _isConnected && _currentUser != null) {
      _socket!.emit('leave_room', {
        'chatRoomId': chatRoomId,
        'userId': _currentUser!.id,
      });
    }
  }

  void updateUserStatus(bool isOnline) {
    if (_socket != null && _isConnected && _currentUser != null) {
      _socket!.emit('user_status_update', {
        'userId': _currentUser!.id,
        'isOnline': isOnline,
        'lastSeen': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> disconnect() async {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
    _isConnected = false;
    _currentUser = null;
  }
}

// Simple HTTP-based fallback service for when WebSocket is not available
class HttpChatService {
  static const String baseUrl = 'http://localhost:3000/api';

  Future<void> sendMessage(Message message) async {
    // Implementation for HTTP-based message sending
    // This would be used as a fallback when WebSocket is not available
    debugPrint('HTTP fallback: Sending message ${message.id}');
  }

  Future<List<Message>> getMessages(String chatRoomId) async {
    // Implementation for HTTP-based message retrieval
    debugPrint('HTTP fallback: Getting messages for room $chatRoomId');
    return [];
  }
}
