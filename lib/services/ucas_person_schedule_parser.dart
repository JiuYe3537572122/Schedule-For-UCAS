import 'dart:convert';
import 'dart:typed_data';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// 慕课提示：《课程名》课程学习时间为 A-B。
class MoocNote {
  final String name;
  final DateTime? start;
  final DateTime? end;
  final String raw;
  const MoocNote({required this.name, this.start, this.end, required this.raw});
}

/// 个人课表页（`xkgo.ucas.ac.cn:3000/course/personSchedule`）的解析结果。
class PersonSchedule {
  /// 课程 ID，按页面首次出现顺序去重。
  final List<int> ids;

  /// 课程 ID → 课程名（来自网格里的链接文字）。
  final Map<int, String> names;

  /// 课程 ID → 网格中出现的 (day, period) 集合（所有周次的并集）。
  final Map<int, Set<(int day, int period)>> cells;

  /// 页面标题里的学期名，如「2026年秋季学期」；未识别为空。
  final String semesterLabel;

  final List<MoocNote> moocNotes;

  const PersonSchedule({
    required this.ids,
    required this.names,
    required this.cells,
    required this.semesterLabel,
    required this.moocNotes,
  });

  bool get isEmpty => ids.isEmpty;
}

final RegExp _courseTimeRe = RegExp(r'coursetime/(\d+)');
final RegExp _semesterRe = RegExp(r'(\d{4})年(春季|秋季|夏季)学期');
final RegExp _moocRe = RegExp(
    r'《([^》]+)》\s*课程学习时间为\s*(\d{4})年(\d{1,2})月(\d{1,2})日\s*[-–—~]\s*(\d{4})年(\d{1,2})月(\d{1,2})日');
final RegExp _pureIdRe = RegExp(r'(?<!\d)(\d{4,7})(?!\d)');

/// 判断文件内容是否像 HAR（JSON，含 log.entries）。
bool looksLikeHar(String text) {
  final head = text.trimLeft();
  return head.startsWith('{') && head.contains('"log"') && head.contains('"entries"');
}

