import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:class_manager/screens/personalization_screen.dart';
import 'package:class_manager/state/app_state.dart';

/// 个性化页新增项：显示网格开关、个人姓名输入。
void main() {
  Future<AppState> pumpPersonalization(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final state = AppState.memory();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: PersonalizationScreen()),
      ),
    );
    await tester.pump();
    return state;
  }

  testWidgets('显示网格开关可切换', (WidgetTester tester) async {
    final state = await pumpPersonalization(tester);

    expect(find.text('显示网格'), findsOneWidget);
    expect(state.settings.showGrid, isTrue, reason: '默认显示网格');

    // 按标题定位开关（大卡片第一行）
    final gridSwitch = find.descendant(
      of: find
          .ancestor(of: find.text('显示网格'), matching: find.byType(Row))
          .first,
      matching: find.byType(Switch),
    );
    await tester.tap(gridSwitch);
    await tester.pump();
    expect(state.settings.showGrid, isFalse);

    await tester.tap(gridSwitch);
    await tester.pump();
    expect(state.settings.showGrid, isTrue);
  });

  testWidgets('个人姓名可输入并保存', (WidgetTester tester) async {
    final state = await pumpPersonalization(tester);

    expect(find.text('个人姓名'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '闫梓萱');
    await tester.pump();
    expect(state.settings.userName, '闫梓萱');
  });
}
