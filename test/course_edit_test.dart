import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:class_manager/main.dart';
import 'package:class_manager/models/course.dart';
import 'package:class_manager/models/semester.dart';
import 'package:class_manager/state/app_state.dart';

/// 课程页：详情模式下名称 / 教师 / 地点 / 上课安排只读，只有备注与颜色可改；
/// 手动课程可经「修改信息」进入完整编辑；新增与删除照常。
void main() {
  Future<AppState> pumpWith(WidgetTester tester, List<Course> courses) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final state = AppState.memory();
    state.browseWeek = 1;
    for (final c in courses) {
      await state.addCourse(c);
    }
    await tester.pumpWidget(ClassManagerApp(state: state));
    await tester.pump();
    return state;
  }

  testWidgets('选课系统课程：全部客观信息只读，仅备注与颜色可改', (WidgetTester tester) async {
    final state = await pumpWith(tester, [
      Course(
          name: '自然语言处理',
          location: '5号楼4层多功能厅',
          day: 1,
          startPeriod: 1,
          endPeriod: 3,
          weeks: '',
          semesterKey: kDefaultSemesterKey,
          sourceId: 314787,
          courseCode: '280216085404P2009'),
    ]);

    await tester.tap(find.text('自然语言处理'));
    await tester.pumpAndSettle();

    expect(find.text('课程详情'), findsOneWidget);
    expect(find.text('自然语言处理'), findsOneWidget);
    expect(find.text('5号楼4层多功能厅'), findsOneWidget);
    expect(find.text('选课系统未提供'), findsOneWidget, reason: '教师为空时的客观提示');
    expect(find.text('周一 · 第一~三节'), findsOneWidget);
    expect(find.text('08:30~11:10'), findsOneWidget);
    expect(find.text('全周'), findsOneWidget);
    expect(find.textContaining('来自选课系统'), findsOneWidget);
    // 只有「备注」一个输入框；没有修改入口与周次选择
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('修改信息'), findsNothing);
    expect(find.text('全部'), findsNothing);

    await tester.enterText(find.byType(TextField), '周三那节在机房');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final c = state.currentCourses.single;
    expect(c.note, '周三那节在机房');
    expect((c.name, c.location, c.day, c.startPeriod, c.endPeriod, c.weeks),
        ('自然语言处理', '5号楼4层多功能厅', 1, 1, 3, ''), reason: '客观信息不变');
    expect(find.text('自然语言处理'), findsOneWidget, reason: '回到课表');
  });

  testWidgets('手动课程：点「修改信息」后可改名称与星期并保存', (WidgetTester tester) async {
    final state = await pumpWith(tester, [
      Course(name: '自习', day: 1, startPeriod: 5, endPeriod: 6, weeks: '', semesterKey: kDefaultSemesterKey),
    ]);

    await tester.tap(find.text('自习'));
    await tester.pumpAndSettle();
    expect(find.text('周一 · 第五~六节'), findsOneWidget);
    expect(find.text('修改信息'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget, reason: '详情模式只有备注输入框');

    await tester.tap(find.text('修改信息'));
    await tester.pumpAndSettle();
    expect(find.text('修改课程'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(4), reason: '名称 / 教师 / 地点 / 备注');
    expect(find.text('全部'), findsOneWidget, reason: '显示周次选择');

    await tester.enterText(find.byType(TextField).first, '晚自习');
    await tester.tap(find.text('三')); // 星期三
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final c = state.currentCourses.single;
    expect(c.name, '晚自习');
    expect(c.day, 3);
    expect(find.text('晚自习'), findsOneWidget);
  });

  testWidgets('新增课程与删除课程', (WidgetTester tester) async {
    final state = await pumpWith(tester, const []);

    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('添加课程'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(4));
    expect(find.text('全部'), findsOneWidget, reason: '新增时为完整编辑器');

    await tester.enterText(find.byType(TextField).first, '新课程');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(state.currentCourses.length, 1);
    expect(find.text('新课程'), findsOneWidget);

    await tester.tap(find.text('新课程'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('删除课程'));
    await tester.tap(find.text('删除课程'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(state.currentCourses, isEmpty);
    expect(find.text('新课程'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
