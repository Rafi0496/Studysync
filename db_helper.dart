import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DbHelper {
  static final DbHelper _instance = DbHelper._internal();
  static Database? _database;

  factory DbHelper() => _instance;
  DbHelper._internal();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'studysync.db');
    return openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''CREATE TABLE users (
      id TEXT PRIMARY KEY, email TEXT UNIQUE, name TEXT, 
      streak INTEGER, points INTEGER, totalStudyHours INTEGER, joinDate TEXT)''');

    await db.execute('''CREATE TABLE study_sessions (
      id TEXT PRIMARY KEY, userId TEXT, subject TEXT, topics TEXT, 
      durationMinutes INTEGER, notes TEXT, date TEXT, pointsEarned INTEGER,
      FOREIGN KEY (userId) REFERENCES users(id))''');

    await db.execute('''CREATE TABLE achievements (
      id TEXT PRIMARY KEY, userId TEXT, title TEXT, 
      description TEXT, unlockedDate TEXT,
      FOREIGN KEY (userId) REFERENCES users(id))''');
  }

  Future<int> insertUser(Map<String, dynamic> user) async {
    final db = await database;
    return await db.insert('users', user, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getUser(String userId) async {
    final db = await database;
    final result = await db.query('users', where: 'id = ?', whereArgs: [userId]);
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final db = await database;
    return await db.query('users', orderBy: 'points DESC');
  }

  Future<int> updateUser(Map<String, dynamic> user) async {
    final db = await database;
    return await db.update('users', user, where: 'id = ?', whereArgs: [user['id']]);
  }

  Future<int> insertSession(Map<String, dynamic> session) async {
    final db = await database;
    return await db.insert('study_sessions', session);
  }

  Future<List<Map<String, dynamic>>> getSessionsByUser(String userId) async {
    final db = await database;
    return await db.query('study_sessions', where: 'userId = ?', whereArgs: [userId], orderBy: 'date DESC');
  }

  Future<List<Map<String, dynamic>>> getRecentSessions(String userId, {int limit = 5}) async {
    final db = await database;
    return await db.query('study_sessions', where: 'userId = ?', whereArgs: [userId], orderBy: 'date DESC', limit: limit);
  }

  Future<int> getTotalSessionsCount(String userId) async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM study_sessions WHERE userId = ?', [userId]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<Map<String, dynamic>>> getWeeklyStats(String userId) async {
    final db = await database;
    return await db.rawQuery(
        '''SELECT DATE(date) as date, SUM(durationMinutes) as totalMinutes, 
         SUM(pointsEarned) as totalPoints FROM study_sessions 
         WHERE userId = ? AND date >= datetime('now', '-7 days')
         GROUP BY DATE(date) ORDER BY date ASC''', [userId]);
  }

  Future<int> insertAchievement(Map<String, dynamic> achievement) async {
    final db = await database;
    return await db.insert('achievements', achievement);
  }

  Future<List<Map<String, dynamic>>> getUserAchievements(String userId) async {
    final db = await database;
    return await db.query('achievements', where: 'userId = ?', whereArgs: [userId], orderBy: 'unlockedDate DESC');
  }

  Future<bool> hasAchievement(String userId, String title) async {
    final db = await database;
    final result = await db.query('achievements', where: 'userId = ? AND title = ?', whereArgs: [userId, title]);
    return result.isNotEmpty;
  }

  Future<Map<String, dynamic>> getUserAnalytics(String userId) async {
    final db = await database;
    final totalMinutes = await db.rawQuery('SELECT SUM(durationMinutes) as total FROM study_sessions WHERE userId = ?', [userId]);
    final totalPoints = await db.rawQuery('SELECT SUM(pointsEarned) as total FROM study_sessions WHERE userId = ?', [userId]);
    final sessionsCount = await getTotalSessionsCount(userId);
    return {
      'totalHours': (Sqflite.firstIntValue(totalMinutes) ?? 0) ~/ 60,
      'totalPoints': Sqflite.firstIntValue(totalPoints) ?? 0,
      'sessionsLogged': sessionsCount,
    };
  }

  Future<List<Map<String, dynamic>>> getLeaderboard({int limit = 100}) async {
    final db = await database;
    return await db.query('users', orderBy: 'points DESC, streak DESC', limit: limit);
  }
}
