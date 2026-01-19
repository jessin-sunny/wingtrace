import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class ChatDatabaseHelper {
  static final ChatDatabaseHelper instance = ChatDatabaseHelper._init();
  static Database? _database;

  ChatDatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('wingtrace_chat.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE chats (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        role TEXT NOT NULL,
        text TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');
  }

  Future<void> insertMessage(String role, String text) async {
    final db = await instance.database;
    await db.insert('chats', {
      'role': role,
      'text': text,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, String>>> getMessages() async {
    final db = await instance.database;
    final result = await db.query('chats', orderBy: 'id ASC');

    return result.map((row) => {
      'role': row['role'] as String,
      'text': row['text'] as String,
    }).toList();
  }

  Future<void> clearHistory() async {
    final db = await instance.database;
    await db.delete('chats');
  }
}