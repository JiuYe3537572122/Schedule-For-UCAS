import 'package:class_manager/models/periods.dart';
import 'package:class_manager/utils/weeks.dart';

/// 解析出的课程条目（尚未入库）。
class ParsedCourse {
  String name;
  String teacher;
  String location;
  String note;
  int day; // 1..7
  int startPeriod; // 1..13
  int endPeriod; // 1..13
  String weeks; // 规范周次，空 = 全周

  /// 选课系统课程 ID（在线导入时有值）。
  int? sourceId;

  /// 课程编码。
  String courseCode;

  ParsedCourse({
    required this.name,
    this.teacher = '',
    this.location = '',
    this.note = '',
    required this.day,
    required this.startPeriod,
    required this.endPeriod,
    this.weeks = '',
    this.sourceId,
    this.courseCode = '',
  });

  String get periodsLabel {
    if (startPeriod == endPeriod) {
      return '第${numberToChinese(startPeriod)}节';
    }
    return '第${numberToChinese(startPeriod)}~${numberToChinese(endPeriod)}节';
  }

  String get summary => '${weekdayName(day)}  $periodsLabel  ${Weeks.describe(weeks)}';
}

/// 表格单元格（虚拟网格已展开合并）。
class RawCell {
  final List<String> lines;
  final int rowspan; // 占据的表格行数（节数）
  final int colspan;

  const RawCell({
    required this.lines,
    this.rowspan = 1,
    this.colspan = 1,
  });

  bool get isEmpty => lines.isEmpty;
}

/// 单元格内的一门课（周数前缀 + 若干行）。
class CellChunk {
  String weeks;
  final List<String> lines;
  CellChunk(this.weeks, this.lines);
}

final RegExp weekPrefixRe =
    RegExp(r'^\s*(\d{1,2}(?:-\d{1,2})?(?:[,，、;；]\d{1,2}(?:-\d{1,2})?)*)\s*周');

final RegExp _locationRe = RegExp(
    r'(楼|室|馆|厅|中心|基地|校区|教室|实验室|机房|教学楼|实验楼|图书馆|科学院|研究院|场|教)');

bool _looksLikeLocation(String s) {
  if (s.isEmpty) return false;
  if (_locationRe.hasMatch(s)) return true;
  if (RegExp(r'^[A-Za-z]?\d{1,3}[-A-Za-z0-9]*$').hasMatch(s)) return true;
  // 形如「一教101」「学园二350」
  return RegExp(r'^[一-龥]{1,4}\d{1,4}[A-Za-z\d-]*$').hasMatch(s);
}

bool _looksLikeTeacher(String s) {
  if (s.isEmpty || _looksLikeLocation(s)) return false;
  if (RegExp(r'[,，、]').hasMatch(s)) return true; // 多位老师
  return RegExp(r'^[一-龥·]{2,6}$').hasMatch(s);
}

/// 把单元格内的多行文本切分成 (周数, 行) 块（一个格子可能有多门课）。
List<CellChunk> splitEntries(List<String> lines) {
  final chunks = <CellChunk>[];
  CellChunk? cur;
  for (final raw in lines) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final m = weekPrefixRe.firstMatch(line);
    if (m != null) {
      cur = CellChunk(Weeks.canonical(m.group(1)!), []);
      chunks.add(cur);
      final rest = line.substring(m.end).trim();
      if (rest.isNotEmpty) cur.lines.add(rest);
    } else {
      if (cur == null) {
        cur = CellChunk('', []);
        chunks.add(cur);
      }
      cur.lines.add(line);
    }
  }
  return chunks;
}

/// 把 (周数, 若干行) 转成 ParsedCourse 字段。
ParsedCourse fillCourseEntry(
    CellChunk chunk, int day, int startPeriod, int endPeriod) {
  final lines = chunk.lines.where((l) => l.trim().isNotEmpty).toList();
  var name = '';
  var teacher = '';
  var location = '';
  var note = '';
  if (lines.isNotEmpty) {
    name = lines.first;
    final rest = lines.sublist(1).toList();
    if (rest.isNotEmpty) {
      // 优先从尾部找地点
      var locIdx = -1;
      for (var i = rest.length - 1; i >= 0; i--) {
        if (_looksLikeLocation(rest[i])) {
          locIdx = i;
          break;
        }
      }
      if (locIdx >= 0 && rest.length >= 2) {
        location = rest[locIdx];
        rest.removeAt(locIdx);
      } else if (rest.length == 1) {
        location = rest[0];
        rest.clear();
      }
      final teacherParts = <String>[];
      final noteParts = <String>[];
      for (final line in rest) {
        if (teacherParts.isEmpty && _looksLikeTeacher(line)) {
          teacherParts.add(line);
        } else {
          noteParts.add(line);
        }
      }
      teacher = teacherParts.join(',');
      note = noteParts.join('；');
    }
  }
  final w = startPeriod.clamp(1, kPeriodCount);
  final e = endPeriod.clamp(w, kPeriodCount);
  return ParsedCourse(
    name: name,
    teacher: teacher,
    location: location,
    note: note,
    day: day.clamp(1, 7),
    startPeriod: w,
    endPeriod: e,
    weeks: chunk.weeks,
  );
}

