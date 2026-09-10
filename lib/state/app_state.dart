import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:class_manager/db/app_database.dart';
import 'package:class_manager/models/app_settings.dart';
import 'package:class_manager/models/course.dart';
import 'package:class_manager/models/exam.dart';
import 'package:class_manager/models/semester.dart';
import 'package:class_manager/services/schedule_parser.dart';
import 'package:class_manager/services/secret_store.dart';
import 'package:class_manager/theme/palette.dart';
import 'package:class_manager/utils/weeks.dart';

/// 全局状态（Provider ChangeNotifier）。
class AppState extends ChangeNotifier {
  final AppDatabase? db;

  /// 敏感数据存储（SEP 密码）。
  final SecretStore secrets;

  /// 全部课程（跨学期）。界面请用 [currentCourses]。
  List<Course> courses = [];
  List<Exam> exams = [];
  AppSettings settings = AppSettings();

  /// 用户自定义学期（预置学期见 [kBuiltinSemesters]）。
  List<Semester> customSemesters = [];

  int selectedDay = 1; // 1..7
  int browseWeek = 1; // 当前浏览的周
  bool bannerExpanded = true;

  AppState(this.db, {SecretStore? secrets})
      : secrets = secrets ?? MemorySecretStore();

  /// 从数据库初始化。
  static Future<AppState> create() async {
    final db = AppDatabase();
    final state = AppState(db, secrets: SecureSecretStore());
    await state.reload();
    return state;
  }

  /// 内存模式（测试用，无数据库）。
  AppState.memory()
      : db = null,
        secrets = MemorySecretStore();

  Future<void> reload() async {
    if (db == null) return;
    courses = await db!.loadCourses();
    exams = await db!.loadExams();
    settings = await db!.loadSettings();
    customSemesters = await db!.loadCustomSemesters();
    _ensureCurrentSemesterExists();
    await _migrateLegacySepPassword();
    browseWeek = currentWeek;
    notifyListeners();
  }

  /// 旧版本把 SEP 密码明文存在 settings 表；迁入安全存储后删除明文，
  /// 并 VACUUM 以免明文残留在数据库文件的空闲页里。
  Future<void> _migrateLegacySepPassword() async {
    final legacy = await db!.readRawSetting(kSepPasswordKey);
    if (legacy == null) return;
    if (legacy.isNotEmpty && settings.sepRemember) {
      await saveSepPassword(legacy);
    }
    await db!.deleteRawSetting(kSepPasswordKey);
    if (legacy.isNotEmpty) await db!.vacuum();
  }

  // ---------- SEP 密码（安全存储） ----------

  Future<String> loadSepPassword() async {
    try {
      return await secrets.read(kSepPasswordKey) ?? '';
    } catch (e) {
      // 典型情况：从备份恢复的密文没有对应的 Keystore 密钥。清掉坏条目，让下次保存能成功。
      debugPrint('读取 SEP 密码失败：$e');
      await clearSepPassword();
      return '';
    }
  }

  Future<void> saveSepPassword(String password) async {
    if (password.isEmpty) return clearSepPassword();
    try {
      await secrets.write(kSepPasswordKey, password);
    } catch (e) {
      debugPrint('保存 SEP 密码失败：$e');
    }
  }

  Future<void> clearSepPassword() async {
    try {
      await secrets.delete(kSepPasswordKey);
    } catch (e) {
      debugPrint('清除 SEP 密码失败：$e');
    }
  }

  // ---------- 学期 ----------

  /// 全部学期（预置 + 自定义，自定义覆盖同键预置），按开学日期降序。
  List<Semester> get semesters {
    final map = <String, Semester>{for (final s in kBuiltinSemesters) s.key: s};
    for (final s in customSemesters) {
      map[s.key] = s;
    }
    final list = map.values.toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    return list;
  }

  Semester semesterByKey(String key) =>
      semesters.firstWhere((s) => s.key == key, orElse: () => semesters.first);

