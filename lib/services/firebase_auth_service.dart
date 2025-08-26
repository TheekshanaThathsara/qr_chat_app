import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:instant_chat_app/models/user.dart' as app_user;
import 'package:instant_chat_app/services/firebase_service.dart';
import 'package:instant_chat_app/services/database_service.dart';
import 'dart:async';

class FirebaseAuthService {
  static final FirebaseAuthService _instance = FirebaseAuthService._internal();
  factory FirebaseAuthService() => _instance;
  FirebaseAuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseService _firebaseService = FirebaseService();
  final DatabaseService _databaseService = DatabaseService();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up with email and password
  Future<app_user.User?> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      debugPrint('🔥 Starting sign up process...');
      debugPrint('🔥 Email: $email');
      debugPrint('🔥 Username: $username');
      debugPrint(
        '🔥 Firebase initialized: ${_auth.app.isAutomaticDataCollectionEnabled}',
      );

      // Add a timeout to prevent hanging
      final UserCredential result = await _auth
          .createUserWithEmailAndPassword(email: email, password: password)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              debugPrint(
                '🔥 TIMEOUT: Sign up operation timed out after 30 seconds',
              );
              throw 'Sign up operation timed out. Please check your internet connection and try again.';
            },
          );

      debugPrint('🔥 Firebase Auth SUCCESS! User ID: ${result.user?.uid}');
      debugPrint('🔥 Firebase User Email: ${result.user?.email}');

      final User? firebaseUser = result.user;
      if (firebaseUser != null) {
        debugPrint('🔥 Updating display name to: $username');

        // Update display name with timeout
        await firebaseUser
            .updateDisplayName(username)
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                debugPrint('🔥 TIMEOUT: Display name update timed out');
                throw 'Failed to update display name';
              },
            );

        debugPrint('🔥 Display name updated successfully');

        // Create app user
        final appUser = app_user.User(
          id: firebaseUser.uid,
          username: username,
          email: email,
          profileImage: firebaseUser.photoURL,
          lastSeen: DateTime.now(),
          isOnline: true,
        );

        debugPrint('🔥 Created app user object');
        debugPrint('🔥 App User ID: ${appUser.id}');
        debugPrint('🔥 App User Username: ${appUser.username}');
        debugPrint('🔥 App User Email: ${appUser.email}');

        // Save to SQLite first (faster)
        debugPrint('🔥 Saving user to SQLite...');
        await _databaseService
            .saveUser(appUser)
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                debugPrint('🔥 TIMEOUT: SQLite save timed out');
                throw 'Failed to save user locally';
              },
            );
        debugPrint('🔥 User saved to SQLite successfully');

        // Save to Firebase with retry
        debugPrint('🔥 Saving user to Firebase...');
        try {
          await _firebaseService
              .saveUserToFirebase(appUser)
              .timeout(
                const Duration(seconds: 15),
                onTimeout: () {
                  debugPrint('🔥 TIMEOUT: Firebase save timed out');
                  throw 'Failed to save user to Firebase';
                },
              );
          debugPrint('🔥 User saved to Firebase successfully');
        } catch (e) {
          debugPrint(
            '🔥 Warning: Failed to save to Firebase, but user was created: $e',
          );
          // Don't fail the whole process if Firebase save fails
        }

        debugPrint('🔥 Sign up process completed successfully!');
        return appUser;
      } else {
        debugPrint('🔥 ERROR: Firebase user is null after successful creation');
        throw 'Failed to create user account';
      }
    } on TimeoutException catch (e) {
      debugPrint('🔥 Timeout Exception: $e');
      throw 'The operation timed out. Please check your internet connection and try again.';
    } on FirebaseAuthException catch (e) {
      debugPrint('🔥 Firebase Auth Exception caught!');
      debugPrint('🔥 Error Code: ${e.code}');
      debugPrint('🔥 Error Message: ${e.message}');
      debugPrint('🔥 Error Details: ${e.toString()}');

      switch (e.code) {
        case 'weak-password':
          throw 'The password provided is too weak.';
        case 'email-already-in-use':
          throw 'The account already exists for that email.';
        case 'invalid-email':
          throw 'The email address is not valid.';
        case 'operation-not-allowed':
          throw 'Email/password sign up is not enabled. Please enable it in Firebase Console.';
        case 'api-key-not-valid':
          throw 'Firebase API key is not valid. Please check your Firebase configuration.';
        case 'network-request-failed':
          throw 'Network error. Please check your internet connection and try again.';
        case 'too-many-requests':
          throw 'Too many requests. Please try again later.';
        default:
          throw 'Sign up failed: ${e.message ?? 'Unknown error'}';
      }
    } catch (e) {
      debugPrint('🔥 Unexpected error during sign up: $e');
      debugPrint('🔥 Error type: ${e.runtimeType}');
      throw 'Sign up failed: $e';
    }
  }

  // Sign in with email and password
  Future<app_user.User?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('🔥 Attempting to sign in with email: $email');

      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      debugPrint(
        '🔥 Sign in successful, Firebase User ID: ${result.user?.uid}',
      );

      final User? firebaseUser = result.user;
      if (firebaseUser != null) {
        // Get or create app user
        app_user.User? appUser = await _databaseService.getUser(
          firebaseUser.uid,
        );

        if (appUser == null) {
          // Create new app user if not exists
          appUser = app_user.User(
            id: firebaseUser.uid,
            username: firebaseUser.displayName ?? 'User',
            email: firebaseUser.email ?? '',
            profileImage: firebaseUser.photoURL,
            lastSeen: DateTime.now(),
            isOnline: true,
          );
          try {
            await _databaseService.saveUser(appUser);
          } catch (e) {
            debugPrint(
              'Warning: failed to save appUser locally on sign in: $e',
            );
          }
        } else {
          // Update last seen and online status
          appUser = appUser.copyWith(lastSeen: DateTime.now(), isOnline: true);
          try {
            await _databaseService.saveUser(appUser);
          } catch (e) {
            debugPrint(
              'Warning: failed to update appUser locally on sign in: $e',
            );
          }
        }

        // Update Firebase user data (best-effort)
        try {
          await _firebaseService.saveUserToFirebase(appUser);
        } catch (e) {
          debugPrint('Warning: failed to save user to Firebase on sign in: $e');
        }

        return appUser;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('🔥 Firebase Auth Exception: ${e.code} - ${e.message}');
      switch (e.code) {
        case 'user-not-found':
          throw 'No user found for that email.';
        case 'wrong-password':
          throw 'Wrong password provided.';
        case 'invalid-email':
          throw 'The email address is not valid.';
        case 'user-disabled':
          throw 'This user account has been disabled.';
        case 'too-many-requests':
          throw 'Too many failed login attempts. Please try again later.';
        case 'api-key-not-valid':
          throw 'Firebase API key is not valid. Please check your Firebase configuration.';
        default:
          throw 'Sign in failed: ${e.message}';
      }
    } catch (e) {
      debugPrint('🔥 Unexpected error signing in: $e');
      rethrow;
    }
  }

  // Sign in anonymously (for quick access)
  Future<app_user.User?> signInAnonymously({String? username}) async {
    try {
      final UserCredential result = await _auth.signInAnonymously();
      final User? firebaseUser = result.user;

      if (firebaseUser != null) {
        final appUser = app_user.User(
          id: firebaseUser.uid,
          username: username ?? 'Anonymous User',
          email: '', // Anonymous users don't have email
          profileImage: null,
          lastSeen: DateTime.now(),
          isOnline: true,
        );

        // Save to both Firebase and SQLite
        await _firebaseService.saveUserToFirebase(appUser);
        await _databaseService.saveUser(appUser);

        return appUser;
      }
      return null;
    } catch (e) {
      debugPrint('Error signing in anonymously: $e');
      rethrow;
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      debugPrint('Error resetting password: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    // We'll try to update remote/local state but always attempt Firebase signOut in finally
    Exception? lastError;
    try {
      // Update user offline status before signing out
      final user = currentUser;
      if (user != null) {
        final appUser = await _databaseService
            .getUser(user.uid)
            .timeout(
              const Duration(seconds: 8),
              onTimeout: () {
                debugPrint('Timeout while getting local user before signOut');
                throw Exception('Timeout getting local user');
              },
            );
        if (appUser != null) {
          final updatedUser = appUser.copyWith(
            lastSeen: DateTime.now(),
            isOnline: false,
          );

          try {
            await _firebaseService
                .saveUserToFirebase(updatedUser)
                .timeout(const Duration(seconds: 8));
          } catch (e) {
            debugPrint(
              'Warning: Failed to save user to Firebase during signOut: $e',
            );
            lastError = Exception('Firebase save error: $e');
          }

          try {
            await _databaseService
                .saveUser(updatedUser)
                .timeout(const Duration(seconds: 6));
          } catch (e) {
            debugPrint(
              'Warning: Failed to save user locally during signOut: $e',
            );
            lastError = Exception('Local save error: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Non-fatal error preparing signOut updates: $e');
      lastError = Exception('Preparation error: $e');
    } finally {
      try {
        // Ensure auth signOut is attempted and completes within a reasonable time
        await _auth.signOut().timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint('Error calling FirebaseAuth.signOut(): $e');
        if (lastError == null) {
          lastError = Exception('Auth signOut error: $e');
        }
      }

      if (lastError != null) {
        // Surface a non-fatal exception to caller while ensuring signOut was attempted
        // Caller (UserProvider.logout) will ignore these errors but they are logged here
        debugPrint('signOut completed with warnings: ${lastError.toString()}');
      }
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    String? username,
    String? profileImageUrl,
  }) async {
    try {
      final user = currentUser;
      if (user != null) {
        // Update Firebase Auth profile
        if (username != null) {
          await user.updateDisplayName(username);
        }
        if (profileImageUrl != null) {
          await user.updatePhotoURL(profileImageUrl);
        }

        // Update app user data
        app_user.User? appUser = await _databaseService.getUser(user.uid);
        if (appUser != null) {
          final updatedUser = appUser.copyWith(
            username: username ?? appUser.username,
            profileImage: profileImageUrl ?? appUser.profileImage,
          );
          await _firebaseService.saveUserToFirebase(updatedUser);
          await _databaseService.saveUser(updatedUser);
        }
      }
    } catch (e) {
      debugPrint('Error updating profile: $e');
      rethrow;
    }
  }

  // Get current app user
  Future<app_user.User?> getCurrentAppUser() async {
    final user = currentUser;
    if (user != null) {
      return await _databaseService.getUser(user.uid);
    }
    return null;
  }

  // Check if user is signed in
  bool get isSignedIn => currentUser != null;
}
