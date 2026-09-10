import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:class_manager/services/ucas_course_resolver.dart';

/// 在线补全 Resolver：注入假抓取函数，测试并发、重试、失败分类。
void main() {
  String fixture(int id) => File('test/fixtures/ucas/my_schedule/coursetime_$id.json').readAsStringSync();

  test('全部成功：保持输入顺序，学期取自 term', () async {
    final calls = <int>[];
    final resolver = UcasCourseResolver(
      fetch: (uri) async {
        final id = int.parse(RegExp(r'(\d+)\.json').firstMatch(uri.path)!.group(1)!);
        calls.add(id);
        return (200, fixture(id));
      },
      concurrency: 3,
    );
    final progress = <int>[];
    final report = await resolver.resolve([315004, 314787, 314784],
        onProgress: (d, t) => progress.add(d));
    expect(report.courses.map((c) => c.courseId).toList(), [315004, 314787, 314784]);
    expect(report.errors, isEmpty);
    expect(report.term?.firstDay, DateTime(2026, 8, 31));
    expect(progress, [1, 2, 3]);
    expect(calls.toSet(), {315004, 314787, 314784});
  });

  test('重复 ID 去重；404 / 非 JSON / 登录页 / 网络异常分别归类', () async {
    var attempts = 0;
    final resolver = UcasCourseResolver(fetch: (uri) async {
      final id = int.parse(RegExp(r'(\d+)\.json').firstMatch(uri.path)!.group(1)!);
      switch (id) {
        case 314787:
          return (200, fixture(314787));
        case 1:
          return (404, '');
        case 2:
          return (200, '<html><body>Error 不存在</body></html>');
        case 3:
          return (200, '<html><body>登录失败！请重新登录</body></html>');
        case 4:
          attempts++;
          throw const SocketException('offline');
        default:
          return (200, '{}');
      }
    });
    final report = await resolver.resolve([314787, 314787, 1, 2, 3, 4, 5]);
    expect(report.courses.length, 2, reason: '314787 与 5（空 JSON，无时间）');
    final kinds = {for (final e in report.errors) e.courseId: e.kind};
    expect(kinds[1], ResolveFailure.notFound);
    expect(kinds[2], ResolveFailure.notFound);
    expect(kinds[3], ResolveFailure.loginRequired);
    expect(kinds[4], ResolveFailure.network);
    expect(attempts, 2, reason: '网络异常重试一次');
    expect(report.loginWall, isTrue);
    final empty = report.courses.firstWhere((c) => c.courseId == 5);
    expect(empty.hasSchedule, isFalse);
  });

  test('parseCourseTimeJson 容忍字符串数字与缺失 course 对象', () {
    final rc = UcasCourseResolver.parseCourseTimeJson(9, {
      'courseTimeList': [
        {'courseTime': '8199', 'courseWeek': '7', 'courseName': '测试课', 'coursePlace': 'A1'},
      ],
    });
    expect(rc.courseId, 9);
    expect(rc.name, '测试课');
    expect(rc.slots.single.day, 1);
    expect(rc.slots.single.weeks, [1, 2, 3]);
    expect(rc.toParsedCourses(maxWeek: 20).single.weeks, '1-3');
  });

  test('toParsedCourses 全周压缩与不连续节次拆分', () {
    final json = jsonDecode(fixture(314787)) as Map<String, dynamic>;
    // 改造：周次覆盖 1-20 → 全周；节次 1,2,5,6 → 两段
    final list = (json['courseTimeList'] as List).cast<Map<String, dynamic>>();
    list[0]['courseWeek'] = (1 << 20) - 1;
    list[0]['courseTime'] = (1 << 13) | 51; // 节次 1,2,5,6
    final rc = UcasCourseResolver.parseCourseTimeJson(314787, json);
    final parsed = rc.toParsedCourses(maxWeek: 20);
    expect(parsed.length, 3);
    expect(parsed[0].weeks, '', reason: '1-20 周 = 全周');
    expect((parsed[0].startPeriod, parsed[0].endPeriod), (1, 2));
    expect((parsed[1].startPeriod, parsed[1].endPeriod), (5, 6));
  });
}
