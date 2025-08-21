import 'package:sqflite/sqflite.dart';
import '../models/contact.dart';

class ContactService {
  static const String _tableName = 'contacts';

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        username TEXT NOT NULL,
        profileImage TEXT,
        addedAt TEXT NOT NULL,
        isBlocked INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  static Future<void> addContact(Database db, Contact contact) async {
    await db.insert(
      _tableName,
      contact.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Contact>> getContacts(Database db) async {
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      orderBy: 'username ASC',
    );

    return List.generate(maps.length, (i) {
      return Contact.fromJson(maps[i]);
    });
  }

  static Future<Contact?> getContactByUserId(Database db, String userId) async {
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'userId = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    return Contact.fromJson(maps.first);
  }

  static Future<void> updateContact(Database db, Contact contact) async {
    await db.update(
      _tableName,
      contact.toJson(),
      where: 'id = ?',
      whereArgs: [contact.id],
    );
  }

  static Future<void> deleteContact(Database db, String contactId) async {
    await db.delete(_tableName, where: 'id = ?', whereArgs: [contactId]);
  }

  static Future<void> blockContact(
    Database db,
    String contactId,
    bool isBlocked,
  ) async {
    await db.update(
      _tableName,
      {'isBlocked': isBlocked ? 1 : 0},
      where: 'id = ?',
      whereArgs: [contactId],
    );
  }

  static Future<bool> isContactExists(Database db, String userId) async {
    final contact = await getContactByUserId(db, userId);
    return contact != null;
  }
}
