import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:class_manager/services/ucas_bitmask.dart';
import 'package:class_manager/services/ucas_course_resolver.dart';

/// 选课系统 coursetime JSON 位掩码解码。
void main() {
  group('位掩码基本规则', () {
    test('星期 = courseTime >> 13，低 13 位为节次', () {
      // 自然语言处理：周一 1-3 节
      expect(ucasDayOf(8199), 1);
      expect(ucasPeriodsOf(8199), [1, 2, 3]);
      // 周三 6-8 节
      expect(ucasDayOf(24800), 3);
      expect(ucasPeriodsOf(24800), [6, 7, 8]);
    });

    test('周次逐位对应', () {
      expect(ucasWeeksOf(1047552), List.generate(10, (i) => 11 + i));
      expect(ucasWeeksOf(32), [6]);
      expect(ucasWeeksOf(0), isEmpty);
    });

    test('第 13 节与周日可正确编码解码', () {
      final t = ucasEncodeTime(7, [12, 13]);
      expect(ucasDayOf(t), 7);
      expect(ucasPeriodsOf(t), [12, 13]);
      // 集成电路与SOC设计基础：周一 12-13 节 = 14336
      expect(ucasDayOf(14336), 1);
      expect(ucasPeriodsOf(14336), [12, 13]);
      expect(ucasEncodeWeeks([11, 12, 13, 14, 15, 16, 17, 18, 19, 20]), 1047552);
    });

    test('不连续节次拆分', () {
      expect(splitRuns([1, 2, 5, 6]), [[1, 2], [5, 6]]);
      expect(splitRuns([3]), [[3]]);
      expect(splitRuns([]), isEmpty);
    });

    test('非法数据返回 null', () {
      expect(decodeUcasSlot({'courseTime': 0, 'courseWeek': 1}), isNull);
      expect(decodeUcasSlot({'courseTime': 'x', 'courseWeek': 1}), isNull);
      expect(decodeUcasSlot({'courseTime': 8 << 13 | 1, 'courseWeek': 1}), isNull, reason: '星期 8 非法');
    });
  });

  group('真实 JSON 夹具', () {
    Map<String, dynamic> load(String name) => jsonDecode(
        File('test/fixtures/ucas/$name').readAsStringSync()) as Map<String, dynamic>;

    test('314787 自然语言处理：两个时段，11-20 周', () {
      final rc = UcasCourseResolver.parseCourseTimeJson(314787, load('coursetime_314787.json'));
      expect(rc.name, '自然语言处理');
      expect(rc.courseCode, '280216085404P2009');
      expect(rc.slots.length, 2);
      expect(rc.slots[0].day, 1);
      expect(rc.slots[0].periods, [1, 2, 3]);
      expect(rc.slots[0].weeks, List.generate(10, (i) => 11 + i));
      expect(rc.slots[0].place, '5号楼4层多功能厅');
      expect(rc.slots[1].day, 3);
      expect(rc.slots[1].periods, [6, 7, 8]);
      expect(rc.term?.firstDay, DateTime(2026, 8, 31));
      expect(rc.term?.shortName, '2026年秋季学期');
      expect(rc.term?.id, 89576);

      final parsed = rc.toParsedCourses(maxWeek: 20);
      expect(parsed.length, 2);
      expect(parsed[0].weeks, '11-20');
      expect(parsed[0].startPeriod, 1);
      expect(parsed[0].endPeriod, 3);
      expect(parsed[0].sourceId, 314787);
      expect(parsed[0].courseCode, '280216085404P2009');
    });

    test('314780 古无脊椎动物学：三个时段，含周六', () {
      final rc = UcasCourseResolver.parseCourseTimeJson(314780, load('coursetime_314780.json'));
      expect(rc.slots.length, 3);
      expect(rc.slots.map((s) => s.day).toList(), [3, 5, 6]);
      expect(rc.slots[2].periods, [1, 2]);
      expect(rc.slots[2].weeks, [6]);
    });

    test('314781 古植物学：不同时段地点不同', () {
      final rc = UcasCourseResolver.parseCourseTimeJson(314781, load('coursetime_314781.json'));
      expect(rc.slots.map((s) => s.place).toSet(), {'A203', '户外实践'});
    });

    test('我的课表 9 门课全部可解码且属于 2026 秋', () {
      final dir = Directory('test/fixtures/ucas/my_schedule');
      final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList();
      expect(files.length, 9);
      var slots = 0;
      for (final f in files) {
        final id = int.parse(RegExp(r'coursetime_(\d+)').firstMatch(f.path)!.group(1)!);
        final rc = UcasCourseResolver.parseCourseTimeJson(
            id, jsonDecode(f.readAsStringSync()) as Map<String, dynamic>);
        expect(rc.courseId, id);
        expect(rc.hasSchedule, isTrue, reason: '$id 应有时间安排');
        expect(rc.term?.firstDay, DateTime(2026, 8, 31));
        for (final s in rc.slots) {
          expect(s.day, inInclusiveRange(1, 7));
          expect(s.periods.first, greaterThanOrEqualTo(1));
          expect(s.periods.last, lessThanOrEqualTo(13));
          expect(s.weeks.last, lessThanOrEqualTo(20));
        }
        slots += rc.slots.length;
      }
      expect(slots, 12);
    });
  });

  group('HTML 离线兜底解析', () {
    test('HTML 与 JSON 解码结果一致', () {
      for (final id in [314787, 314780, 314781, 314785]) {
        final json = jsonDecode(File('test/fixtures/ucas/coursetime_$id.json').readAsStringSync())
            as Map<String, dynamic>;
        final html = File('test/fixtures/ucas/coursetime_$id.html').readAsStringSync();
        final a = UcasCourseResolver.parseCourseTimeJson(id, json);
        final b = UcasCourseResolver.parseCourseTimeHtml(id, html);
        expect(b.name, a.name, reason: '$id 课程名');
        expect(b.slots.length, a.slots.length, reason: '$id 时段数');
        for (var i = 0; i < a.slots.length; i++) {
          expect(b.slots[i].day, a.slots[i].day);
          expect(b.slots[i].periods, a.slots[i].periods);
          expect(b.slots[i].weeks, a.slots[i].weeks);
          expect(b.slots[i].place, a.slots[i].place);
        }
        expect(b.term?.shortName, '2026年秋季学期');
      }
    });
  });
}
