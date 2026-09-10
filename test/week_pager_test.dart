import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:class_manager/main.dart';
import 'package:class_manager/screens/home_screen.dart';
import 'package:class_manager/state/app_state.dart';

/// 主页周次切换：上下拖动翻页（向上拖动 → 下一周，向下拖动 → 上一周），
/// 翻页时当前页与相邻页同时整页滑动。
void main() {
  testWidgets('上下拖动切换周次', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final state = AppState.memory();
    state.browseWeek = 5;

    await tester.pumpWidget(ClassManagerApp(state: state));
    await tester.pump();

    expect(find.text('5'), findsWidgets);

    // 拖动过程中：新旧两页同时渲染（整页滑动，无淡出）
    final before = tester.widget<FullWeekSchedule>(find.byType(FullWeekSchedule).first);
    final gesture =
        await tester.startGesture(tester.getCenter(find.text('周一')));
    await gesture.moveBy(const Offset(0, -60));
    await tester.pump();
    expect(find.byType(FullWeekSchedule), findsNWidgets(2),
        reason: '翻页过程中应同时渲染当前页与相邻页');
    // 性能保证：拖动只改变平移量，当前页组件实例不应被重建
    final during = tester
        .widgetList<FullWeekSchedule>(find.byType(FullWeekSchedule))
        .firstWhere((w) => w.week == 5);
    expect(identical(before, during), isTrue, reason: '拖动期间课表页应复用同一实例');
    await gesture.moveBy(const Offset(0, -40));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(state.browseWeek, 5, reason: '小幅拖动应回弹，不切周');

    // 向上快速拖动 → 下一周
    await tester.fling(find.text('周一'), const Offset(0, -220), 1200);
    await tester.pumpAndSettle();
    expect(state.browseWeek, 6, reason: '向上拖动应翻到下一周');

    // 向下快速拖动 → 上一周
    await tester.fling(find.text('周一'), const Offset(0, 220), 1200);
    await tester.pumpAndSettle();
    expect(state.browseWeek, 5, reason: '向下拖动应翻回上一周');

    // 首周不能再往上翻
    state.setBrowseWeek(1);
    await tester.pumpAndSettle();
    await tester.fling(find.text('周一'), const Offset(0, 220), 1200);
    await tester.pumpAndSettle();
    expect(state.browseWeek, 1, reason: '第 1 周向下拖动应保持不动');
  });

  testWidgets('回到本周：逐周滑动返回', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final state = AppState.memory();
    state.browseWeek = 6; // 当前周为第 1 周（默认开学日期）

    await tester.pumpWidget(ClassManagerApp(state: state));
    await tester.pump();

    expect(find.text('回到本周'), findsOneWidget);

    await tester.tap(find.text('回到本周'));
    await tester.pump(); // 启动逐周回跳

    // 中途应处于两页滑动状态（说明是连续滑动而非瞬间跳转）
    await tester.pump(const Duration(milliseconds: 120));
    expect(state.browseWeek, lessThan(6), reason: '应逐周回跳');

    await tester.pumpAndSettle();
    expect(state.browseWeek, state.currentWeek, reason: '最终回到本周');
    expect(find.text('回到本周'), findsNothing, reason: '已在本周，按钮隐藏');
  });
}
