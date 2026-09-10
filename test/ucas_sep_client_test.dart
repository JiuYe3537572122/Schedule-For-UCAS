import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:class_manager/services/ucas_sep_client.dart';

/// SEP 登录相关的纯函数：公钥解析、RSA 加密、页面片段解析。
void main() {
  // sep.ucas.ac.cn 页面内嵌的 jsePubKey（2048 位 RSA）
  const pubKey =
      'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA0o2Y0iQQYdjIVPO8IdwaAjitO3n4tEjq8kDx7clH5LN1bywAYkijBeBQ0KH19t2a601l90C8g+P5pC7K3bTJLv/x6PHltdeFAnL1lScWr/T5jE1PBATRbjvN3IetFnZ2S4BwjaBfjBvd/w0SQ9pxa1efVyhjHKVry2gl4c+qdZZoA0rwdQJNFcC6f6653NSBhfFNbnydJ7Ekx2h1PH72OvkO5j49IQr0ulIpjAOumfxy3mCBfOsCp3DwG3/7upWpdswAU6AhQKD50BtCz/De8w7vOcxWBiskRPs3fSG6l+oQGMuXKIbpMvI+D7afbwt7WldtCky2wofVPhnTytSCbQIDAQAB';

  test('解析 SPKI 公钥：2048 位、e = 65537', () {
    final key = UcasSepClient.parseSpkiPublicKey(pubKey);
    expect(key.modulus!.bitLength, 2048);
    expect(key.exponent, BigInt.from(65537));
  });

  test('RSA PKCS#1 v1.5 加密输出 256 字节 base64，且每次随机填充不同', () {
    final a = UcasSepClient.rsaEncryptPkcs1('p@ssw0rd', pubKey);
    final b = UcasSepClient.rsaEncryptPkcs1('p@ssw0rd', pubKey);
    expect(base64Decode(a).length, 256);
    expect(base64Decode(b).length, 256);
    expect(a, isNot(b));
    // 密文作为整数必须小于模数
    final key = UcasSepClient.parseSpkiPublicKey(pubKey);
    final c = base64Decode(a).fold<BigInt>(BigInt.zero, (v, x) => (v << 8) | BigInt.from(x));
    expect(c < key.modulus!, isTrue);
  });

  test('登录错误提示提取', () {
    const html = '<div class="container"><div class="alert alert-error">\n  验证码错误！ <b>请重试</b>\n</div></div>';
    expect(UcasSepClient.extractError(html), '验证码错误！ 请重试');
    expect(UcasSepClient.extractError('<html><body>ok</body></html>'), isNull);
  });

  test('调试轨迹脱敏：跳转链接中的身份令牌被替换', () {
    expect(
      UcasSepClient.maskSecrets(
          'GET https://xkgo.ucas.ac.cn:3000/login?Identity=abc123&roleId=1 → 302'),
      'GET https://xkgo.ucas.ac.cn:3000/login?Identity=***&roleId=1 → 302',
    );
    expect(UcasSepClient.maskSecrets('POST /slogin → 302 (0 bytes)'),
        'POST /slogin → 302 (0 bytes)');
  });

  test('门户跳转链接识别', () {
    const base = 'https://sep.ucas.ac.cn/portal/site/226/821';
    expect(
      UcasSepClient.findHandoffLink(
          '<p>2秒钟没有响应请点击<a href="https://xkgo.ucas.ac.cn:3000/login?Identity=abc&roleId=1"><strong>这里</strong></a></p>', base),
      'https://xkgo.ucas.ac.cn:3000/login?Identity=abc&roleId=1',
    );
    expect(
      UcasSepClient.findHandoffLink('<a href="https://xkcts.ucas.ac.cn:8443/login?Identity=x">go</a>', base),
      'https://xkcts.ucas.ac.cn:8443/login?Identity=x',
    );
    expect(
      UcasSepClient.findHandoffLink('<meta http-equiv="refresh" content="0;url=/portal/other">', base),
      'https://sep.ucas.ac.cn/portal/other',
    );
    expect(UcasSepClient.findHandoffLink('<html><body>nothing</body></html>', base), isNull);
  });
}