/// 从 HAR 文本里取出个人课表页 HTML；找不到返回 null。
String? extractPersonScheduleHtmlFromHar(String harText) {
  Map<String, dynamic> root;
  try {
    root = jsonDecode(harText) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
  final entries = (root['log'] as Map?)?['entries'] as List? ?? const [];
  String? fallback;
  for (final e in entries) {
    if (e is! Map) continue;
    final req = e['request'] as Map?;
    final res = e['response'] as Map?;
    final url = req?['url']?.toString() ?? '';
    final status = (res?['status'] as num?)?.toInt() ?? 0;
    final content = res?['content'] as Map?;
    final text = content?['text']?.toString();
    if (text == null || text.isEmpty) continue;
    final decoded = content?['encoding'] == 'base64'
        ? utf8.decode(base64Decode(text), allowMalformed: true)
        : text;
    if (url.contains('/course/personSchedule') && status == 200) {
      return decoded;
    }
    // 兜底：任何含 coursetime 链接的 HTML
    if (fallback == null &&
        decoded.contains('coursetime/') &&
        decoded.contains('<table')) {
      fallback = decoded;
    }
  }
  return fallback;
}

/// 解析个人课表页 HTML。
PersonSchedule parsePersonScheduleHtml(String html) {
  final doc = html_parser.parse(html);
  final main = doc.querySelector('#main-content') ?? doc.body ?? doc.documentElement!;

  // 学期名
  final title = doc.querySelector('#page-title')?.text ?? main.text;
  final sm = _semesterRe.firstMatch(title);
  final semesterLabel = sm == null ? '' : '${sm.group(1)}年${sm.group(2)}学期';

  // 慕课提示
  final moocNotes = <MoocNote>[];
  for (final alert in main.querySelectorAll('.alert')) {
    for (final m in _moocRe.allMatches(alert.text.replaceAll(' ', ' '))) {
      moocNotes.add(MoocNote(
        name: m.group(1)!.trim(),
        start: DateTime(int.parse(m.group(2)!), int.parse(m.group(3)!), int.parse(m.group(4)!)),
        end: DateTime(int.parse(m.group(5)!), int.parse(m.group(6)!), int.parse(m.group(7)!)),
        raw: m.group(0)!,
      ));
    }
  }

  final ids = <int>[];
  final names = <int, String>{};
  final cells = <int, Set<(int, int)>>{};

  void addLink(dom.Element a, int? day, int? period) {
    final href = a.attributes['href'] ?? '';
    final m = _courseTimeRe.firstMatch(href);
    if (m == null) return;
    final id = int.parse(m.group(1)!);
    if (!ids.contains(id)) ids.add(id);
    final name = a.text.replaceAll(' ', ' ').trim();
    if (name.isNotEmpty) names.putIfAbsent(id, () => name);
    if (day != null && period != null) {
      cells.putIfAbsent(id, () => {}).add((day, period));
    }
  }

  // 网格：<tr><th>节次</th><td>…</td>×7</tr>
  var sawGrid = false;
  for (final tr in main.querySelectorAll('tr')) {
    final th = tr.querySelector('th');
    final period = int.tryParse(th?.text.trim() ?? '');
    final tds = tr.children.where((e) => e.localName == 'td').toList();
    if (period == null || tds.isEmpty) continue;
    sawGrid = true;
    for (var d = 0; d < tds.length && d < 7; d++) {
      for (final a in tds[d].querySelectorAll('a')) {
        addLink(a, d + 1, period);
      }
    }
  }
  // 无网格结构：退化为全文链接扫描
  if (!sawGrid) {
    for (final a in main.querySelectorAll('a')) {
      addLink(a, null, null);
    }
  }

  return PersonSchedule(
    ids: ids,
    names: names,
    cells: cells,
    semesterLabel: semesterLabel,
    moocNotes: moocNotes,
  );
}

/// 统一入口：自动识别 HAR / HTML / MHTML。
PersonSchedule? parsePersonScheduleBytes(Uint8List bytes) {
  var text = utf8.decode(bytes, allowMalformed: true);
  if (looksLikeHar(text)) {
    final html = extractPersonScheduleHtmlFromHar(text);
    if (html == null) return null;
    return parsePersonScheduleHtml(html);
  }
  // MHTML：截取 HTML 部分
  if (text.startsWith('Mime-Version') || text.contains('Content-Type: text/html')) {
    final start = [text.indexOf('<!DOCTYPE'), text.indexOf('<html')]
        .where((i) => i >= 0)
        .fold<int>(-1, (a, b) => a < 0 ? b : (b < a ? b : a));
    if (start >= 0) {
      final end = text.indexOf('--NEXT.ITEM-BOUNDARY', start);
      text = text.substring(start, end > start ? end : text.length);
    }
    // quoted-printable 软换行
    text = text.replaceAll('=\r\n', '').replaceAll('=\n', '');
  }
  if (!text.contains('coursetime/')) return null;
  return parsePersonScheduleHtml(text);
}

/// 从任意文本（粘贴的链接 / 口令 / 纯数字）提取课程 ID。
List<int> extractCourseIds(String text) {
  final ids = <int>[];
  void add(int id) {
    if (!ids.contains(id)) ids.add(id);
  }
  final linkMatches = _courseTimeRe.allMatches(text).toList();
  if (linkMatches.isNotEmpty) {
    for (final m in linkMatches) {
      add(int.parse(m.group(1)!));
    }
    return ids;
  }
  for (final m in _pureIdRe.allMatches(text)) {
    add(int.parse(m.group(1)!));
  }
  return ids;
}

/// 课表口令前缀。
const String kShareTokenPrefix = 'guoxiaoke:';

String buildShareToken(Iterable<int> ids) => '$kShareTokenPrefix${ids.join(',')}';
