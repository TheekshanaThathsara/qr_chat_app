import 'package:flutter/foundation.dart';
import 'package:instant_chat_app/models/user.dart';
import 'package:instant_chat_app/services/storage_service.dart';
import 'package:uuid/uuid.dart';

class UserProvider with ChangeNotifier {
  Future<void> loginUser({required String email, required String password}) async {
    try {
      final userData = await _storageService.getCurrentUser();
      if (userData == null) {
        throw Exception('No user found. Please register first.');
      }
      final user = User.fromJson(userData);
      // NOTE: Password is not stored in User model. For demo, accept any password if email matches.
      if (user.email != email) {
        throw Exception('Email does not match.');
      }
      // If you store password securely, check it here.
      _currentUser = user;
      notifyListeners();
      if (onUserReady != null) {
        onUserReady!(_currentUser!);
      }
    } catch (e) {
      debugPrint('Error logging in: $e');
      rethrow;
    }
  }
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

  Future<void> createUser(String username, {required String email, required String password}) async {
    try {
      final user = User(
        id: _uuid.v4(),
        username: username,
        email: email,
        lastSeen: DateTime.now(),
        isOnline: true,
      );
      // You may want to securely store password elsewhere, not in User model
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

  // Callback to handle navigation after logout
  Function()? onAfterLogout;

  Future<void> logout() async {
    try {
      // Disconnect chat before logging out
      if (onUserLogout != null) {
        onUserLogout!();
      }
      
      await _storageService.clearCurrentUser();
      _currentUser = null;
      notifyListeners();

      // Call navigation callback after logout
      if (onAfterLogout != null) {
        onAfterLogout!();
      }
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