/// 从已展开的虚拟网格解析课程（通用：HTML / docx / xlsx 共用）。
List<ParsedCourse> parseScheduleGrid(List<List<RawCell>> grid,
    {int? headerRow}) {
  if (grid.isEmpty) return [];
  // 1) 定位表头
  var header = headerRow ?? -1;
  if (header < 0) {
    for (var r = 0; r < grid.length && r < 6; r++) {
      final joined = grid[r].map((c) => c.lines.join()).join('|');
      if (joined.contains('节次') || joined.contains('星期')) {
        header = r;
        break;
      }
    }
    if (header < 0) header = 0;
  }
  final headerRowCells = grid[header];

  // 2) 列 → 星期 映射
  final dayMap = <int, int>{};
  final colDays = <int>[]; // 其余未识别列按顺序填入 周一..周日
  for (var c = 0; c < headerRowCells.length; c++) {
    final text = headerRowCells[c].lines.join('');
    final d = parseDayNameFromText(text);
    if (d != null) {
      dayMap[c] = d;
    } else if (!text.contains('节次') &&
        !text.contains('时间') &&
        !text.contains(':') &&
        text.length <= 3) {
      colDays.add(c);
    }
  }
  var nextDay = 1;
  for (final c in colDays) {
    if (!dayMap.containsKey(c)) {
      dayMap[c] = nextDay;
      nextDay = nextDay % 7 + 1;
    }
  }
  if (dayMap.isEmpty) {
    var d = 1;
    for (var c = 1; c < headerRowCells.length && c <= 7; c++) {
      dayMap[c] = d++;
    }
  }

  // 3) 逐行解析
  final result = <ParsedCourse>[];
  for (var r = header + 1; r < grid.length; r++) {
    final row = grid[r];
    final period = _parseRowPeriod(r, header, grid);
    for (final entry in dayMap.entries) {
      final c = entry.key;
      if (c >= row.length) continue;
      final cell = row[c];
      if (cell.isEmpty) continue;
      final endPeriod = period + cell.rowspan - 1;
      for (final chunk in splitEntries(cell.lines)) {
        final pc = fillCourseEntry(chunk, entry.value, period, endPeriod);
        if (pc.name.isNotEmpty) result.add(pc);
      }
    }
  }
  return result;
}

int _parseRowPeriod(int r, int header, List<List<RawCell>> grid) {
  if (grid[r].isEmpty) return r - header;
  final first = grid[r].first;
  final text = first.lines.join('');
  // 形如「第六节」
  final m = RegExp(r'^第([一二三四五六七八九十]{1,2})节').firstMatch(text);
  if (m != null) {
    final n = chineseNumber(m.group(1)!);
    if (n != null) return n;
  }
  // 形如「6」
  final m2 = RegExp(r'^\s*(\d{1,2})').firstMatch(text);
  if (m2 != null) return int.parse(m2.group(1)!);
  return r - header;
}

/// 解析「星期一」「周一」「周日」「星期日」「五」等，返回 1..7 或 null。
int? parseDayNameFromText(String text) {
  if (text.isEmpty) return null;
  const map = {
    '一': 1, '二': 2, '三': 3, '四': 4, '五': 5, '六': 6, '日': 7, '天': 7,
  };
  if (text.contains('星期')) {
    final m = RegExp(r'星期([一二三四五六日天])').firstMatch(text);
    if (m != null) return map[m.group(1)];
  }
  final m = RegExp(r'^(周|星期)([一二三四五六日天])').firstMatch(text.trim());
  if (m != null) return map[m.group(2)];
  if (text.length == 1) return map[text];
  return null;
}
