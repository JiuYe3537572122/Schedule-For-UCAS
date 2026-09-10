/// 考试模型。
class Exam {
  int? id;
  String name;
  String location;
  String date; // 'yyyy-MM-dd'
  String startTime; // 'HH:mm'，可为空
  String endTime; // 'HH:mm'，可为空
  String note;

  Exam({
    this.id,
    required this.name,
    this.location = '',
    required this.date,
    this.startTime = '',
    this.endTime = '',
    this.note = '',
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'location': location,
        'date': date,
        'start_time': startTime,
        'end_time': endTime,
        'note': note,
      };

  factory Exam.fromMap(Map<String, Object?> m) => Exam(
        id: m['id'] as int?,
        name: (m['name'] as String?) ?? '',
        location: (m['location'] as String?) ?? '',
        date: (m['date'] as String?) ?? '',
        startTime: (m['start_time'] as String?) ?? '',
        endTime: (m['end_time'] as String?) ?? '',
        note: (m['note'] as String?) ?? '',
      );

  Exam copyWith({
    int? id,
    String? name,
    String? location,
    String? date,
    String? startTime,
    String? endTime,
    String? note,
  }) =>
      Exam(
        id: id ?? this.id,
        name: name ?? this.name,
        location: location ?? this.location,
        date: date ?? this.date,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        note: note ?? this.note,
      );

  /// 与今天相比的剩余天数（0 = 今天，负 = 已结束）。
  int daysFromNow([DateTime? now]) {
    final today = now ?? DateTime.now();
    final d = DateTime.tryParse(date);
    if (d == null) return 1 << 20; // 无效日期视为遥远未来，不抛异常
    return DateTime(d.year, d.month, d.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
  }

  bool get isOver => daysFromNow() < 0;

  String get statusLabel {
    final n = daysFromNow();
    if (n < 0) return '已结束';
    if (n == 0) return '今天';
    return '还有 $n 天';
  }

  String get timeLabel {
    if (startTime.isEmpty && endTime.isEmpty) return '';
    if (startTime.isNotEmpty && endTime.isNotEmpty) return '($startTime~$endTime)';
    return '($startTime$endTime)';
  }
}
