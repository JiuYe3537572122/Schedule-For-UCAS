import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:class_manager/screens/root_shell.dart';
import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/theme/palette.dart';

/// 应用显示名。
const String kAppName = '果小课';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Windows / Linux 桌面使用 FFI 版 SQLite（native assets 构建），
  // Android 保持系统 sqlite3，行为一致。
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  final state = await AppState.create();
  runApp(ClassManagerApp(state: state));
}

class ClassManagerApp extends StatelessWidget {
  final AppState state;
  const ClassManagerApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: state,
      child: Consumer<AppState>(
        builder: (context, s, _) {
          final theme = themeColorOf(s.settings);
          return MaterialApp(
            title: kAppName,
            debugShowCheckedModeBanner: false,
            // 中文界面（日期/时间选择器等系统组件）
            locale: const Locale('zh', 'CN'),
            supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              colorScheme: ColorScheme.fromSeed(
                seedColor: theme,
                brightness: Brightness.dark,
              ),
              scaffoldBackgroundColor: Colors.transparent,
              fontFamilyFallback: const ['Microsoft YaHei', 'PingFang SC'],
              textTheme: const TextTheme().apply(
                bodyColor: Colors.white,
                displayColor: Colors.white,
              ),
            ),
            home: const RootShell(),
          );
        },
      ),
    );
  }
}
