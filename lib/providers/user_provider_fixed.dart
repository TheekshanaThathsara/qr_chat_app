import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:instant_chat_app/models/user.dart';
import 'package:instant_chat_app/services/storage_service.dart';
import 'package:instant_chat_app/services/firebase_auth_service.dart';
import 'dart:async';

class UserProvider with ChangeNotifier {
  User? _currentUser;
  final StorageService _storageService = StorageService();
  final FirebaseAuthService _authService = FirebaseAuthService();
  StreamSubscription<firebase_auth.User?>? _authSubscription;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  // Callbacks
  Function(User)? onUserReady;
  Function()? onUserLogout;

  // Initialize user and listen to auth state
  Future<void> initializeUser() async {
    try {
      // Listen to Firebase auth state changes
      _authSubscription = _authService.authStateChanges.listen((
        firebaseUser,
      ) async {
        if (firebaseUser != null) {
          // User is signed in
          final appUser = await _authService.getCurrentAppUser();
          if (appUser != null) {
            _currentUser = appUser;
            await _storageService.saveCurrentUser(appUser.toJson());
            notifyListeners();

            if (onUserReady != null) {
              onUserReady!(appUser);
            }
          }
        } else {
          // User is signed out
          _currentUser = null;
          await _storageService.clearCurrentUser();
          notifyListeners();

          if (onUserLogout != null) {
            onUserLogout!();
          }
        }
      });

      // Check if user is already signed in
      if (_authService.isSignedIn) {
        final appUser = await _authService.getCurrentAppUser();
        if (appUser != null) {
          _currentUser = appUser;
          notifyListeners();

          if (onUserReady != null) {
            onUserReady!(appUser);
          }
        }
      }
    } catch (e) {
      debugPrint('Error initializing user: $e');
    }
  }

  // Sign up with email and password
  Future<void> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      final user = await _authService.signUpWithEmailAndPassword(
        email: email,
        password: password,
        username: username,
      );

      if (user != null) {
        _currentUser = user;
        await _storageService.saveCurrentUser(user.toJson());
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error signing up: $e');
      rethrow;
    }
  }

  // Sign in with email and password
  Future<void> signIn({required String email, required String password}) async {
    try {
      final user = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (user != null) {
        _currentUser = user;
        await _storageService.saveCurrentUser(user.toJson());
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error signing in: $e');
      rethrow;
    }
  }

  // Sign in anonymously
  Future<void> signInAnonymously({String? username}) async {
    try {
      final user = await _authService.signInAnonymously(username: username);

      if (user != null) {
        _currentUser = user;
        await _storageService.saveCurrentUser(user.toJson());
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error signing in anonymously: $e');
      rethrow;
    }
  }

  // Legacy method for backward compatibility
  Future<void> createUser(
    String username, {
    required String email,
    required String password,
  }) async {
    await signUp(email: email, password: password, username: username);
  }

  // Legacy method for backward compatibility
  Future<void> loginUser({
    required String email,
    required String password,
  }) async {
    await signIn(email: email, password: password);
  }

  Future<void> updateUser({
    String? username,
    String? profileImage,
    bool? isOnline,
  }) async {
    if (_currentUser == null) return;

    try {
      // Update via Firebase Auth Service
      await _authService.updateUserProfile(
        username: username,
        profileImageUrl: profileImage,
      );

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

  Future<void> logout() async {
    // Disconnect chat before logging out
    if (onUserLogout != null) {
      try {
        onUserLogout!();
      } catch (e) {
        debugPrint('Error during onUserLogout callback: $e');
      }
    }

    // Attempt to sign out but don't let a failing sign-out block clearing local state
    try {
      await _authService.signOut().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('Timeout while signing out from auth service');
          throw 'Sign out timed out';
        },
      );
    } catch (e) {
      // Log and continue: ensure local state is cleared so UI can navigate away
      debugPrint('Error during authService.signOut (ignored): $e');
    }

    try {
      await _storageService.clearCurrentUser();
    } catch (e) {
      debugPrint('Error clearing local storage during logout: $e');
    }

    _currentUser = null;
    notifyListeners();
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

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
