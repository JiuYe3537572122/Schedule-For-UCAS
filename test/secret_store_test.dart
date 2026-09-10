import 'package:flutter_test/flutter_test.dart';

import 'package:class_manager/models/app_settings.dart';
import 'package:class_manager/services/secret_store.dart';
import 'package:class_manager/state/app_state.dart';

/// SEP 密码不再进入设置表，而是走 [SecretStore]。
void main() {
  test('AppSettings 不再序列化 sep_password', () {
    final map = AppSettings(sepUsername: 'u', sepRemember: true).toMap();
    expect(map.containsKey('sep_password'), isFalse);
    expect(map['sep_username'], 'u');
    expect(map['sep_remember'], 1);
  });

  test('MemorySecretStore 读写删', () async {
    final store = MemorySecretStore();
    expect(await store.read('k'), isNull);
    await store.write('k', 'v');
    expect(await store.read('k'), 'v');
    await store.delete('k');
    expect(await store.read('k'), isNull);
  });

  test('AppState 保存 / 读取 / 清除 SEP 密码', () async {
    final state = AppState.memory();
    expect(await state.loadSepPassword(), '');
    await state.saveSepPassword('p@ss');
    expect(await state.loadSepPassword(), 'p@ss');
    expect(await state.secrets.read(kSepPasswordKey), 'p@ss');
    await state.clearSepPassword();
    expect(await state.loadSepPassword(), '');
    // 保存空密码等价于清除
    await state.saveSepPassword('x');
    await state.saveSepPassword('');
    expect(await state.secrets.read(kSepPasswordKey), isNull);
  });

  test('安全存储异常时不影响登录流程', () async {
    final state = AppState(null, secrets: _BrokenStore());
    expect(await state.loadSepPassword(), '');
    await state.saveSepPassword('p');
    await state.clearSepPassword();
  });
}

class _BrokenStore implements SecretStore {
  @override
  Future<String?> read(String key) async => throw StateError('keystore unavailable');
  @override
  Future<void> write(String key, String value) async => throw StateError('keystore unavailable');
  @override
  Future<void> delete(String key) async => throw StateError('keystore unavailable');
}
