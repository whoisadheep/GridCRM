import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('crm.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE cached_calls (
        id INTEGER PRIMARY KEY,
        customer_name TEXT,
        customer_phone TEXT,
        call_type TEXT,
        priority TEXT,
        status TEXT,
        problem_description TEXT,
        updated_at TEXT,
        json_data TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE cached_call_details (
        id INTEGER PRIMARY KEY,
        json_data TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE pending_actions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action_type TEXT,
        payload TEXT,
        created_at TEXT,
        synced INTEGER DEFAULT 0
      )
    ''');
  }

  // --- Methods for cached_calls ---
  Future<void> cacheCalls(List<dynamic> callsJson) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('cached_calls');
      for (var call in callsJson) {
        await txn.insert('cached_calls', {
          'id': call['id'],
          'customer_name': call['customer']?['name'],
          'customer_phone': call['customer']?['phone'],
          'call_type': call['call_type'],
          'priority': call['priority'],
          'status': call['status'],
          'problem_description': call['problem_description'],
          'updated_at': call['updated_at'],
          'json_data': jsonEncode(call),
        });
      }
    });
  }

  Future<List<Map<String, dynamic>>> getCachedCalls() async {
    final db = await instance.database;
    final result = await db.query('cached_calls', orderBy: 'updated_at DESC');
    return result.map((e) => jsonDecode(e['json_data'] as String) as Map<String, dynamic>).toList();
  }

  // --- Methods for cached_call_details ---
  Future<void> cacheCallDetail(int id, Map<String, dynamic> detailJson) async {
    final db = await instance.database;
    await db.insert('cached_call_details', {
      'id': id,
      'json_data': jsonEncode(detailJson)
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getCachedCallDetail(int id) async {
    final db = await instance.database;
    final result = await db.query('cached_call_details', where: 'id = ?', whereArgs: [id]);
    if (result.isNotEmpty) {
      return jsonDecode(result.first['json_data'] as String);
    }
    return null;
  }

  Future<void> deleteCachedCall(int id) async {
    final db = await instance.database;
    await db.delete('cached_calls', where: 'id = ?', whereArgs: [id]);
    await db.delete('cached_call_details', where: 'id = ?', whereArgs: [id]);
  }

  // --- Methods for pending_actions ---
  Future<void> addPendingAction(String type, Map<String, dynamic> payload) async {
    final db = await instance.database;
    await db.insert('pending_actions', {
      'action_type': type,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
      'synced': 0
    });
  }

  Future<List<Map<String, dynamic>>> getPendingActions() async {
    final db = await instance.database;
    return await db.query('pending_actions', where: 'synced = ?', whereArgs: [0], orderBy: 'id ASC');
  }

  Future<void> markActionSynced(int id) async {
    final db = await instance.database;
    await db.update('pending_actions', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }
}