  Semester get currentSemester => semesterByKey(settings.currentSemesterKey);

  /// 当前学期的课程。
  List<Course> get currentCourses => courses
      .where((c) => c.semesterKey == settings.currentSemesterKey)
      .toList();

  int courseCountOf(String semesterKey) =>
      courses.where((c) => c.semesterKey == semesterKey).length;

  void _ensureCurrentSemesterExists() {
    if (!semesters.any((s) => s.key == settings.currentSemesterKey)) {
      settings = settings.copyWith(currentSemesterKey: semesters.first.key);
    }
  }

  /// 切换当前学期。
  Future<void> setCurrentSemester(String key) async {
    if (!semesters.any((s) => s.key == key)) return;
    await updateSettings(settings.copyWith(currentSemesterKey: key));
    browseWeek = currentWeek;
    notifyListeners();
  }

  /// 新增或更新学期（同键覆盖）。返回最终的学期对象。
  Future<Semester> upsertSemester(Semester s) async {
    customSemesters = [
      for (final x in customSemesters)
        if (x.key != s.key) x,
      s,
    ];
    if (db != null) await db!.saveCustomSemesters(customSemesters);
    notifyListeners();
    return s;
  }

  /// 删除学期及其全部课程（预置学期只删除课程与自定义覆盖）。
  Future<void> deleteSemester(String key) async {
    if (db != null) await db!.clearCourses(semesterKey: key);
    courses.removeWhere((c) => c.semesterKey == key);
    customSemesters.removeWhere((s) => s.key == key);
    if (db != null) await db!.saveCustomSemesters(customSemesters);
    if (settings.currentSemesterKey == key) {
      _ensureCurrentSemesterExists();
      if (db != null) await db!.saveSettings(settings);
      browseWeek = currentWeek;
    }
    notifyListeners();
  }

  /// 若某开学日期对应的学期不存在则自动创建（导入时使用）。
  Future<Semester> ensureSemester(DateTime firstDay,
      {String? label, int? termId}) async {
    final draft = Semester.fromStart(firstDay, label: label, termId: termId);
    final existing = semesters.where((s) => s.key == draft.key).toList();
    if (existing.isNotEmpty) {
      final cur = existing.first;
      // 补充 termId / label
      if ((cur.termId == null && termId != null) ||
          (cur.label.isEmpty && (label ?? '').isNotEmpty)) {
        return upsertSemester(cur.copyWith(
          termId: cur.termId ?? termId,
          label: cur.label.isEmpty ? label : null,
        ));
      }
      return cur;
    }
    return upsertSemester(draft);
  }

  // ---------- 计算辅助 ----------

  int get maxWeek => currentSemester.weekCount;

  int get currentWeek => currentSemester.weekOfDate(DateTime.now());

  /// 第 week 周、第 day 天对应的日期。
  DateTime dateOf(int week, int day) => currentSemester.dateOf(week, day);

  /// 周次串 → 周数列表的缓存（纯函数，键含学期周数）。
  final Map<String, List<int>> _weeksMemo = <String, List<int>>{};

  List<int> _parsedWeeks(String weeks, int maxWeek) => _weeksMemo.putIfAbsent(
      '$maxWeek|$weeks', () => Weeks.parse(weeks, maxWeek: maxWeek));

  /// 课程在第 week 周是否上课。
  bool courseActiveInWeek(Course c, int week) =>
      _parsedWeeks(c.weeks, maxWeek).contains(week);

  /// 解析课程周次（按当前学期周数展开全周）。
  List<int> weeksOf(Course c) => List<int>.of(_parsedWeeks(c.weeks, maxWeek));

  /// 压缩周次（按当前学期周数判断全周）。
  String compressWeeks(Iterable<int> weeks) =>
      Weeks.compress(weeks.toList(), maxWeek: maxWeek);

