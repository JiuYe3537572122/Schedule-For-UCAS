import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 敏感数据（目前只有 SEP 密码）的存取抽象。
///
/// 正式环境用 [SecureSecretStore]（系统安全存储），测试用 [MemorySecretStore]。
abstract class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// SEP 密码在安全存储中的键。
const String kSepPasswordKey = 'sep_password';

/// 基于 flutter_secure_storage：
/// - Android：AES/GCM 加密，密钥由 Android Keystore 的 RSA 密钥包裹；
/// - Windows：AES/GCM 加密后写入应用支持目录，密钥保存在 Windows 凭据管理器；
/// - iOS / macOS：Keychain。
class SecureSecretStore implements SecretStore {
  final FlutterSecureStorage _storage;

  SecureSecretStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage(aOptions: AndroidOptions());

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// 纯内存实现（测试 / 内存模式）。
class MemorySecretStore implements SecretStore {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);
}
