import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:html/parser.dart' as html_parser;

import 'package:class_manager/models/periods.dart';
import 'package:class_manager/services/schedule_parser.dart';
import 'package:class_manager/services/ucas_bitmask.dart';
import 'package:class_manager/utils/weeks.dart';

/// `coursetime/{id}.json` 里的学期信息。
class UcasTerm {
  final int? id;
  final String name; // 2026—2027学年(秋)第一学期
  final String shortName; // 2026年秋季学期
  final DateTime? firstDay; // 第 1 周周一

  const UcasTerm({this.id, this.name = '', this.shortName = '', this.firstDay});

  static UcasTerm? fromJson(Map<String, dynamic>? m) {
    if (m == null) return null;
    return UcasTerm(
      id: (m['id'] as num?)?.toInt(),
      name: (m['name'] as String?) ?? '',
      shortName: (m['shortName'] as String?) ?? (m['displayShortName'] as String?) ?? '',
      firstDay: tryParseDate(m['firstDay'] as String?),
    );
  }
}

/// 一门课的在线补全结果。
class ResolvedCourse {
  final int courseId;
  final String name;
  final String courseCode;
  final List<UcasTimeSlot> slots;
  final UcasTerm? term;

  const ResolvedCourse({
    required this.courseId,
    required this.name,
    required this.courseCode,
    required this.slots,
    this.term,
  });

  bool get hasSchedule => slots.isNotEmpty;

  /// 转成可导入的课程条目（节次按连续段拆分）。
  List<ParsedCourse> toParsedCourses({int maxWeek = kMaxWeek, String nameFallback = ''}) {
    final result = <ParsedCourse>[];
    final n = name.isNotEmpty ? name : nameFallback;
    for (final s in slots) {
      for (final run in s.periodRuns) {
        result.add(ParsedCourse(
          name: n,
          location: s.place,
          day: s.day.clamp(1, 7),
          startPeriod: run.first.clamp(1, kPeriodCount),
          endPeriod: run.last.clamp(1, kPeriodCount),
          weeks: Weeks.compress(s.weeks, maxWeek: maxWeek),
          sourceId: courseId,
          courseCode: courseCode,
        ));
      }
    }
    return result;
  }
}

/// 单个 ID 的获取失败原因。
enum ResolveFailure { network, notFound, loginRequired, badResponse }

class ResolveError {
  final int courseId;
  final ResolveFailure kind;
  final String message;
  const ResolveError(this.courseId, this.kind, this.message);

  String get label => switch (kind) {
        ResolveFailure.network => '网络错误',
        ResolveFailure.notFound => '课程不存在',
        ResolveFailure.loginRequired => '接口需要登录',
        ResolveFailure.badResponse => '响应无法解析',
      };
}

class ResolveReport {
  final List<ResolvedCourse> courses;
  final List<ResolveError> errors;
  const ResolveReport(this.courses, this.errors);

  /// 所有课程共同的学期（取第一个有 firstDay 的）。
  UcasTerm? get term {
    for (final c in courses) {
      if (c.term?.firstDay != null) return c.term;
    }
    return null;
  }

  bool get loginWall => errors.any((e) => e.kind == ResolveFailure.loginRequired);
}

/// 抓取函数签名：返回 (状态码, 响应体)。可注入以便测试。
typedef UcasFetcher = Future<(int status, String body)> Function(Uri uri);

/// 用选课系统公开接口补全课程信息。
class UcasCourseResolver {
  static const String baseUrl = 'https://xkcts.ucas.ac.cn:8443/course/coursetime/';

  final UcasFetcher fetch;
  final int concurrency;
  final Duration timeout;

  UcasCourseResolver({
    UcasFetcher? fetch,
    this.concurrency = 4,
    this.timeout = const Duration(seconds: 15),
  }) : fetch = fetch ?? _defaultFetch;

  static Uri jsonUri(int id) => Uri.parse('$baseUrl$id.json');
  static Uri pageUri(int id) => Uri.parse('$baseUrl$id');