  /// 指定星期当周的可见课程（按周次过滤，仅当前学期）。
  List<Course> coursesOn(int day, int week) => currentCourses
      .where((c) => c.day == day && courseActiveInWeek(c, week))
      .toList()
    ..sort((a, b) => a.startPeriod.compareTo(b.startPeriod));

  Color courseColor(Course c) => Color(c.colorValue);

  /// 给新课程挑选一个尽量未被使用的颜色（统计当前学期）。
  int pickCourseColor({Course? exclude}) {
    final used = <int, int>{};
    for (final c in currentCourses) {
      if (exclude != null && c.id != null && c.id == exclude.id) continue;
      used[c.colorValue] = (used[c.colorValue] ?? 0) + 1;
    }
    int best = kCourseColors.first;
    var bestCount = 1 << 30;
    for (final color in kCourseColors) {
      final count = used[color] ?? 0;
      if (count < bestCount) {
        bestCount = count;
        best = color;
      }
    }
    return best;
  }

  // ---------- 界面状态 ----------

  void setBrowseWeek(int w) {
    browseWeek = w.clamp(1, maxWeek);
    notifyListeners();
  }

  void setSelectedDay(int d) {
    selectedDay = d.clamp(1, 7);
    notifyListeners();
  }

  void toggleBanner() {
    bannerExpanded = !bannerExpanded;
    notifyListeners();
  }

  // ---------- 课程 CRUD ----------

  Future<void> addCourse(Course c) async {
    if (c.semesterKey.isEmpty) c.semesterKey = settings.currentSemesterKey;
    if (db != null) {
      c.id = await db!.insertCourse(c);
    }
    courses.add(c);
    notifyListeners();
  }

  Future<void> updateCourse(Course c) async {
    if (db != null && c.id != null) {
      await db!.updateCourse(c);
    }
    final i = courses.indexWhere((x) => x.id == c.id);
    if (i >= 0) {
      courses[i] = c;
    }
    notifyListeners();
  }

  Future<void> deleteCourse(Course c) async {
    if (db != null && c.id != null) {
      await db!.deleteCourse(c.id!);
    }
    courses.removeWhere((x) => x.id == c.id);
    notifyListeners();
  }

  /// 批量导入到 [semesterKey]（默认当前学期）；[replace] 为 true 时先清空该学期。
  ///
  /// 自动为不同课程分配不同颜色：**同名课程复用同一颜色**，
  /// 新课程取当前使用次数最少的颜色（逐条累加统计，避免整批同色）。
  Future<void> importCourses(List<ParsedCourse> parsed,
      {bool replace = false, String? semesterKey}) async {
    final key = semesterKey ?? settings.currentSemesterKey;
    if (replace) {
      if (db != null) await db!.clearCourses(semesterKey: key);
      courses.removeWhere((c) => c.semesterKey == key);
    }

    // 该学期现有课程的用色统计 + 课程名 → 颜色
    final used = <int, int>{};
    final nameColor = <String, int>{};
    for (final c in courses.where((c) => c.semesterKey == key)) {
      used[c.colorValue] = (used[c.colorValue] ?? 0) + 1;
      nameColor.putIfAbsent(c.name.trim(), () => c.colorValue);
    }

    int colorFor(String name) {
      final k = name.trim();
      final existing = nameColor[k];
      if (existing != null) return existing;
      var best = kCourseColors.first;
      var bestCount = 1 << 30;
      for (final color in kCourseColors) {
        final count = used[color] ?? 0;
        if (count < bestCount) {
          bestCount = count;
          best = color;
        }
      }
      used[best] = (used[best] ?? 0) + 1;
      nameColor[k] = best;
      return best;
    }

    for (final pc in parsed) {
      await addCourse(Course(
        name: pc.name,
        teacher: pc.teacher,
        location: pc.location,
        note: pc.note,
        day: pc.day,
        startPeriod: pc.startPeriod,
        endPeriod: pc.endPeriod,
        weeks: pc.weeks,
        colorValue: colorFor(pc.name),
        semesterKey: key,
        sourceId: pc.sourceId,
        courseCode: pc.courseCode,
      ));
    }
    notifyListeners();
  }

