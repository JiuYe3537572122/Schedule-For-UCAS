/// 周数工具：解析/压缩「1-16」「2,15」之类的周次描述，以及开学日期换算。
class Weeks {
  /// 表现所有周的通用写法（未填写周数 = 全周）。
  static const String allWeeks = '';

  /// 解析周次字符串 → 排序去重的周数集合。
  /// 例如 '1-16' → [1..16]；'2,15' → [2,15]；'1-4,6,9-12' → ...
  /// 空串表示全周（1..maxWeek）。
  static List<int> parse(String raw, {int maxWeek = kMaxWeek}) {
    if (raw.trim().isEmpty) {
      return List<int>.generate(maxWeek, (i) => i + 1);
    }
    final result = <int>{};
    final parts = raw.trim().split(RegExp(r'[,，、;；\s]+'));
    for (final part in parts) {
      if (part.isEmpty) continue;
      final m = RegExp(r'^(\d{1,2})(?:-(\d{1,2}))?$').firstMatch(part.trim());
      if (m == null) continue;
      final a = int.parse(m.group(1)!);
      final b = m.group(2) == null ? a : int.parse(m.group(2)!);
      final lo = a.clamp(1, maxWeek);
      final hi = b.clamp(1, maxWeek);
      for (var w = lo; w <= hi; w++) {
        result.add(w);
      }
    }
    final list = result.toList()..sort();
    return list;
  }

  /// 将周数集合压缩为规范字符串（连续区间 → 'a-b'，否则逗号分隔）。
  /// 恰好覆盖 1..maxWeek 时压成空串（全周）。
  static String compress(List<int> weeks, {int maxWeek = kMaxWeek}) {
    if (weeks.isEmpty) return allWeeks;
    final sorted = weeks.toSet().toList()..sort();
    if (sorted.length == maxWeek &&
        sorted.first == 1 &&
        sorted.last == maxWeek) {
      return allWeeks;
    }
    final runs = <String>[];
    var start = sorted.first;
    var prev = sorted.first;
    for (var i = 1; i < sorted.length; i++) {
      final w = sorted[i];
      if (w == prev + 1) {
        prev = w;
        continue;
      }
      runs.add(start == prev ? '$start' : '$start-$prev');
      start = w;
      prev = w;
    }
    runs.add(start == prev ? '$start' : '$start-$prev');
    return runs.join(',');
  }

  /// 原始字符串 → 规范形式（空串 = 全周）。
  static String canonical(String raw, {int maxWeek = kMaxWeek}) =>
      compress(parse(raw, maxWeek: maxWeek), maxWeek: maxWeek);

  static bool contains(String weeks, int week, {int maxWeek = kMaxWeek}) =>
      parse(weeks, maxWeek: maxWeek).contains(week);

  /// 是否全周。
  static bool isAll(String weeks) => weeks.isEmpty || weeks.trim().isEmpty;

  /// 用于展示：全周显示「全周」，否则显示规范串（末尾加「周」）。
  static String describe(String weeks) => isAll(weeks) ? '全周' : '$weeks周';

  static String describeWithWeek(String weeks, int week) {
    if (!contains(weeks, week)) return '不在第$week周';
    return isAll(weeks) ? '第$week周' : '第$week周 · $weeks周';
  }
}

/// 课表支持的最大周数（硬上限；国科大秋季学期 20 周）。
/// 实际学期周数见 [Semester.weekCount]。
const int kMaxWeek = 20;

/// 'yyyy-MM-dd' → DateTime（本地时区）。
DateTime parseDate(String s) {
  final parts = s.split('-').map(int.parse).toList();
  return DateTime(parts[0], parts[1], parts[2]);
}

/// 宽松解析，失败返回 null。
DateTime? tryParseDate(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  final m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(s.trim());
  if (m == null) return null;
  return DateTime(
      int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
}

String fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 短格式：'9/7'。
String fmtDateShort(DateTime d) => '${d.month}/${d.day}';

/// 某日期是第几周（以开学日期 startDateStr 计算，第 1 周从开学日期所在周一算起）。
int weekOf(DateTime date, String startDateStr, {int maxWeek = kMaxWeek}) {
  final start = parseDate(startDateStr);
  var monday = start.subtract(Duration(days: start.weekday - 1));
  final diff = DateTime(date.year, date.month, date.day)
      .difference(DateTime(monday.year, monday.month, monday.day))
      .inDays;
  final w = diff ~/ 7 + 1;
  return w.clamp(1, maxWeek);
}

/// 第 week 周、第 day 天（1..7，周一..周日）对应的日期。
DateTime dateOfWeekDay(int week, int day, String startDateStr) {
  final start = parseDate(startDateStr);
  final monday = start.subtract(Duration(days: start.weekday - 1));
  return monday.add(Duration(days: (week - 1) * 7 + (day - 1)));
}
