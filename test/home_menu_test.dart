import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:class_manager/main.dart';
import 'package:class_manager/state/app_state.dart';

/// 主页菜单弹层：导入课表 / 添加课程 / 学期，
/// 「刷新课表」仅在有选课系统课程时出现。
void main() {
  testWidgets('主页菜单不包含个性化设置与关于', (WidgetTester tester) async {
    final state = AppState.memory();
    state.browseWeek = 1;

    await tester.pumpWidget(ClassManagerApp(state: state));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    expect(find.textContaining('导入课表'), findsOneWidget);
    expect(find.text('添加课程'), findsOneWidget);
    expect(find.textContaining('学期（'), findsOneWidget);
    expect(find.textContaining('刷新课表'), findsNothing,
        reason: '没有来自选课系统的课程时不显示刷新');
    expect(find.text('个性化设置'), findsNothing);
  });
}
