# Firebase + SQLite Dual Database Setup for InstantChatApp

## Overview
This Flutter chat app uses dual database storage with Firebase Authentication:
- **Firebase Firestore**: Real-time messaging and cloud sync
- **Firebase Auth**: User authentication (email/password, anonymous)
- **SQLite**: Offline message storage and instant access

## Your Firebase Project Details
- **Project ID**: `instantchatapp-891b2`
- **Console URL**: https://console.firebase.google.com/project/instantchatapp-891b2

## Setup Instructions

### 1. Complete Firebase Configuration

#### Step 1: Download Configuration Files
1. Go to your Firebase Console: https://console.firebase.google.com/project/instantchatapp-891b2/settings/general
2. Download configuration files:
   - **Android**: `google-services.json` → Place in `android/app/`
   - **iOS**: `GoogleService-Info.plist` → Place in `ios/Runner/`
   - **Web**: Copy the config and update `lib/firebase_options.dart`

#### Step 2: Update firebase_options.dart
Replace the placeholder values in `lib/firebase_options.dart` with your actual:
- API Keys
- App IDs  
- Sender ID

You can find these values in:
- Firebase Console → Project Settings → General → Your apps

### 2. Enable Authentication Methods

Go to https://console.firebase.google.com/project/instantchatapp-891b2/authentication/providers

Enable these sign-in methods:
- ✅ **Email/Password** - For registered users
- ✅ **Anonymous** - For guest users

### 3. Configure Firestore Database

Go to https://console.firebase.google.com/project/instantchatapp-891b2/firestore

1. **Create Database** (if not created)
   - Start in test mode for development
   - Choose your preferred location

2. **Security Rules** (for development):
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /{document=**} {
         allow read, write: if request.auth != null;
       }
     }
   }
   ```

### 4. App Features Implemented

#### Authentication:
- ✅ Email/Password Sign Up & Sign In
- ✅ Anonymous/Guest Access  
- ✅ Auto login on app restart
- ✅ Secure logout

#### Dual Database:
- ✅ **Real-time sync**: Firebase for cloud messages
- ✅ **Offline support**: SQLite for local storage
- ✅ **Smart sync**: Unsynced messages auto-upload when online
- ✅ **Consistent UI**: Always reads from SQLite for performance

#### Message Features:
- ✅ Real-time messaging when online
- ✅ Offline message viewing and sending
- ✅ Message sync across devices
- ✅ QR code room joining
- ✅ Media attachments (images, files)

### 5. How It Works

#### User Flow:
1. **First Time**: Sign up or continue as guest
2. **Returning**: Auto-login if authenticated
3. **Offline**: Full chat functionality from SQLite
4. **Online**: Real-time sync with Firebase

#### Database Flow:
```
Send Message:
SQLite (instant) → Firebase (cloud sync) → Other devices

Receive Message:  
Firebase (real-time) → SQLite (local cache) → UI display

Offline Mode:
SQLite only → Auto-sync when connection returns
```

### 6. Testing Your Setup

1. **Build & Run**: `flutter run`
2. **Test Auth**: Try sign up, sign in, guest mode
3. **Test Chat**: Send messages online/offline
4. **Test Sync**: Use multiple devices with same account

### 7. Security Notes

For production, update Firestore rules:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /messages/{messageId} {
      allow read, write: if request.auth != null;
    }
    match /chat_rooms/{roomId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

Your chat app is now ready with full Firebase integration! 🚀
