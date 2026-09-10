import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'package:class_manager/models/app_settings.dart';
import 'package:class_manager/models/course.dart';
import 'package:class_manager/models/exam.dart';
import 'package:class_manager/models/semester.dart';

/// SQLite 本地数据库。
///
/// v1：courses / exams / settings 三张表（来自原项目 Schedule-For-WHU）。
/// v2：courses 增加 semester_key / source_id / course_code；settings 增加
///     current_semester 与 semesters（JSON）。
class AppDatabase {
  static const int kVersion = 2;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'class_manager.db');
    _db = await openDatabase(path,
        version: kVersion, onCreate: _onCreate, onUpgrade: _onUpgrade);
    await _initDefaults(_db!);
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE courses(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        teacher TEXT DEFAULT '',
        location TEXT DEFAULT '',
        note TEXT DEFAULT '',
        day INTEGER NOT NULL,
        start_period INTEGER NOT NULL,
        end_period INTEGER NOT NULL,
        weeks TEXT DEFAULT '',
        color INTEGER NOT NULL,
        semester_key TEXT NOT NULL DEFAULT '',
        source_id INTEGER,
        course_code TEXT DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE exams(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        location TEXT DEFAULT '',
        date TEXT NOT NULL,
        start_time TEXT DEFAULT '',
        end_time TEXT DEFAULT '',
        note TEXT DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE settings(
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          "ALTER TABLE courses ADD COLUMN semester_key TEXT NOT NULL DEFAULT ''");
      await db.execute('ALTER TABLE courses ADD COLUMN source_id INTEGER');
      await db.execute(
          "ALTER TABLE courses ADD COLUMN course_code TEXT DEFAULT ''");
      // 旧数据全部归入当时的开学日期所对应的学期
      final rows = await db.query('settings',
          where: 'key = ?', whereArgs: ['start_date']);
      final oldStart = rows.isEmpty
          ? kDefaultSemesterKey
          : (rows.first['value']?.toString() ?? kDefaultSemesterKey);
      final key = _normalizeKey(oldStart);
      await db.update('courses', {'semester_key': key},
          where: "semester_key = ''");
      await db.insert(
        'settings',
        {'key': 'current_semester', 'value': key},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      // 旧开学日期不是预置学期时，注册为自定义学期
      if (!kBuiltinSemesters.any((s) => s.key == key)) {
        final custom = Semester.fromStart(DateTime.parse(key));
        await db.insert(
          'settings',
          {'key': 'semesters', 'value': Semester.encodeList([custom])},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
  }

  static String _normalizeKey(String date) {
    try {
      final d = DateTime.parse(date);
      return Semester.fromStart(d).key;
    } catch (_) {
      return kDefaultSemesterKey;
    }
  }

  // ---------- 课程 ----------

  Future<List<Course>> loadCourses() async {
    final db = await database;
    final rows = await db.query('courses', orderBy: 'day, start_period');
    return rows.map(Course.fromMap).toList();
  }

  Future<int> insertCourse(Course c) async {
    final db = await database;
    final map = c.toMap()..remove('id');
    return db.insert('courses', map);
  }

  Future<void> updateCourse(Course c) async {
    final db = await database;
    await db.update('courses', c.toMap(),
        where: 'id = ?', whereArgs: [c.id]);
  }

  Future<void> deleteCourse(int id) async {
    final db = await database;
    await db.delete('courses', where: 'id = ?', whereArgs: [id]);
  }

  /// 清空某学期课程；[semesterKey] 为 null 时清空全部。
  Future<void> clearCourses({String? semesterKey}) async {
    final db = await database;
    if (semesterKey == null) {
      await db.delete('courses');
    } else {
      await db.delete('courses',
          where: 'semester_key = ?', whereArgs: [semesterKey]);
    }
  }

  // ---------- 考试 ----------

  Future<List<Exam>> loadExams() async {
    final db = await database;
    final rows = await db.query('exams', orderBy: 'date');
    return rows.map(Exam.fromMap).toList();
  }

  Future<int> insertExam(Exam e) async {
    final db = await database;
    final map = e.toMap()..remove('id');
    return db.insert('exams', map);
  }

  Future<void> updateExam(Exam e) async {
    final db = await database;
    await db.update('exams', e.toMap(), where: 'id = ?', whereArgs: [e.id]);
  }

  Future<void> deleteExam(int id) async {
    final db = await database;
    await db.delete('exams', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- 设置 ----------

  Future<Map<String, String?>> _loadRaw() async {
    final db = await database;
    final rows = await db.query('settings');
    return {
      for (final r in rows) r['key'] as String: r['value']?.toString(),
    };
  }

  Future<AppSettings> loadSettings() async {
    final map = await _loadRaw();
    return AppSettings.fromMap({
      'current_semester': map['current_semester'],
      'start_date': map['start_date'],
      'theme_color_index': int.tryParse(map['theme_color_index'] ?? ''),
      'background_blur': double.tryParse(map['background_blur'] ?? ''),
      'card_transparency': double.tryParse(map['card_transparency'] ?? ''),
      'card_blur': double.tryParse(map['card_blur'] ?? ''),
      'liquid_glass': int.tryParse(map['liquid_glass'] ?? ''),
      'jelly_effect': int.tryParse(map['jelly_effect'] ?? ''),
      'saturation': double.tryParse(map['saturation'] ?? ''),
      'refraction': double.tryParse(map['refraction'] ?? ''),
      'dispersion': double.tryParse(map['dispersion'] ?? ''),
      'wallpaper_path': map['wallpaper_path'],
      'show_grid': int.tryParse(map['show_grid'] ?? ''),
      'user_name': map['user_name'],
      'sep_username': map['sep_username'],
      'sep_remember': int.tryParse(map['sep_remember'] ?? ''),
    });
  }

  /// 读取单个原始设置项（用于迁移旧版明文保存的 SEP 密码）。
  Future<String?> readRawSetting(String key) async {
    final db = await database;
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value']?.toString();
  }

  Future<void> deleteRawSetting(String key) async {
    final db = await database;
    await db.delete('settings', where: 'key = ?', whereArgs: [key]);
  }

  /// 重建数据库文件，清掉已删除行在空闲页中的残留（迁移明文密码后调用）。
  Future<void> vacuum() async {
    final db = await database;
    await db.execute('VACUUM');
  }

  Future<void> saveSettings(AppSettings s) async {
    final db = await database;
    final batch = db.batch();
    s.toMap().forEach((k, v) {
      if (v == null) {
        batch.delete('settings', where: 'key = ?', whereArgs: [k]);
      } else {
        batch.insert(
          'settings',
          {'key': k, 'value': v.toString()},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    await batch.commit(noResult: true);
  }

  /// 自定义学期列表（不含预置）。
  Future<List<Semester>> loadCustomSemesters() async {
    final map = await _loadRaw();
    return Semester.decodeList(map['semesters']);
  }

  Future<void> saveCustomSemesters(List<Semester> list) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': 'semesters', 'value': Semester.encodeList(list)},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ---------- 首启初始化 ----------

  /// 仅初始化默认设置；课程 / 考试默认为空，由用户自行添加或导入。
  Future<void> _initDefaults(Database db) async {
    final settingCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM settings')) ??
        0;
    if (settingCount == 0) {
      final batch = db.batch();
      AppSettings().toMap().forEach((k, v) {
        if (v != null) {
          batch.insert('settings', {'key': k, 'value': v.toString()});
        }
      });
      await batch.commit(noResult: true);
    }
  }
}
