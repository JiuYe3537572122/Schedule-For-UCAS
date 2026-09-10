import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:class_manager/main.dart';
import 'package:class_manager/models/exam.dart';
import 'package:class_manager/state/app_state.dart';

void main() {
  testWidgets('开学日期选择器为中文', (WidgetTester tester) async {
    final state = AppState.memory();
    await tester.pumpWidget(ClassManagerApp(state: state));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('学期（'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('修改当前学期开学日期'));
    await tester.pumpAndSettle();

    expect(find.text('取消'), findsOneWidget, reason: '日期选择器应为中文（取消）');
    expect(find.text('确定'), findsOneWidget, reason: '日期选择器应为中文（确定）');
  });

  testWidgets('已结束考试展开动画', (WidgetTester tester) async {
    final state = AppState.memory();
    state.exams = [
      Exam(
          name: '线性代数',
          location: '博3-B401',
          date: '2023-11-11',
          startTime: '19:00',
          endTime: '20:40'),
    ];

    await tester.pumpWidget(ClassManagerApp(state: state));
    await tester.pump();
    await tester.tap(find.text('发现'));
    await tester.pumpAndSettle();

    AnimatedCrossFade panel() => tester
        .widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade).first);

    expect(panel().crossFadeState, CrossFadeState.showFirst,
        reason: '默认折叠');

    await tester.ensureVisible(find.textContaining('已结束考试'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('已结束考试'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    final mid = tester.getSize(find.byType(AnimatedCrossFade).first).height;

    await tester.pumpAndSettle();
    final full = tester.getSize(find.byType(AnimatedCrossFade).first).height;

    expect(panel().crossFadeState, CrossFadeState.showSecond, reason: '展开后显示列表');
    expect(mid, greaterThan(0), reason: '展开过程中高度应逐渐增长');
    expect(full, greaterThan(mid), reason: '展开动画应丝滑过渡到完整高度');
  });
}
