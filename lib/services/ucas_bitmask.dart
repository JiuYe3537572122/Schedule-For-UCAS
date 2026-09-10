/// 国科大选课系统 `coursetime/{id}.json` 位掩码解码。
///
/// 规则（对 2026 秋 354 门课与 HTML 文字逐条比对验证）：
/// - `courseTime >> 13` = 星期（1 = 周一 … 7 = 周日）
/// - `courseTime` 低 13 位第 k 位（k 从 0 起）= 第 k+1 节有课
/// - `courseWeek` 第 k 位 = 第 k+1 周有课
library;

/// 一个上课时段（同一星期、若干节次、若干周次、一个地点）。
class UcasTimeSlot {
  final int day; // 1..7
  final List<int> periods; // 升序，可能不连续
  final List<int> weeks; // 升序
  final String place;

  const UcasTimeSlot({
    required this.day,
    required this.periods,
    required this.weeks,
    required this.place,
  });

  /// 把节次按连续段拆开：[1,2,5,6] → [[1,2],[5,6]]。
  List<List<int>> get periodRuns => splitRuns(periods);

  @override
  String toString() => 'UcasTimeSlot(day=$day, periods=$periods, weeks=$weeks, place=$place)';
}

const int kUcasPeriodBits = 13;
const int kUcasWeekBits = 32;

int ucasDayOf(int courseTime) => courseTime >> kUcasPeriodBits;

List<int> ucasPeriodsOf(int courseTime) => [
      for (var k = 0; k < kUcasPeriodBits; k++)
        if ((courseTime >> k) & 1 == 1) k + 1,
    ];

List<int> ucasWeeksOf(int courseWeek) => [
      for (var k = 0; k < kUcasWeekBits; k++)
        if ((courseWeek >> k) & 1 == 1) k + 1,
    ];

/// 反向编码（测试与分享用）。
int ucasEncodeTime(int day, Iterable<int> periods) {
  var v = day << kUcasPeriodBits;
  for (final p in periods) {
    v |= 1 << (p - 1);
  }
  return v;
}

int ucasEncodeWeeks(Iterable<int> weeks) {
  var v = 0;
  for (final w in weeks) {
    v |= 1 << (w - 1);
  }
  return v;
}

/// 解码 `courseTimeList` 的一个元素；字段缺失或非法时返回 null。
UcasTimeSlot? decodeUcasSlot(Map<String, dynamic> t) {
  final ct = _asInt(t['courseTime']);
  final cw = _asInt(t['courseWeek']);
  if (ct == null || cw == null) return null;
  final day = ucasDayOf(ct);
  final periods = ucasPeriodsOf(ct);
  if (day < 1 || day > 7 || periods.isEmpty) return null;
  return UcasTimeSlot(
    day: day,
    periods: periods,
    weeks: ucasWeeksOf(cw),
    place: (t['coursePlace'] as String?)?.trim() ?? '',
  );
}

int? _asInt(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

/// 把升序整数列表切成连续段。
List<List<int>> splitRuns(List<int> sorted) {
  final runs = <List<int>>[];
  List<int>? cur;
  for (final x in sorted) {
    if (cur != null && x == cur.last + 1) {
      cur.add(x);
    } else {
      cur = [x];
      runs.add(cur);
    }
  }
  return runs;
}
