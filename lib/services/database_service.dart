import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'package:instant_chat_app/models/chat_room.dart';
import 'package:instant_chat_app/models/conversation.dart';
import 'package:instant_chat_app/models/message.dart';
import 'package:instant_chat_app/models/user.dart';
import 'package:instant_chat_app/models/contact.dart';
import 'package:instant_chat_app/services/contact_service.dart';

class DatabaseService {
  Future<void> deleteChatRoom(String chatRoomId) async {
    final db = await database;
    await db.delete('chat_rooms', where: 'id = ?', whereArgs: [chatRoomId]);
    await db.delete(
      'messages',
      where: 'chat_room_id = ?',
      whereArgs: [chatRoomId],
    );
  }

  static Database? _database;
  static const String _databaseName = 'instant_chat.db';
  static const int _databaseVersion = 5;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create chat rooms table
    await db.execute('''
      CREATE TABLE chat_rooms (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        participants TEXT NOT NULL,
        last_message TEXT,
        created_at TEXT NOT NULL,
        created_by TEXT NOT NULL,
        is_private INTEGER NOT NULL DEFAULT 0,
        qr_code TEXT
      )
    ''');

    // Create messages table
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        sender_name TEXT NOT NULL,
        content TEXT NOT NULL,
        type INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        is_read INTEGER NOT NULL DEFAULT 0,
        image_url TEXT,
        file_name TEXT,
        synced INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (conversation_id) REFERENCES conversations (id)
      )
    ''');

    // Create conversations table
    await db.execute('''
      CREATE TABLE conversations (
        id TEXT PRIMARY KEY,
        user1_id TEXT NOT NULL,
        user2_id TEXT NOT NULL,
        user1_name TEXT NOT NULL,
        user2_name TEXT NOT NULL,
        user1_profile_image TEXT,
        user2_profile_image TEXT,
        last_message TEXT,
        last_message_time TEXT,
        created_at TEXT NOT NULL,
        unread_counts TEXT
      )
    ''');

    // Create users table (now includes email)
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        username TEXT NOT NULL,
        email TEXT NOT NULL,
        profile_image TEXT,
        last_seen TEXT NOT NULL,
        is_online INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Create contacts table
    await db.execute('''
      CREATE TABLE contacts (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        username TEXT NOT NULL,
        profileImage TEXT,
        addedAt TEXT NOT NULL,
        isBlocked INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add synced column to messages table
      await db.execute(
        'ALTER TABLE messages ADD COLUMN synced INTEGER NOT NULL DEFAULT 0',
      );
    }
    // Version 3: add email column to users table if missing
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE users ADD COLUMN email TEXT DEFAULT ""');
      } catch (e) {
        // If the column already exists or alter failed, log and continue
        // (Some devices may already have this column)
      }
    }
    // Version 4: Add conversations support
    if (oldVersion < 4) {
      try {
        // Create conversations table
        await db.execute('''
          CREATE TABLE conversations (
            id TEXT PRIMARY KEY,
            user1_id TEXT NOT NULL,
            user2_id TEXT NOT NULL,
            user1_name TEXT NOT NULL,
            user2_name TEXT NOT NULL,
            user1_profile_image TEXT,
            user2_profile_image TEXT,
            last_message TEXT,
            last_message_time TEXT,
            created_at TEXT NOT NULL,
            unread_counts TEXT
          )
        ''');
        
        // Update messages table to use conversation_id instead of chat_room_id
        await db.execute('ALTER TABLE messages ADD COLUMN conversation_id TEXT');
        
        // Copy data from chat_room_id to conversation_id for existing records
        await db.execute('UPDATE messages SET conversation_id = chat_room_id WHERE conversation_id IS NULL');
        
      } catch (e) {
        print('Error upgrading database to version 4: $e');
      }
    }

    // Version 5: Fix messages table schema to remove chat_room_id dependency
    if (oldVersion < 5) {
      try {
        print('Upgrading database to version 5: Fixing messages table schema...');
        
        // Create a backup of messages data
        await db.execute('''
          CREATE TABLE messages_backup AS 
          SELECT id, conversation_id, sender_id, sender_name, content, type, timestamp, is_read, image_url, file_name, synced 
          FROM messages 
          WHERE conversation_id IS NOT NULL
        ''');
        
        // Drop the old messages table
        await db.execute('DROP TABLE messages');
        
        // Recreate messages table with correct schema
        await db.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            conversation_id TEXT NOT NULL,
            sender_id TEXT NOT NULL,
            sender_name TEXT NOT NULL,
            content TEXT NOT NULL,
            type INTEGER NOT NULL,
            timestamp TEXT NOT NULL,
            is_read INTEGER NOT NULL DEFAULT 0,
            image_url TEXT,
            file_name TEXT,
            synced INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (conversation_id) REFERENCES conversations (id)
          )
        ''');
        
        // Restore data from backup
        await db.execute('''
          INSERT INTO messages (id, conversation_id, sender_id, sender_name, content, type, timestamp, is_read, image_url, file_name, synced)
          SELECT id, conversation_id, sender_id, sender_name, content, type, timestamp, is_read, image_url, file_name, synced
          FROM messages_backup
        ''');
        
        // Drop the backup table
        await db.execute('DROP TABLE messages_backup');
        
        print('Successfully upgraded database to version 5!');
        
      } catch (e) {
        print('Error upgrading database to version 5: $e');
      }
    }
  }

  Future<void> initializeDatabase() async {
    await database;
  }

  // Chat Room operations
  Future<void> saveChatRoom(ChatRoom chatRoom) async {
    final db = await database;
    await db.insert('chat_rooms', {
      'id': chatRoom.id,
      'name': chatRoom.name,
      'description': chatRoom.description,
      'participants': jsonEncode(
        chatRoom.participants.map((u) => u.toJson()).toList(),
      ),
      'last_message': chatRoom.lastMessage != null
          ? jsonEncode(chatRoom.lastMessage!.toJson())
          : null,
      'created_at': chatRoom.createdAt.toIso8601String(),
      'created_by': chatRoom.createdBy,
      'is_private': chatRoom.isPrivate ? 1 : 0,
      'qr_code': chatRoom.qrCode,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ChatRoom>> getChatRooms() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'chat_rooms',
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) {
      // Parse participants JSON if available
      List<dynamic> participantsJson = [];
      try {
        if (maps[i]['participants'] != null) {
          participantsJson = jsonDecode(maps[i]['participants']);
        }
      } catch (e) {
        // Fallback: leave participants empty
        participantsJson = [];
      }

      // Parse last_message which may be stored as JSON string or as null
      dynamic lastMessageField = maps[i]['last_message'];
      dynamic lastMessageJson;
      try {
        if (lastMessageField == null) {
          lastMessageJson = null;
        } else if (lastMessageField is String) {
          lastMessageJson = jsonDecode(lastMessageField);
        } else if (lastMessageField is Map) {
          lastMessageJson = lastMessageField;
        } else {
          lastMessageJson = null;
        }
      } catch (e) {
        lastMessageJson = null;
      }

      return ChatRoom.fromJson({
        'id': maps[i]['id'],
        'name': maps[i]['name'],
        'description': maps[i]['description'],
        'participants': participantsJson,
        'lastMessage': lastMessageJson,
        'createdAt': maps[i]['created_at'],
        'createdBy': maps[i]['created_by'],
        'isPrivate': maps[i]['is_private'] == 1,
        'qrCode': maps[i]['qr_code'],
      });
    });
  }

  /// Get chat rooms where the specified user is a participant
  Future<List<ChatRoom>> getChatRoomsForUser(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'chat_rooms',
      orderBy: 'created_at DESC',
    );

    List<ChatRoom> userChatRooms = [];

    for (final row in maps) {
      try {
        // Parse participants JSON if available
        List<dynamic> participantsJson = [];
        try {
          if (row['participants'] != null) {
            participantsJson = jsonDecode(row['participants']);
          }
        } catch (e) {
          // Skip malformed participants data
          continue;
        }

        // Check if the user is a participant in this room
        final participantIds = participantsJson
            .map((p) => (p as Map<String, dynamic>)['id']?.toString())
            .whereType<String>()
            .toList();

        if (participantIds.contains(userId)) {
          // Parse last_message which may be stored as JSON string or as null
          dynamic lastMessageField = row['last_message'];
          dynamic lastMessageJson;
          try {
            if (lastMessageField == null) {
              lastMessageJson = null;
            } else if (lastMessageField is String) {
              lastMessageJson = jsonDecode(lastMessageField);
            } else if (lastMessageField is Map) {
              lastMessageJson = lastMessageField;
            } else {
              lastMessageJson = null;
            }
          } catch (e) {
            lastMessageJson = null;
          }

          userChatRooms.add(
            ChatRoom.fromJson({
              'id': row['id'],
              'name': row['name'],
              'description': row['description'],
              'participants': participantsJson,
              'lastMessage': lastMessageJson,
              'createdAt': row['created_at'],
              'createdBy': row['created_by'],
              'isPrivate': row['is_private'] == 1,
              'qrCode': row['qr_code'],
            }),
          );
        }
      } catch (e) {
        // Skip malformed rows
        continue;
      }
    }

    return userChatRooms;
  }

  /// Return raw chat_rooms rows from SQLite for debugging.
  Future<List<Map<String, dynamic>>> getRawChatRooms() async {
    final db = await database;
    return await db.query('chat_rooms', orderBy: 'created_at DESC');
  }

  Future<ChatRoom?> getChatRoom(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'chat_rooms',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      List<dynamic> participantsJson = [];
      try {
        if (maps[0]['participants'] != null) {
          participantsJson = jsonDecode(maps[0]['participants']);
        }
      } catch (e) {
        participantsJson = [];
      }

      dynamic lastMessageField = maps[0]['last_message'];
      dynamic lastMessageJson;
      try {
        if (lastMessageField == null) {
          lastMessageJson = null;
        } else if (lastMessageField is String) {
          lastMessageJson = jsonDecode(lastMessageField);
        } else if (lastMessageField is Map) {
          lastMessageJson = lastMessageField;
        } else {
          lastMessageJson = null;
        }
      } catch (e) {
        lastMessageJson = null;
      }

      return ChatRoom.fromJson({
        'id': maps[0]['id'],
        'name': maps[0]['name'],
        'description': maps[0]['description'],
        'participants': participantsJson,
        'lastMessage': lastMessageJson,
        'createdAt': maps[0]['created_at'],
        'createdBy': maps[0]['created_by'],
        'isPrivate': maps[0]['is_private'] == 1,
        'qrCode': maps[0]['qr_code'],
      });
    }
    return null;
  }

  Future<ChatRoom?> getChatRoomByQrCode(String qrCode) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'chat_rooms',
      where: 'qr_code = ?',
      whereArgs: [qrCode],
    );

    if (maps.isNotEmpty) {
      List<dynamic> participantsJson = [];
      try {
        if (maps[0]['participants'] != null) {
          participantsJson = jsonDecode(maps[0]['participants']);
        }
      } catch (e) {
        participantsJson = [];
      }

      dynamic lastMessageField = maps[0]['last_message'];
      dynamic lastMessageJson;
      try {
        if (lastMessageField == null) {
          lastMessageJson = null;
        } else if (lastMessageField is String) {
          lastMessageJson = jsonDecode(lastMessageField);
        } else if (lastMessageField is Map) {
          lastMessageJson = lastMessageField;
        } else {
          lastMessageJson = null;
        }
      } catch (e) {
        lastMessageJson = null;
      }

      return ChatRoom.fromJson({
        'id': maps[0]['id'],
        'name': maps[0]['name'],
        'description': maps[0]['description'],
        'participants': participantsJson,
        'lastMessage': lastMessageJson,
        'createdAt': maps[0]['created_at'],
        'createdBy': maps[0]['created_by'],
        'isPrivate': maps[0]['is_private'] == 1,
        'qrCode': maps[0]['qr_code'],
      });
    }
    return null;
  }

  // Find existing private chat room containing both userA and userB
  Future<ChatRoom?> getPrivateRoomBetweenUsers(
    String userAId,
    String userBId,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'chat_rooms',
      where: 'is_private = ?',
      whereArgs: [1],
    );

    for (final row in maps) {
      try {
        final participantsJson = row['participants'] != null
            ? jsonDecode(row['participants']) as List<dynamic>
            : <dynamic>[];

        final participantIds = participantsJson
            .map((p) => (p as Map<String, dynamic>)['id']?.toString())
            .whereType<String>()
            .toList();

        // Check if both ids present
        if (participantIds.contains(userAId) &&
            participantIds.contains(userBId)) {
          // Normalize last_message field which may be a JSON string
          dynamic lastMessageField = row['last_message'];
          dynamic lastMessageJson;
          try {
            if (lastMessageField == null) {
              lastMessageJson = null;
            } else if (lastMessageField is String) {
              lastMessageJson = jsonDecode(lastMessageField);
            } else if (lastMessageField is Map) {
              lastMessageJson = lastMessageField;
            } else {
              lastMessageJson = null;
            }
          } catch (e) {
            lastMessageJson = null;
          }

          return ChatRoom.fromJson({
            'id': row['id'],
            'name': row['name'],
            'description': row['description'],
            'participants': participantsJson,
            'lastMessage': lastMessageJson,
            'createdAt': row['created_at'],
            'createdBy': row['created_by'],
            'isPrivate': row['is_private'] == 1,
            'qrCode': row['qr_code'],
          });
        }
      } catch (e) {
        // ignore malformed rows
        continue;
      }
    }

    return null;
  }

  // Message operations
  Future<void> saveMessage(Message message, {bool synced = false}) async {
    final db = await database;
    await db.insert('messages', {
      'id': message.id,
      'conversation_id': message.conversationId,
      'sender_id': message.senderId,
      'sender_name': message.senderName,
      'content': message.content,
      'type': message.type.index,
      'timestamp': message.timestamp.toIso8601String(),
      'is_read': message.isRead ? 1 : 0,
      'image_url': message.imageUrl,
      'file_name': message.fileName,
      'synced': synced ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Message>> getMessages(String chatRoomId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: 'chat_room_id = ?',
      whereArgs: [chatRoomId],
      orderBy: 'timestamp ASC',
    );

    return List.generate(maps.length, (i) {
      return Message.fromJson({
        'id': maps[i]['id'],
        'chatRoomId': maps[i]['chat_room_id'],
        'senderId': maps[i]['sender_id'],
        'senderName': maps[i]['sender_name'],
        'content': maps[i]['content'],
        'type': maps[i]['type'],
        'timestamp': maps[i]['timestamp'],
        'isRead': maps[i]['is_read'] == 1,
        'imageUrl': maps[i]['image_url'],
        'fileName': maps[i]['file_name'],
      });
    });
  }

  Future<void> markMessageAsRead(String messageId) async {
    final db = await database;
    await db.update(
      'messages',
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<void> markMessageAsSynced(String messageId) async {
    final db = await database;
    await db.update(
      'messages',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<List<Message>> getUnsyncedMessages() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'timestamp ASC',
    );

    return List.generate(maps.length, (i) {
      return Message.fromJson({
        'id': maps[i]['id'],
        'chatRoomId': maps[i]['chat_room_id'],
        'senderId': maps[i]['sender_id'],
        'senderName': maps[i]['sender_name'],
        'content': maps[i]['content'],
        'type': maps[i]['type'],
        'timestamp': maps[i]['timestamp'],
        'isRead': maps[i]['is_read'] == 1,
        'imageUrl': maps[i]['image_url'],
        'fileName': maps[i]['file_name'],
      });
    });
  }

  // User operations
  Future<void> saveUser(User user) async {
    final db = await database;
    await db.insert('users', {
      'id': user.id,
      'email': user.email,
      'username': user.username,
      'profile_image': user.profileImage,
      'last_seen': user.lastSeen.toIso8601String(),
      'is_online': user.isOnline ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<User?> getUser(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return User.fromJson({
        'id': maps[0]['id'],
        'email': maps[0]['email'],
        'username': maps[0]['username'],
        'profileImage': maps[0]['profile_image'],
        'lastSeen': maps[0]['last_seen'],
        'isOnline': maps[0]['is_online'] == 1,
      });
    }
    return null;
  }

  Future<void> deleteDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }

  // Contact methods
  Future<void> addContact(Contact contact) async {
    final db = await database;
    await ContactService.addContact(db, contact);
  }

  Future<List<Contact>> getContacts() async {
    final db = await database;
    return await ContactService.getContacts(db);
  }

  Future<Contact?> getContactByUserId(String userId) async {
    final db = await database;
    return await ContactService.getContactByUserId(db, userId);
  }

  Future<void> updateContact(Contact contact) async {
    final db = await database;
    await ContactService.updateContact(db, contact);
  }

  Future<void> deleteContact(String contactId) async {
    final db = await database;
    await ContactService.deleteContact(db, contactId);
  }

  Future<bool> isContactExists(String userId) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> result = await db.rawQuery(
        'SELECT COUNT(*) as c FROM contacts WHERE userId = ?',
        [userId],
      );
      int count = 0;
      if (result.isNotEmpty) {
        final dynamic v = result.first['c'];
        if (v is int) {
          count = v;
        } else if (v is String) {
          count = int.tryParse(v) ?? 0;
        } else if (v is num) {
          count = v.toInt();
        }
      }
      return count > 0;
    } catch (e) {
      // Fallback: delegate to ContactService which currently returns a bool
      try {
        return await ContactService.isContactExists(db, userId);
      } catch (_) {
        return false;
      }
    }
  }

  // Conversation operations
  Future<void> insertOrUpdateConversation(Conversation conversation) async {
    final db = await database;
    await db.insert(
      'conversations',
      {
        'id': conversation.id,
        'user1_id': conversation.user1Id,
        'user2_id': conversation.user2Id,
        'user1_name': conversation.user1Name,
        'user2_name': conversation.user2Name,
        'user1_profile_image': conversation.user1ProfileImage,
        'user2_profile_image': conversation.user2ProfileImage,
        'last_message': conversation.lastMessage,
        'last_message_time': conversation.lastMessageTime?.toIso8601String(),
        'created_at': conversation.createdAt.toIso8601String(),
        'unread_counts': jsonEncode(conversation.unreadCounts),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Conversation>> getConversationsForUser(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'conversations',
      where: 'user1_id = ? OR user2_id = ?',
      whereArgs: [userId, userId],
      orderBy: 'last_message_time DESC, created_at DESC',
    );

    return List.generate(maps.length, (i) {
      return Conversation(
        id: maps[i]['id'],
        user1Id: maps[i]['user1_id'],
        user2Id: maps[i]['user2_id'],
        user1Name: maps[i]['user1_name'],
        user2Name: maps[i]['user2_name'],
        user1ProfileImage: maps[i]['user1_profile_image'],
        user2ProfileImage: maps[i]['user2_profile_image'],
        lastMessage: maps[i]['last_message'],
        lastMessageTime: maps[i]['last_message_time'] != null
            ? DateTime.parse(maps[i]['last_message_time'])
            : null,
        createdAt: DateTime.parse(maps[i]['created_at']),
        unreadCounts: maps[i]['unread_counts'] != null
            ? Map<String, int>.from(jsonDecode(maps[i]['unread_counts']))
            : {},
      );
    });
  }

  Future<List<Message>> getMessagesForConversation(String conversationId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'timestamp ASC',
    );

    return List.generate(maps.length, (i) {
      return Message(
        id: maps[i]['id'],
        conversationId: maps[i]['conversation_id'],
        senderId: maps[i]['sender_id'],
        senderName: maps[i]['sender_name'],
        content: maps[i]['content'],
        type: MessageType.values[maps[i]['type']],
        timestamp: DateTime.parse(maps[i]['timestamp']),
        isRead: maps[i]['is_read'] == 1,
        imageUrl: maps[i]['image_url'],
        fileName: maps[i]['file_name'],
      );
    });
  }

  Future<void> insertMessage(Message message) async {
    final db = await database;
    await db.insert(
      'messages',
      {
        'id': message.id,
        'conversation_id': message.conversationId,
        'sender_id': message.senderId,
        'sender_name': message.senderName,
        'content': message.content,
        'type': message.type.index,
        'timestamp': message.timestamp.toIso8601String(),
        'is_read': message.isRead ? 1 : 0,
        'image_url': message.imageUrl,
        'file_name': message.fileName,
        'synced': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