  static Future<(int, String)> _defaultFetch(Uri uri) async {
    final client = HttpClient()
      ..userAgent = 'Mozilla/5.0 (Guoxiaoke; Flutter)'
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.getUrl(uri);
      req.headers.set(HttpHeaders.acceptHeader, 'application/json, text/html');
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      return (res.statusCode, body);
    } finally {
      client.close(force: true);
    }
  }

  /// 并发解析一组课程 ID。[onProgress] 回调 (完成数, 总数)。
  Future<ResolveReport> resolve(List<int> ids,
      {void Function(int done, int total)? onProgress}) async {
    final unique = ids.toSet().toList();
    final courses = <ResolvedCourse>[];
    final errors = <ResolveError>[];
    var done = 0;
    final queue = List<int>.from(unique);

    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final id = queue.removeAt(0);
        final r = await _resolveOne(id);
        if (r.$1 != null) courses.add(r.$1!);
        if (r.$2 != null) errors.add(r.$2!);
        done++;
        onProgress?.call(done, unique.length);
      }
    }

    await Future.wait([for (var i = 0; i < concurrency; i++) worker()]);
    courses.sort((a, b) => unique.indexOf(a.courseId).compareTo(unique.indexOf(b.courseId)));
    return ResolveReport(courses, errors);
  }

  Future<(ResolvedCourse?, ResolveError?)> _resolveOne(int id) async {
    (int, String)? res;
    Object? lastErr;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        res = await fetch(jsonUri(id)).timeout(timeout);
        break;
      } catch (e) {
        lastErr = e;
      }
    }
    if (res == null) {
      return (null, ResolveError(id, ResolveFailure.network, '$lastErr'));
    }
    final (status, body) = res;
    if (status == 302 || status == 401 || status == 403) {
      return (null, const ResolveError(0, ResolveFailure.loginRequired, '').copyId(id));
    }
    if (status == 404) {
      return (null, ResolveError(id, ResolveFailure.notFound, 'HTTP 404'));
    }
    final trimmed = body.trimLeft();
    if (!trimmed.startsWith('{')) {
      // HTML：判断是登录墙还是无效 ID
      final text = html_parser.parse(body).body?.text ?? body;
      if (text.contains('登录') || text.contains('login')) {
        return (null, ResolveError(id, ResolveFailure.loginRequired, 'HTML 登录页'));
      }
      return (null, ResolveError(id, ResolveFailure.notFound, '非 JSON 响应'));
    }
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return (parseCourseTimeJson(id, json), null);
    } catch (e) {
      return (null, ResolveError(id, ResolveFailure.badResponse, '$e'));
    }
  }

  /// 解析 `coursetime/{id}.json`（纯函数，供测试）。
  static ResolvedCourse parseCourseTimeJson(int id, Map<String, dynamic> json) {
    final course = json['course'] as Map<String, dynamic>? ?? const {};
    final list = (json['courseTimeList'] as List?) ?? const [];
    final slots = <UcasTimeSlot>[];
    var nameFromSlots = '';
    for (final t in list) {
      if (t is! Map) continue;
      final m = Map<String, dynamic>.from(t);
      final s = decodeUcasSlot(m);
      if (s != null) slots.add(s);
      if (nameFromSlots.isEmpty) {
        nameFromSlots = (m['courseName'] as String?)?.trim() ?? '';
      }
    }
    final name = ((course['configureName'] as String?)?.trim().isNotEmpty ?? false)
        ? (course['configureName'] as String).trim()
        : nameFromSlots;
    return ResolvedCourse(
      courseId: (course['configureId'] as num?)?.toInt() ?? id,
      name: name,
      courseCode: (course['configureCode'] as String?)?.trim() ?? '',
      slots: slots,
      term: UcasTerm.fromJson(json['term'] as Map<String, dynamic>?) ??
          UcasTerm.fromJson(json['curTerm'] as Map<String, dynamic>?),
    );
  }

  /// 解析 `coursetime/{id}` HTML 页面（离线兜底，纯函数）。
  static ResolvedCourse parseCourseTimeHtml(int id, String html) {
    final doc = html_parser.parse(html);
    final text = doc.body?.text ?? '';
    final nameM = RegExp(r'课程名称[:：]\s*(\S[^\n]*)').firstMatch(text);
    final name = nameM?.group(1)?.trim() ?? '';
    final termM = RegExp(r'(\d{4})—(\d{4})学年\((春|秋|夏)\)第[一二三]学期').firstMatch(text);
    final term = termM == null
        ? null
        : UcasTerm(name: termM.group(0)!, shortName: '${termM.group(1)}年${termM.group(3)}季学期');
    final slots = <UcasTimeSlot>[];
    const dayMap = {'一': 1, '二': 2, '三': 3, '四': 4, '五': 5, '六': 6, '日': 7, '天': 7};
    final rows = doc.querySelectorAll('tr');
    for (var i = 0; i + 2 < rows.length; i += 3) {
      String cell(int k) => rows[i + k].querySelector('td')?.text.trim() ?? '';
      final tm = RegExp(r'星期([一二三四五六日天])[:：]\s*第([\d、,，\s]+)节').firstMatch(cell(0));
      if (tm == null) continue;
      final periods = RegExp(r'\d+').allMatches(tm.group(2)!).map((m) => int.parse(m.group(0)!)).toList()..sort();
      final weeks = RegExp(r'\d+').allMatches(cell(2)).map((m) => int.parse(m.group(0)!)).toList()..sort();
      slots.add(UcasTimeSlot(
        day: dayMap[tm.group(1)]!,
        periods: periods,
        weeks: weeks,
        place: cell(1),
      ));
    }
    return ResolvedCourse(courseId: id, name: name, courseCode: '', slots: slots, term: term);
  }
}

extension on ResolveError {
  ResolveError copyId(int id) => ResolveError(id, kind, message);
}
