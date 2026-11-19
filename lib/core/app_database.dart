import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Single SQLite database for the whole app. All data stays on-device.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const _dbName = 'ai_life_manager.db';
  static const _dbVersion = 1;

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      join(dir, _dbName),
      version: _dbVersion,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
    );
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
    batch.execute('''
      CREATE TABLE activities (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        notes TEXT,
        recurrence TEXT NOT NULL,
        weekdays TEXT NOT NULL DEFAULT '',
        day_of_month INTEGER,
        start_date TEXT,
        reminder_time TEXT,
        reminder_enabled INTEGER NOT NULL DEFAULT 0,
        color INTEGER NOT NULL,
        icon TEXT NOT NULL,
        archived INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    batch.execute('''
      CREATE TABLE activity_items (
        id TEXT PRIMARY KEY,
        activity_id TEXT NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
        title TEXT NOT NULL,
        detail TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');
    batch.execute('''
      CREATE TABLE completions (
        id TEXT PRIMARY KEY,
        activity_id TEXT NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
        item_id TEXT,
        date TEXT NOT NULL,
        completed_at TEXT NOT NULL
      )
    ''');
    batch.execute(
        'CREATE INDEX idx_completions_date ON completions(date, activity_id)');
    batch.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        note TEXT,
        date TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    batch.execute('CREATE INDEX idx_transactions_date ON transactions(date)');
    batch.execute('''
      CREATE TABLE loans (
        id TEXT PRIMARY KEY,
        person TEXT NOT NULL,
        amount REAL NOT NULL,
        direction TEXT NOT NULL,
        note TEXT,
        date TEXT NOT NULL,
        due_date TEXT,
        settled INTEGER NOT NULL DEFAULT 0,
        settled_at TEXT
      )
    ''');
    batch.execute('''
      CREATE TABLE savings_goals (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        target_amount REAL NOT NULL,
        saved_amount REAL NOT NULL DEFAULT 0,
        deadline TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    batch.execute('''
      CREATE TABLE food_entries (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        meal TEXT NOT NULL,
        name TEXT NOT NULL,
        calories REAL NOT NULL,
        protein REAL NOT NULL DEFAULT 0,
        carbs REAL NOT NULL DEFAULT 0,
        fat REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    batch.execute('CREATE INDEX idx_food_date ON food_entries(date)');
    batch.execute('''
      CREATE TABLE step_entries (
        date TEXT PRIMARY KEY,
        steps INTEGER NOT NULL,
        source TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    batch.execute('''
      CREATE TABLE learning_goals (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        category TEXT NOT NULL,
        deadline TEXT,
        completed INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    batch.execute('''
      CREATE TABLE milestones (
        id TEXT PRIMARY KEY,
        goal_id TEXT NOT NULL REFERENCES learning_goals(id) ON DELETE CASCADE,
        title TEXT NOT NULL,
        done INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');
    batch.execute('''
      CREATE TABLE chat_messages (
        id TEXT PRIMARY KEY,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        actions_json TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await batch.commit(noResult: true);
  }
}
