/// 课程模型（本地存储于 SQLite）。
class Course {
  int? id;
  String name;
  String teacher;
  String location;
  String note;
  int day; // 1..7（周一..周日）
  int startPeriod; // 1..13
  int endPeriod; // 1..13
  String weeks; // 规范周次，如 '1-16'、'2,15'；空串 = 全周
  int colorValue; // ARGB

  /// 所属学期键（= 该学期开学日期 'yyyy-MM-dd'）。
  String semesterKey;

  /// 选课系统课程 ID（courseId），手动添加的课程为 null。
  int? sourceId;

  /// 课程编码，如 '280216085404P2009'。
  String courseCode;

  Course({
    this.id,
    required this.name,
    this.teacher = '',
    this.location = '',
    this.note = '',
    required this.day,
    required this.startPeriod,
    required this.endPeriod,
    this.weeks = '',
    this.colorValue = 0xFF3FC9A2,
    this.semesterKey = '',
    this.sourceId,
    this.courseCode = '',
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'teacher': teacher,
        'location': location,
        'note': note,
        'day': day,
        'start_period': startPeriod,
        'end_period': endPeriod,
        'weeks': weeks,
        'color': colorValue,
        'semester_key': semesterKey,
        'source_id': sourceId,
        'course_code': courseCode,
      };

  factory Course.fromMap(Map<String, Object?> m) => Course(
        id: m['id'] as int?,
        name: (m['name'] as String?) ?? '',
        teacher: (m['teacher'] as String?) ?? '',
        location: (m['location'] as String?) ?? '',
        note: (m['note'] as String?) ?? '',
        day: (m['day'] as int?) ?? 1,
        startPeriod: (m['start_period'] as int?) ?? 1,
        endPeriod: (m['end_period'] as int?) ?? 1,
        weeks: (m['weeks'] as String?) ?? '',
        colorValue: (m['color'] as int?) ?? 0xFF3FC9A2,
        semesterKey: (m['semester_key'] as String?) ?? '',
        sourceId: m['source_id'] as int?,
        courseCode: (m['course_code'] as String?) ?? '',
      );

  Course copyWith({
    int? id,
    String? name,
    String? teacher,
    String? location,
    String? note,
    int? day,
    int? startPeriod,
    int? endPeriod,
    String? weeks,
    int? colorValue,
    String? semesterKey,
    int? sourceId,
    String? courseCode,
  }) =>
      Course(
        id: id ?? this.id,
        name: name ?? this.name,
        teacher: teacher ?? this.teacher,
        location: location ?? this.location,
        note: note ?? this.note,
        day: day ?? this.day,
        startPeriod: startPeriod ?? this.startPeriod,
        endPeriod: endPeriod ?? this.endPeriod,
        weeks: weeks ?? this.weeks,
        colorValue: colorValue ?? this.colorValue,
        semesterKey: semesterKey ?? this.semesterKey,
        sourceId: sourceId ?? this.sourceId,
        courseCode: courseCode ?? this.courseCode,
      );

  /// 显示用周次，如「1-16周」「全周」。
  String get weeksLabel {
    if (weeks.isEmpty || weeks.trim().isEmpty) return '全周';
    return '$weeks周';
  }

  int get span => endPeriod - startPeriod + 1;

  /// 是否来自选课系统（可刷新）。
  bool get isFromUcas => sourceId != null;
}
