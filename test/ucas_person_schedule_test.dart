import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:class_manager/screens/import_preview_screen.dart';
import 'package:class_manager/services/ucas_person_schedule_parser.dart';

/// 个人课表页（personSchedule）解析：HTML / HAR / 粘贴文本。
void main() {
  final html = File('test/fixtures/ucas/personSchedule_sample.html').readAsStringSync();

  test('从 HTML 提取 9 个课程 ID（按首次出现顺序）', () {
    final ps = parsePersonScheduleHtml(html);
    expect(ps.ids,
        [314787, 314784, 315481, 318126, 315004, 314921, 315472, 315492, 315527]);
    expect(ps.names[314787], '自然语言处理');
    expect(ps.names[315527], '学术道德与学术写作规范-02班');
    expect(ps.semesterLabel, '2026年秋季学期');
  });

  test('网格格子：34 个，自然语言处理为周一 1-3 + 周三 6-8', () {
    final ps = parsePersonScheduleHtml(html);
    final total = ps.cells.values.fold<int>(0, (a, b) => a + b.length);
    expect(total, 34);
    expect(ps.cells[314787], {(1, 1), (1, 2), (1, 3), (3, 6), (3, 7), (3, 8)});
    expect(ps.cells[315004], {(3, 3), (3, 4), (2, 12), (2, 13)});
  });

  test('慕课提示解析出两门课与日期', () {
    final ps = parsePersonScheduleHtml(html);
    expect(ps.moocNotes.length, 2);
    expect(ps.moocNotes[0].name, '硕士学位英语(慕课学习)');
    expect(ps.moocNotes[0].start, DateTime(2026, 9, 7));
    expect(ps.moocNotes[0].end, DateTime(2026, 12, 7));
    expect(ps.moocNotes[1].name, '工程伦理(慕课)');
    expect(ps.moocNotes[1].end, DateTime(2026, 11, 22));
  });

  test('离线网格 → 课程（周次全周，节次按连续段拆分）', () {
    final ps = parsePersonScheduleHtml(html);
    final list = offlineCoursesFromCells(314787, ps.names[314787]!, ps.cells[314787]!);
    expect(list.length, 2);
    expect(list[0].day, 1);
    expect(list[0].startPeriod, 1);
    expect(list[0].endPeriod, 3);
    expect(list[0].weeks, '');
    expect(list[1].day, 3);
    expect(list[1].startPeriod, 6);
    expect(list[1].endPeriod, 8);
    expect(list[0].sourceId, 314787);
  });

  test('HAR 包装：取出 personSchedule 条目', () {
    final har = jsonEncode({
      'log': {
        'entries': [
          {
            'request': {'url': 'https://xkgo.ucas.ac.cn:3000/static/base.css'},
            'response': {'status': 200, 'content': {'text': 'body{}', 'mimeType': 'text/css'}},
          },
          {
            'request': {'url': 'https://xkgo.ucas.ac.cn:3000/course/personSchedule'},
            'response': {
              'status': 200,
              'content': {'text': base64Encode(utf8.encode(html)), 'encoding': 'base64'},
            },
          },
        ],
      },
    });
    expect(looksLikeHar(har), isTrue);
    final ps = parsePersonScheduleBytes(Uint8List.fromList(utf8.encode(har)));
    expect(ps, isNotNull);
    expect(ps!.ids.length, 9);
  });

  test('parsePersonScheduleBytes 对纯 HTML 同样有效；无链接时返回 null', () {
    final ps = parsePersonScheduleBytes(Uint8List.fromList(utf8.encode(html)));
    expect(ps?.ids.length, 9);
    expect(parsePersonScheduleBytes(Uint8List.fromList(utf8.encode('<html><body>nothing</body></html>'))), isNull);
  });

  test('粘贴文本：链接优先，其次纯数字；口令格式', () {
    expect(extractCourseIds('https://xkcts.ucas.ac.cn:8443/course/coursetime/314787\nhttps://xkcts.ucas.ac.cn:8443/course/coursetime/314784'),
        [314787, 314784]);
    expect(extractCourseIds('guoxiaoke:314787,314784,314787'), [314787, 314784]);
    expect(extractCourseIds('314787 315004、318126'), [314787, 315004, 318126]);
    expect(extractCourseIds('没有数字'), isEmpty);
    expect(buildShareToken([1, 2]), 'guoxiaoke:1,2');
  });
}
