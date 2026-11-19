import 'package:sqflite/sqflite.dart';

import '../core/app_database.dart';
import '../models/chat.dart';

class ChatRepository {
  Future<Database> get _db => AppDatabase.instance.db;

  Future<List<ChatMessage>> getAll({int limit = 200}) async {
    final db = await _db;
    final rows = await db.query('chat_messages',
        orderBy: 'created_at DESC', limit: limit);
    return rows.map(ChatMessage.fromMap).toList().reversed.toList();
  }

  Future<void> upsert(ChatMessage m) async {
    final db = await _db;
    await db.insert('chat_messages', m.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> clear() async {
    final db = await _db;
    await db.delete('chat_messages');
  }
}
