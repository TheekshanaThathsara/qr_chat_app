import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:instant_chat_app/models/chat_room.dart';
import 'package:instant_chat_app/models/message.dart';
import 'package:instant_chat_app/models/user.dart';

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
  static const int _databaseVersion = 1;

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
        chat_room_id TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        sender_name TEXT NOT NULL,
        content TEXT NOT NULL,
        type INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        is_read INTEGER NOT NULL DEFAULT 0,
        image_url TEXT,
        file_name TEXT,
        FOREIGN KEY (chat_room_id) REFERENCES chat_rooms (id)
      )
    ''');

    // Create users table
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        username TEXT NOT NULL,
        profile_image TEXT,
        last_seen TEXT NOT NULL,
        is_online INTEGER NOT NULL DEFAULT 0
      )
    ''');
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
      'participants': chatRoom.participants
          .map((u) => u.toJson())
          .toList()
          .toString(),
      'last_message': chatRoom.lastMessage?.toJson().toString(),
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
      return ChatRoom.fromJson({
        'id': maps[i]['id'],
        'name': maps[i]['name'],
        'description': maps[i]['description'],
        'participants': [], // Will be populated separately
        'lastMessage': maps[i]['last_message'],
        'createdAt': maps[i]['created_at'],
        'createdBy': maps[i]['created_by'],
        'isPrivate': maps[i]['is_private'] == 1,
        'qrCode': maps[i]['qr_code'],
      });
    });
  }

  Future<ChatRoom?> getChatRoom(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'chat_rooms',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return ChatRoom.fromJson({
        'id': maps[0]['id'],
        'name': maps[0]['name'],
        'description': maps[0]['description'],
        'participants': [], // Will be populated separately
        'lastMessage': maps[0]['last_message'],
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
      return ChatRoom.fromJson({
        'id': maps[0]['id'],
        'name': maps[0]['name'],
        'description': maps[0]['description'],
        'participants': [], // Will be populated separately
        'lastMessage': maps[0]['last_message'],
        'createdAt': maps[0]['created_at'],
        'createdBy': maps[0]['created_by'],
        'isPrivate': maps[0]['is_private'] == 1,
        'qrCode': maps[0]['qr_code'],
      });
    }
    return null;
  }

  // Message operations
  Future<void> saveMessage(Message message) async {
    final db = await database;
    await db.insert('messages', {
      'id': message.id,
      'chat_room_id': message.chatRoomId,
      'sender_id': message.senderId,
      'sender_name': message.senderName,
      'content': message.content,
      'type': message.type.index,
      'timestamp': message.timestamp.toIso8601String(),
      'is_read': message.isRead ? 1 : 0,
      'image_url': message.imageUrl,
      'file_name': message.fileName,
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

  // User operations
  Future<void> saveUser(User user) async {
    final db = await database;
    await db.insert('users', {
      'id': user.id,
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
}
