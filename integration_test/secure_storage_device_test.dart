// 真机集成测试：SEP 密码安全存储。
//
// 运行：flutter test integration_test/secure_storage_device_test.dart -d <设备ID> --no-uninstall
// （不加 --no-uninstall 时 Flutter 会在测完后卸载应用，连同本地数据一起清掉。）
//
// 不需要 SEP 账号：直接验证安全存储读写、旧版明文密码迁移、重建状态后回填，
// 以及登录页能从 sep.ucas.ac.cn 真实拉到验证码。测试结束后会恢复原有密码与设置。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

import 'package:class_manager/db/app_database.dart';
import 'package:class_manager/screens/ucas_login_screen.dart';
import 'package:class_manager/services/secret_store.dart';
import 'package:class_manager/state/app_state.dart';

/// 只含 ASCII，方便按字节在文件里搜索。
const String _sentinel = 'GxK-Sentinel-9f3a7c-pw';

/// 应用私有目录（`/data/user/0/<包名>`）。
Future<Directory> _appDir() async =>
    (await getApplicationSupportDirectory()).parent;

/// 目录下（不跟随符号链接）是否有文件包含明文 [needle]。返回命中的文件路径。
Future<List<String>> _filesContaining(Directory dir, String needle) async {
  final hits = <String>[];
  if (!await dir.exists()) return hits;
  await for (final e in dir.list(recursive: true, followLinks: false)) {
    if (e is! File) continue;
    final len = await e.length();
    if (len == 0 || len > 32 * 1024 * 1024) continue;
    final bytes = await e.readAsBytes();
    if (String.fromCharCodes(bytes).contains(needle)) hits.add(e.path);
  }
  return hits;
}

String _describe(String? v) =>
    v == null ? 'absent' : (v.isEmpty ? 'empty' : 'present(${v.length} chars)');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('安全存储：写入 / 重新实例化读取 / 删除，且私有目录无明文', (tester) async {
    final store = SecureSecretStore();
    const key = 'it_probe';
    await store.write(key, _sentinel);
    expect(await store.read(key), _sentinel);
    expect(await SecureSecretStore().read(key), _sentinel, reason: '新实例应读到同一值');

    final hits = await _filesContaining(await _appDir(), _sentinel);
    expect(hits, isEmpty, reason: '应用私有目录中不应出现明文：$hits');

    await store.delete(key);
    expect(await store.read(key), isNull);
    expect(await SecureSecretStore().read(key), isNull);
  });

  testWidgets('迁移：settings 表明文密码迁入安全存储，数据库文件无残留', (tester) async {
    final db = AppDatabase();
    final store = SecureSecretStore();

    final rawBefore = await db.readRawSetting(kSepPasswordKey);
    debugPrint('[it] 旧版明文行（迁移前）：${_describe(rawBefore)}');
    debugPrint('[it] 安全存储（迁移前）：${_describe(await store.read(kSepPasswordKey))}');

    // 1) 真实迁移路径：若旧版存过明文，这一步就是用户升级后的实际行为
    final s0 = await AppState.create();
    final originalRemember = s0.settings.sepRemember;
    expect(await db.readRawSetting(kSepPasswordKey), isNull,
        reason: '首次启动后 settings 表不应再有 sep_password');
    if (rawBefore != null && rawBefore.isNotEmpty && originalRemember) {
      expect(await store.read(kSepPasswordKey), rawBefore,
          reason: '旧版明文密码应已迁入安全存储');
      debugPrint('[it] 真实旧密码已迁移到安全存储');
    }
    // 备份必须在真实迁移之后取，否则收尾恢复时会把刚迁入的真实密码删掉
    final secureBackup = await store.read(kSepPasswordKey);

    // 2) 构造旧版明文行，验证迁移逻辑本身
    final sqlite = await db.database;
    await sqlite.insert('settings', {'key': kSepPasswordKey, 'value': _sentinel},
        conflictAlgorithm: ConflictAlgorithm.replace);
    await sqlite.insert('settings', {'key': 'sep_remember', 'value': '1'},
        conflictAlgorithm: ConflictAlgorithm.replace);

    final s1 = await AppState.create();
    expect(await db.readRawSetting(kSepPasswordKey), isNull);
    expect(await s1.loadSepPassword(), _sentinel);
    expect(await SecureSecretStore().read(kSepPasswordKey), _sentinel);

    // 3) 数据库文件（含 -journal / -wal）里不应残留明文
    final docs = await getApplicationDocumentsDirectory();
    final dbFiles = docs
        .listSync()
        .whereType<File>()
        .where((f) => p.basename(f.path).startsWith('class_manager.db'))
        .map((f) => f.path)
        .toList();
    debugPrint('[it] 数据库文件：$dbFiles');
    final dbHits = await _filesContaining(docs, _sentinel);
    expect(dbHits, isEmpty, reason: '数据库目录中不应残留明文：$dbHits');
    final allHits = await _filesContaining(await _appDir(), _sentinel);
    expect(allHits, isEmpty, reason: '应用私有目录中不应出现明文：$allHits');

    // 4) 恢复
    if (secureBackup == null) {
      await store.delete(kSepPasswordKey);
    } else {
      await store.write(kSepPasswordKey, secureBackup);
    }
    await sqlite.insert(
        'settings', {'key': 'sep_remember', 'value': originalRemember ? '1' : '0'},
        conflictAlgorithm: ConflictAlgorithm.replace);
    expect(await store.read(kSepPasswordKey), secureBackup);
  });

  testWidgets('登录页：重建状态后密码回填，验证码可从 SEP 真实获取', (tester) async {
    final store = SecureSecretStore();
    final secureBackup = await store.read(kSepPasswordKey);
    await store.write(kSepPasswordKey, _sentinel);

    // 模拟重启：全新 AppState
    final state = await AppState.create();
    expect(await state.loadSepPassword(), _sentinel);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: UcasLoginScreen()),
      ),
    );

    // 最多等 30 秒：验证码图片出现或显示错误
    final captcha = find.byWidgetPredicate(
        (w) => w is Image && w.image is MemoryImage);
    final error = find.textContaining('无法连接 SEP');
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (captcha.evaluate().isNotEmpty || error.evaluate().isNotEmpty) break;
    }
    if (error.evaluate().isNotEmpty) {
      final t = tester.widget<Text>(error.first);
      debugPrint('[it] 登录页错误：${t.data ?? t.textSpan?.toPlainText()}');
    }
    expect(captcha, findsOneWidget, reason: '应从 sep.ucas.ac.cn 拉到验证码图片');
    expect(error, findsNothing);

    final pwdField = tester
        .widgetList<TextField>(find.byType(TextField))
        .firstWhere((t) => t.obscureText);
    expect(pwdField.controller!.text, _sentinel, reason: '密码应从安全存储回填');
    expect(find.text('记住账号和密码'), findsOneWidget);

    // 恢复
    if (secureBackup == null) {
      await store.delete(kSepPasswordKey);
    } else {
      await store.write(kSepPasswordKey, secureBackup);
    }
  });
}
