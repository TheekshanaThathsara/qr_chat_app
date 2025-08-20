import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class StorageService {
  static const String _currentUserKey = 'current_user';
  static const String _chatRoomsKey = 'chat_rooms';
  static const String _settingsKey = 'app_settings';

  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_currentUserKey);
      if (userJson != null) {
        return json.decode(userJson);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get current user: $e');
    }
  }

  Future<void> saveCurrentUser(Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentUserKey, json.encode(userData));
    } catch (e) {
      throw Exception('Failed to save current user: $e');
    }
  }

  Future<void> clearCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_currentUserKey);
    } catch (e) {
      throw Exception('Failed to clear current user: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getChatRooms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final chatRoomsJson = prefs.getString(_chatRoomsKey);
      if (chatRoomsJson != null) {
        final List<dynamic> chatRoomsList = json.decode(chatRoomsJson);
        return chatRoomsList.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to get chat rooms: $e');
    }
  }

  Future<void> saveChatRooms(List<Map<String, dynamic>> chatRooms) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chatRoomsKey, json.encode(chatRooms));
    } catch (e) {
      throw Exception('Failed to save chat rooms: $e');
    }
  }

  Future<Map<String, dynamic>> getAppSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_settingsKey);
      if (settingsJson != null) {
        return json.decode(settingsJson);
      }
      return {
        'theme': 'system',
        'notifications': true,
        'soundEnabled': true,
      };
    } catch (e) {
      throw Exception('Failed to get app settings: $e');
    }
  }

  Future<void> saveAppSettings(Map<String, dynamic> settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_settingsKey, json.encode(settings));
    } catch (e) {
      throw Exception('Failed to save app settings: $e');
    }
  }

  Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      throw Exception('Failed to clear all data: $e');
    }
  }
}