  /// 用选课系统最新数据替换当前学期中同一 sourceId 的课程（保留颜色 / 备注 / 教师）。
  Future<void> replaceCoursesFromSource(
      int sourceId, List<ParsedCourse> fresh) async {
    final key = settings.currentSemesterKey;
    final old = courses
        .where((c) => c.semesterKey == key && c.sourceId == sourceId)
        .toList();
    if (old.isEmpty) return;
    final color = old.first.colorValue;
    final note = old.first.note;
    final teacher = old.first.teacher;
    for (final c in old) {
      if (db != null && c.id != null) await db!.deleteCourse(c.id!);
      courses.remove(c);
    }
    for (final pc in fresh) {
      await addCourse(Course(
        name: pc.name,
        teacher: pc.teacher.isNotEmpty ? pc.teacher : teacher,
        location: pc.location,
        note: pc.note.isNotEmpty ? pc.note : note,
        day: pc.day,
        startPeriod: pc.startPeriod,
        endPeriod: pc.endPeriod,
        weeks: pc.weeks,
        colorValue: color,
        semesterKey: key,
        sourceId: pc.sourceId,
        courseCode: pc.courseCode,
      ));
    }
    notifyListeners();
  }

  // ---------- 考试 CRUD ----------

  Future<void> addExam(Exam e) async {
    if (db != null) {
      e.id = await db!.insertExam(e);
    }
    exams.add(e);
    notifyListeners();
  }

  Future<void> updateExam(Exam e) async {
    if (db != null && e.id != null) {
      await db!.updateExam(e);
    }
    final i = exams.indexWhere((x) => x.id == e.id);
    if (i >= 0) {
      exams[i] = e;
    }
    notifyListeners();
  }

  Future<void> deleteExam(Exam e) async {
    if (db != null && e.id != null) {
      await db!.deleteExam(e.id!);
    }
    exams.removeWhere((x) => x.id == e.id);
    notifyListeners();
  }

  // ---------- 设置 ----------

  Future<void> updateSettings(AppSettings s) async {
    settings = s;
    if (db != null) {
      await db!.saveSettings(s);
    }
    notifyListeners();
  }

  /// 修改当前学期的开学日期（会规范到周一；键随之变化，课程一并迁移）。
  Future<void> setStartDate(String date) async {
    final old = currentSemester;
    final updated = Semester.fromStart(parseDate(date),
        weekCount: old.weekCount, label: old.label, termId: old.termId);
    if (updated.key == old.key) return;
    // 迁移课程
    for (final c in courses.where((c) => c.semesterKey == old.key)) {
      c.semesterKey = updated.key;
      if (db != null && c.id != null) await db!.updateCourse(c);
    }
    customSemesters.removeWhere((s) => s.key == old.key);
    customSemesters.add(updated.copyWith(holidays: old.holidays));
    if (db != null) await db!.saveCustomSemesters(customSemesters);
    await updateSettings(settings.copyWith(currentSemesterKey: updated.key));
    browseWeek = currentWeek;
    notifyListeners();
  }

  /// 把壁纸文件复制进应用目录，返回新路径。
  Future<String> importWallpaper(Uint8List bytes, String originalName) async {
    final dir = await getApplicationDocumentsDirectory();
    final wallDir = Directory(p.join(dir.path, 'wallpapers'));
    if (!await wallDir.exists()) {
      await wallDir.create(recursive: true);
    }
    final ext = p.extension(originalName).isEmpty ? '.jpg' : p.extension(originalName);
    final name = 'wp_${DateTime.now().millisecondsSinceEpoch}$ext';
    final file = File(p.join(wallDir.path, name));
    await file.writeAsBytes(bytes);
    return file.path;
  }
}
