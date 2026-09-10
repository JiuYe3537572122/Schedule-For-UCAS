/// 中国科学院大学一天的课程安排：一天 13 节课（依据教务部《课程时间节次表》2025-07 版）。
class Period {
  final int index; // 1..13
  final String name; // 第一节 ...
  final String start; // '08:30'
  final String end; // '09:15'
  final DaySlot slot; // 上午 / 下午 / 晚上
  final String note; // 如「机动」

  const Period(
    this.index,
    this.name,
    this.start,
    this.end, {
    required this.slot,
    this.note = '',
  });

  String get range => '$start~$end';
}

/// 一天中的时段（用于课表网格画分隔线）。
enum DaySlot { morning, afternoon, evening }

const List<Period> kPeriods = [
  Period(1, '第一节', '08:30', '09:15', slot: DaySlot.morning),
  Period(2, '第二节', '09:20', '10:05', slot: DaySlot.morning),
  Period(3, '第三节', '10:25', '11:10', slot: DaySlot.morning),
  Period(4, '第四节', '11:15', '12:00', slot: DaySlot.morning),
  Period(5, '第五节', '13:30', '14:15', slot: DaySlot.afternoon),
  Period(6, '第六节', '14:20', '15:05', slot: DaySlot.afternoon),
  Period(7, '第七节', '15:25', '16:10', slot: DaySlot.afternoon),
  Period(8, '第八节', '16:15', '17:00', slot: DaySlot.afternoon),
  Period(9, '第九节', '17:05', '17:50', slot: DaySlot.afternoon),
  Period(10, '第十节', '18:30', '19:15', slot: DaySlot.evening),
  Period(11, '第十一节', '19:20', '20:05', slot: DaySlot.evening),
  Period(12, '第十二节', '20:15', '21:00', slot: DaySlot.evening),
  Period(13, '第十三节', '21:05', '21:50', slot: DaySlot.evening),
];

const int kPeriodCount = 13;

Period periodOf(int index) {
  if (index < 1) return kPeriods.first;
  if (index > kPeriodCount) return kPeriods.last;
  return kPeriods[index - 1];
}

/// 该节次之后是否是时段分界（第 4 节后午休、第 9 节后晚饭）。
bool isSlotBoundaryAfter(int index) {
  if (index < 1 || index >= kPeriodCount) return false;
  return kPeriods[index - 1].slot != kPeriods[index].slot;
}

const List<String> kWeekdayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

String weekdayName(int day) => kWeekdayNames[(day - 1).clamp(0, 6)];

/// 中文数字 → 阿拉伯数字（用于解析「第六节」），失败返回 null。
int? chineseNumber(String s) {
  const map = {
    '一': 1, '二': 2, '三': 3, '四': 4, '五': 5, '六': 6, '七': 7,
    '八': 8, '九': 9, '十': 10, '十一': 11, '十二': 12, '十三': 13,
  };
  return map[s];
}

String numberToChinese(int n) {
  const names = [
    '', '一', '二', '三', '四', '五', '六', '七', '八', '九', '十',
    '十一', '十二', '十三',
  ];
  return n >= 1 && n <= 13 ? names[n] : n.toString();
}
