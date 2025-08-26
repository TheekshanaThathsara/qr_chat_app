import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseTest {
  static Future<void> testFirebaseConnection() async {
    try {
      debugPrint('🔥 FIREBASE TEST: Starting comprehensive test...');

      // Test Firebase Core
      final app = Firebase.app();
      debugPrint('🔥 FIREBASE TEST: App name: ${app.name}');
      debugPrint('🔥 FIREBASE TEST: Project ID: ${app.options.projectId}');
      debugPrint(
        '🔥 FIREBASE TEST: API Key: ${app.options.apiKey.substring(0, 10)}...',
      );

      // Test Firebase Auth instance
      final auth = FirebaseAuth.instance;
      debugPrint('🔥 FIREBASE TEST: Auth instance created');
      debugPrint(
        '🔥 FIREBASE TEST: Current user: ${auth.currentUser?.uid ?? 'null'}',
      );

      // Test Firestore instance
      try {
        final firestore = FirebaseFirestore.instance;
        debugPrint('🔥 FIREBASE TEST: Firestore instance created');

        // Try a simple Firestore operation
        await firestore
            .collection('test')
            .limit(1)
            .get()
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                debugPrint('🔥 FIREBASE TEST: Firestore timeout');
                throw 'Firestore connection timed out';
              },
            );
        debugPrint('🔥 FIREBASE TEST: ✅ Firestore connection successful');
      } catch (e) {
        debugPrint('🔥 FIREBASE TEST: ❌ Firestore test failed: $e');
      }

      // Test Authentication
      await testAuthentication();

      debugPrint('🔥 FIREBASE TEST: All tests completed!');
    } catch (e) {
      debugPrint('🔥 FIREBASE TEST: ❌ Overall test failed: $e');
    }
  }

  static Future<void> testAuthentication() async {
    try {
      debugPrint('🔥 AUTH TEST: Testing authentication...');

      final auth = FirebaseAuth.instance;

      // Try anonymous sign in first (simpler test)
      debugPrint('🔥 AUTH TEST: Attempting anonymous sign in...');
      final result = await auth.signInAnonymously().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('🔥 AUTH TEST: Anonymous sign in timed out');
          throw 'Authentication test timed out';
        },
      );

      debugPrint('🔥 AUTH TEST: ✅ Anonymous sign in successful!');
      debugPrint('🔥 AUTH TEST: User ID: ${result.user?.uid}');

      // Sign out the test user
      await auth.signOut();
      debugPrint('🔥 AUTH TEST: ✅ Test user signed out');
    } catch (e) {
      debugPrint('🔥 AUTH TEST: ❌ Authentication test failed: $e');
    }
  }
}
