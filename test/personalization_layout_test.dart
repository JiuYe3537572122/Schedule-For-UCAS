import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:class_manager/screens/personalization_screen.dart';
import 'package:class_manager/state/app_state.dart';

/// 个性化页布局回归：所有调节项位于同一张卡片内、行与行之间用细线分隔、
/// 行高适中（不粘连）。
void main() {
  testWidgets('个性化大卡片：一行一项、行高充足、无溢出', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = AppState.memory();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: PersonalizationScreen()),
      ),
    );
    await tester.pump();

    // 不允许任何布局溢出/异常
    expect(tester.takeException(), isNull);

    // 第一行（背景模糊）与第二行（卡片透明）的顶部间距 = 行高
    final bg = tester.getTopLeft(find.text('背景模糊'));
    final card = tester.getTopLeft(find.text('卡片透明'));
    final sliderRowHeight = card.dy - bg.dy;
    expect(sliderRowHeight, greaterThan(64),
        reason: '滑杆行高应充足（约 70px），实际 $sliderRowHeight');

    // 开关行（液态玻璃）紧随其后，同样有足够间距
    final glass = tester.getTopLeft(find.text('液态玻璃'));
    expect(glass.dy - card.dy, greaterThan(64),
        reason: '开关行高应充足，实际 ${glass.dy - card.dy}');

    // 最后一行（色散）可见，整卡完整；沉浸式背景选项已移除
    expect(find.text('色散'), findsOneWidget);
    expect(find.text('沉浸式背景'), findsNothing);
    expect(find.text('背景图片'), findsOneWidget);
  });
}
