import 'package:flutter/foundation.dart';
import 'package:instant_chat_app/models/user.dart';
import 'package:instant_chat_app/services/storage_service.dart';
import 'package:uuid/uuid.dart';

class UserProvider with ChangeNotifier {
  User? _currentUser;
  final StorageService _storageService = StorageService();
  final Uuid _uuid = const Uuid();

  User? get currentUser => _currentUser;

  bool get isLoggedIn => _currentUser != null;

  // Callback to initialize chat when user is ready
  Function(User)? onUserReady;

  Future<void> initializeUser() async {
    try {
      final userData = await _storageService.getCurrentUser();
      if (userData != null) {
        _currentUser = User.fromJson(userData);
        notifyListeners();
        
        // Initialize chat if user is loaded
        if (_currentUser != null && onUserReady != null) {
          onUserReady!(_currentUser!);
        }
      }
    } catch (e) {
      debugPrint('Error initializing user: $e');
    }
  }

  Future<void> createUser(String username) async {
    try {
      final user = User(
        id: _uuid.v4(),
        username: username,
        lastSeen: DateTime.now(),
        isOnline: true,
      );

      await _storageService.saveCurrentUser(user.toJson());
      _currentUser = user;
      notifyListeners();
      
      // Initialize chat when user is created
      if (onUserReady != null) {
        onUserReady!(_currentUser!);
      }
    } catch (e) {
      debugPrint('Error creating user: $e');
      rethrow;
    }
  }

  Future<void> updateUser({
    String? username,
    String? profileImage,
    bool? isOnline,
  }) async {
    if (_currentUser == null) return;

    try {
      final updatedUser = _currentUser!.copyWith(
        username: username,
        profileImage: profileImage,
        isOnline: isOnline,
        lastSeen: DateTime.now(),
      );

      await _storageService.saveCurrentUser(updatedUser.toJson());
      _currentUser = updatedUser;
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating user: $e');
      rethrow;
    }
  }

  // Callback to disconnect chat when user logs out
  Function()? onUserLogout;

  Future<void> logout() async {
    try {
      // Disconnect chat before logging out
      if (onUserLogout != null) {
        onUserLogout!();
      }
      
      await _storageService.clearCurrentUser();
      _currentUser = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Error logging out: $e');
      rethrow;
    }
  }

  void updateOnlineStatus(bool isOnline) {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(
        isOnline: isOnline,
        lastSeen: DateTime.now(),
      );
      notifyListeners();
    }
  }
}
