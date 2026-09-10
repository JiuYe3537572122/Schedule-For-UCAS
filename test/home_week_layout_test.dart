import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:class_manager/main.dart';
import 'package:class_manager/models/course.dart';
import 'package:class_manager/models/semester.dart';
import 'package:class_manager/screens/home_screen.dart';
import 'package:class_manager/state/app_state.dart';

/// 主页全周课表：
/// 1) 13 节课必须在首屏完整显示（无需上下滚动）；
/// 2) 课表底部与悬浮导航栏的间距保持紧凑（参考图约 20~30px），不留大片空白。
void main() {
  Future<void> pumpAt(WidgetTester tester, Size logical) async {
    tester.view.physicalSize = logical * 3;
    tester.view.devicePixelRatio = 3.0;
    final state = AppState.memory();
    state.browseWeek = 1;
    state.courses = [
      Course(
          name: '晚课',
          day: 1,
          startPeriod: 12,
          endPeriod: 13,
          weeks: '1-16',
          colorValue: 0xFF3FC9A2,
          semesterKey: kDefaultSemesterKey),
    ];
    await tester.pumpWidget(ClassManagerApp(state: state));
    await tester.pump();
  }

  testWidgets('手机竖屏：13 节一屏 + 底部紧贴导航栏', (WidgetTester tester) async {
    addTearDown(tester.view.reset);
    await pumpAt(tester, const Size(390, 844));

    expect(tester.takeException(), isNull);

    final last = tester.getRect(find.text('21:05\n21:50'));
    expect(last.bottom, lessThanOrEqualTo(844.0),
        reason: '第 13 节应在首屏可见，实际底部 ${last.bottom}');

    final nav = tester.getRect(find.byKey(const ValueKey('bottom_nav')));
    final gap = nav.top - last.bottom;
    expect(gap, inInclusiveRange(2, 40),
        reason: '课表底部与导航栏间距应紧凑（参考图约 25px），实际 $gap');

    expect(find.text('主页'), findsOneWidget);
    expect(find.text('周一'), findsOneWidget);
    expect(find.text('周日'), findsOneWidget);
  });

  testWidgets('桌面窗口：13 节一屏 + 底部紧贴导航栏', (WidgetTester tester) async {
    addTearDown(tester.view.reset);
    await pumpAt(tester, const Size(1262, 670));

    expect(tester.takeException(), isNull);

    final last = tester.getRect(find.text('21:05\n21:50'));
    expect(last.bottom, lessThanOrEqualTo(670.0),
        reason: '第 13 节应在首屏可见，实际底部 ${last.bottom}');

    final nav = tester.getRect(find.byKey(const ValueKey('bottom_nav')));
    final gap = nav.top - last.bottom;
    expect(gap, inInclusiveRange(2, 40),
        reason: '课表底部与导航栏间距应紧凑，实际 $gap');
  });

  testWidgets('显示网格开关控制课表网格', (WidgetTester tester) async {
    addTearDown(tester.view.reset);

    final state = AppState.memory();
    state.browseWeek = 1;
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    await tester.pumpWidget(ClassManagerApp(state: state));
    await tester.pump();

    // 网格由单个 CustomPaint 绘制，开关通过 showGrid 传入
    ScheduleGrid grid() => tester.widget<ScheduleGrid>(find.byType(ScheduleGrid).first);
    expect(find.byType(ScheduleGrid), findsWidgets);
    expect(grid().showGrid, isTrue, reason: '默认显示网格');

    await state.updateSettings(state.settings.copyWith(showGrid: false));
    await tester.pump();
    expect(grid().showGrid, isFalse, reason: '关闭后不绘制网格');

    await state.updateSettings(state.settings.copyWith(showGrid: true));
    await tester.pump();
    expect(grid().showGrid, isTrue);
  });
}
