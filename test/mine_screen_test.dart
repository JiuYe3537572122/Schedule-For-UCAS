import 'package:flutter_test/flutter_test.dart';

import 'package:class_manager/main.dart';
import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/utils/greeting.dart';

/// “我的”页：问候语 + 校区 + 个性化入口 + 「关于果小课 / 隐私政策」。
void main() {
  Future<void> openMine(WidgetTester tester) async {
    final state = AppState.memory();
    state.browseWeek = 1;
    await tester.pumpWidget(ClassManagerApp(state: state));
    await tester.pump();
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
  }

  testWidgets('我的页：按时间与姓名问候', (WidgetTester tester) async {
    final state = AppState.memory();
    state.browseWeek = 1;
    await state.updateSettings(state.settings.copyWith(userName: '小果'));

    await tester.pumpWidget(ClassManagerApp(state: state));
    await tester.pump();
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();

    final greeting = greetingFor(DateTime.now());
    expect(find.text(greeting.withName('小果')), findsOneWidget);
    expect(find.textContaining(greeting.reminder), findsOneWidget);
  });

  testWidgets('我的页：未填姓名时只显示时段问候，并显示校区', (WidgetTester tester) async {
    await openMine(tester);
    final greeting = greetingFor(DateTime.now());
    expect(find.text(greeting.hello), findsOneWidget);
    expect(find.text('国科大杭州高等研究院'), findsOneWidget);
  });

  testWidgets('我的页：只保留个性化、关于、隐私政策', (WidgetTester tester) async {
    await openMine(tester);

    expect(find.text('个性化设置'), findsOneWidget);
    expect(find.text('关于$kAppName'), findsOneWidget);
    expect(find.text('隐私政策'), findsOneWidget);

    // 已删除的入口
    expect(find.text('联系作者'), findsNothing);
    expect(find.text('检查更新'), findsNothing);
    expect(find.text('获取源码'), findsNothing);
    expect(find.text('开学日期'), findsNothing);
  });

  testWidgets('关于果小课：说明来源与致谢', (WidgetTester tester) async {
    await openMine(tester);
    await tester.tap(find.text('关于$kAppName'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Schedule-For-WHU'), findsOneWidget);
    expect(find.textContaining('中国科学院院徽'), findsOneWidget);
  });

  testWidgets('隐私政策：说明登录只发给 SEP、课程信息只发送课程编号', (WidgetTester tester) async {
    await openMine(tester);
    await tester.tap(find.text('隐私政策'));
    await tester.pumpAndSettle();
    expect(find.textContaining('不经过任何第三方服务器'), findsOneWidget);
    expect(find.textContaining('发送课程编号'), findsOneWidget);
    expect(find.textContaining('不联网时'), findsOneWidget);
    expect(find.textContaining('2026 年 9 月 10 日'), findsOneWidget);
  });
}
