import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:class_manager/screens/personalization_screen.dart';
import 'package:class_manager/state/app_state.dart';

/// 按标题定位大卡片中的开关。
Finder switchOf(String title) => find.descendant(
      of: find.ancestor(of: find.text(title), matching: find.byType(Row)).first,
      matching: find.byType(Switch),
    );

/// 液态玻璃开关：可在「玻璃卡片」与「高斯模糊卡片」之间切换，
/// 切换过程不产生布局异常。
void main() {
  testWidgets('液态玻璃开关可切换且页面无异常', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final state = AppState.memory(); // liquidGlass 默认 true
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: PersonalizationScreen()),
      ),
    );
    await tester.pump();

    expect(state.settings.liquidGlass, isTrue);

    // 关闭液态玻璃 → 卡片改为普通高斯模糊
    await tester.tap(switchOf('液态玻璃'));
    await tester.pump();
    expect(state.settings.liquidGlass, isFalse);
    expect(tester.takeException(), isNull);

    // 再次打开 → 恢复玻璃卡片
    await tester.tap(switchOf('液态玻璃'));
    await tester.pump();
    expect(state.settings.liquidGlass, isTrue);
    expect(tester.takeException(), isNull);
  });
}
