import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:class_manager/screens/ucas_login_screen.dart';
import 'package:class_manager/state/app_state.dart';

/// SEP 登录页：字段齐全；测试环境下网络不可达时显示错误卡片而不崩溃。
void main() {
  testWidgets('登录页渲染与离线错误提示', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final state = AppState.memory();
    await state.updateSettings(state.settings.copyWith(sepUsername: 'someone@mails.ucas.ac.cn'));

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: UcasLoginScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('登录选课系统导入'), findsOneWidget);
    expect(find.text('SEP 用户名'), findsOneWidget);
    expect(find.text('密码'), findsOneWidget);
    expect(find.text('验证码'), findsOneWidget);
    expect(find.text('记住账号和密码'), findsOneWidget);
    expect(find.text('登录并导入课表'), findsOneWidget);
    // 已保存的用户名回填
    expect(find.text('someone@mails.ucas.ac.cn'), findsOneWidget);
    // flutter_test 默认拦截真实 HTTP（返回 400），应显示连接失败提示
    expect(find.textContaining('无法连接 SEP'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
