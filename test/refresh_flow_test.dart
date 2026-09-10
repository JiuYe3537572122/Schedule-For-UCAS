import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:class_manager/main.dart';
import 'package:class_manager/models/course.dart';
import 'package:class_manager/models/semester.dart';
import 'package:class_manager/screens/import_preview_screen.dart';
import 'package:class_manager/services/ucas_course_resolver.dart';
import 'package:class_manager/state/app_state.dart';

/// 「刷新课表」：进度弹窗在补全结束后关闭，不得触发 Navigator 断言，也不得多弹一次 pop。
void main() {
  testWidgets('刷新课表：补全成功后关闭弹窗并更新课程', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final fixture = File('test/fixtures/ucas/my_schedule/coursetime_314787.json').readAsStringSync();
    ucasResolverFactory = () => UcasCourseResolver(
          fetch: (uri) async {
            await Future<void>.delayed(const Duration(milliseconds: 300));
            return (200, fixture);
          },
        );
    addTearDown(() => ucasResolverFactory = () => UcasCourseResolver());

    final state = AppState.memory();
    state.browseWeek = 1;
    await state.addCourse(Course(
        name: '自然语言处理（旧）',
        day: 5,
        startPeriod: 1,
        endPeriod: 2,
        weeks: '1-8',
        semesterKey: kDefaultSemesterKey,
        sourceId: 314787,
        colorValue: 0xFF112233));

    await tester.pumpWidget(ClassManagerApp(state: state));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('刷新课表'));
    await tester.pump(); // 关闭菜单 + 打开进度弹窗
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(AlertDialog), findsOneWidget, reason: '应显示进度弹窗');

    // 推进时间让补全完成、弹窗关闭
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final e = tester.takeException();
      expect(e, isNull, reason: '第 $i 帧出现异常: $e');
    }

    expect(find.byType(AlertDialog), findsNothing, reason: '弹窗应已关闭');
    expect(find.text('周一'), findsOneWidget, reason: '主页仍在');
    // 课程已被替换为接口数据：周一 1-3 节 + 周三 6-8 节，颜色保留
    final courses = state.currentCourses;
    expect(courses.length, 2);
    expect(courses.every((c) => c.colorValue == 0xFF112233), isTrue);
    expect(courses.map((c) => c.day).toSet(), {1, 3});
    expect(find.textContaining('已刷新'), findsOneWidget);
  });
}
