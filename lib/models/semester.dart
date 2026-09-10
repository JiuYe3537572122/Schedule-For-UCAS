import 'dart:convert';

import 'package:class_manager/utils/weeks.dart';

/// 学期：只由开学日期（第 1 周周一）标识，不区分秋 / 春 / 夏类型。
///
/// [key] 与 [startDate] 相同，同时作为课程按学期隔离的键。
class Semester {
  final String key; // = startDate，'2026-08-31'
  final String startDate; // 第 1 周周一，'yyyy-MM-dd'
  final int weekCount; // 该学期周数
  final String label; // 显示名，如「2026年秋季学期」
  final int? termId; // 选课系统学期 ID（如 89576），可空
  final List<Holiday> holidays;

  const Semester({
    required this.startDate,
    required this.weekCount,
    required this.label,
    this.termId,
    this.holidays = const [],
  }) : key = startDate;

  /// 按开学月份推断默认周数：8–12 月开学 → 20 周；其余 → 18 周（含夏季 I/II）。
  static int defaultWeekCount(DateTime start) => start.month >= 8 ? 20 : 18;

  /// 按开学日期生成默认显示名，如「2026年秋季学期」「2027年春季学期」。
  static String defaultLabel(DateTime start) =>
      '${start.year}年${start.month >= 8 ? '秋季' : '春季'}学期';

  /// 由开学日期（会被规范到所在周一）创建学期。
  factory Semester.fromStart(DateTime start,
      {int? weekCount, String? label, int? termId}) {
    final monday = start.subtract(Duration(days: start.weekday - 1));
    final d = DateTime(monday.year, monday.month, monday.day);
    return Semester(
      startDate: fmtDate(d),
      weekCount: (weekCount ?? defaultWeekCount(d)).clamp(1, kMaxWeek),
      label: label ?? defaultLabel(d),
      termId: termId,
    );
  }

  DateTime get start => parseDate(startDate);

  DateTime get end => start.add(Duration(days: weekCount * 7 - 1));

  /// 今天是否落在本学期内（含前后各 1 周的宽限，方便假期查看）。
  bool containsDate(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return !d.isBefore(start.subtract(const Duration(days: 7))) &&
        !d.isAfter(end.add(const Duration(days: 7)));
  }

  int weekOfDate(DateTime date) =>
      weekOf(date, startDate, maxWeek: weekCount);

  DateTime dateOf(int week, int day) => dateOfWeekDay(week, day, startDate);

  Holiday? holidayOn(DateTime date) {
    final s = fmtDate(date);
    for (final h in holidays) {
      if (h.date == s) return h;
    }
    return null;
  }

  Semester copyWith({
    String? startDate,
    int? weekCount,
    String? label,
    int? termId,
    bool clearTermId = false,
    List<Holiday>? holidays,
  }) =>
      Semester(
        startDate: startDate ?? this.startDate,
        weekCount: weekCount ?? this.weekCount,
        label: label ?? this.label,
        termId: clearTermId ? null : (termId ?? this.termId),
        holidays: holidays ?? this.holidays,
      );

  Map<String, Object?> toMap() => {
        'start_date': startDate,
        'week_count': weekCount,
        'label': label,
        'term_id': termId,
        'holidays': [for (final h in holidays) h.toMap()],
      };

  factory Semester.fromMap(Map<String, Object?> m) => Semester(
        startDate: m['start_date'] as String,
        weekCount: ((m['week_count'] as num?)?.toInt() ?? 20).clamp(1, kMaxWeek),
        label: (m['label'] as String?) ?? '',
        termId: (m['term_id'] as num?)?.toInt(),
        holidays: [
          for (final h in (m['holidays'] as List?) ?? const [])
            Holiday.fromMap(Map<String, Object?>.from(h as Map)),
        ],
      );

  static String encodeList(List<Semester> list) =>
      jsonEncode([for (final s in list) s.toMap()]);

  static List<Semester> decodeList(String? json) {
    if (json == null || json.trim().isEmpty) return [];
    try {
      final raw = jsonDecode(json) as List;
      return [
        for (final e in raw) Semester.fromMap(Map<String, Object?>.from(e as Map)),
      ];
    } catch (_) {
      return [];
    }
  }

  @override
  bool operator ==(Object other) => other is Semester && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

/// 法定假日标记（仅显示，不做调休换课）。
class Holiday {
  final String date; // 'yyyy-MM-dd'
  final String name; // '国庆'

  const Holiday(this.date, this.name);

  Map<String, Object?> toMap() => {'date': date, 'name': name};

  factory Holiday.fromMap(Map<String, Object?> m) =>
      Holiday(m['date'] as String, (m['name'] as String?) ?? '');
}

/// 预置学期（2026-2027 学年，来自国科大官方校历）。
const List<Semester> kBuiltinSemesters = [
  Semester(
    startDate: '2026-08-31',
    weekCount: 20,
    label: '2026年秋季学期',
    termId: 89576,
    holidays: [
      Holiday('2026-09-25', '中秋'),
      Holiday('2026-10-01', '国庆'),
      Holiday('2027-01-01', '元旦'),
    ],
  ),
  Semester(
    startDate: '2027-02-22',
    weekCount: 18,
    label: '2027年春季学期',
    holidays: [
      Holiday('2027-04-05', '清明'),
      Holiday('2027-05-01', '劳动节'),
      Holiday('2027-06-09', '端午'),
    ],
  ),
];

/// 默认学期键。
const String kDefaultSemesterKey = '2026-08-31';
