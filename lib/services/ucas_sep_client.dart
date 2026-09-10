import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:pointycastle/export.dart';

/// 国科大 SEP（教育业务接入平台）登录 + 选课系统个人课表抓取。
///
/// 流程与浏览器一致（参考 sep.ucas.ac.cn 页面内 `sepSubmit()`）：
/// 1. GET `https://sep.ucas.ac.cn/` 取 RSA 公钥 `jsePubKey`，同时拿到 JSESSIONID；
/// 2. GET `/changePic?code=时间戳` 取验证码图片（与会话绑定）；
/// 3. POST `/slogin`：userName、pwd（RSA/PKCS#1 v1.5 + base64）、certCode、loginFrom、sb=sb；
/// 4. GET `/portal/site/226/821`（选课系统入口）→ 页面里带身份令牌的跳转链接 → 跟随；
/// 5. GET `https://xkgo.ucas.ac.cn:3000/course/personSchedule` 得到个人课表 HTML。
///
/// 账号密码只发送给 sep.ucas.ac.cn，不经过任何第三方。
class UcasSepClient {
  static const String sepBase = 'https://sep.ucas.ac.cn';
  static const String portalCourseEntry = '/portal/site/226/821';
  static const List<String> personScheduleUrls = [
    'https://xkgo.ucas.ac.cn:3000/course/personSchedule',
    'https://xkcts.ucas.ac.cn:8443/course/personSchedule',
  ];
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

  final Dio dio;
  final CookieJar cookieJar;

  /// 调试轨迹（URL、状态码、页面标题），失败时展示给用户。
  final List<String> trace = [];

  String? _pubKey;

  UcasSepClient({Dio? dio, CookieJar? cookieJar})
      : cookieJar = cookieJar ?? CookieJar(),
        dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
              sendTimeout: const Duration(seconds: 15),
              followRedirects: false,
              validateStatus: (s) => s != null && s < 500,
              headers: {
                'User-Agent': userAgent,
                'Accept':
                    'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
                'Accept-Language': 'zh-CN,zh;q=0.9',
              },
            )) {
    this.dio.interceptors.add(CookieManager(this.cookieJar));
  }

  // ---------------------------------------------------------------- HTTP

  void _log(String s) {
    trace.add(maskSecrets(s));
    if (trace.length > 40) trace.removeAt(0);
  }

  static final RegExp _secretParam = RegExp(
      r'\b(Identity|token|ticket|jsessionid|session_id|sessionid)=([^&\s"'']+)',
      caseSensitive: false);

  /// 调试轨迹脱敏：门户跳转链接里的身份令牌等一律替换为 `***`，
  /// 避免用户复制调试信息反馈问题时泄露会话凭证。
  static String maskSecrets(String s) =>
      s.replaceAllMapped(_secretParam, (m) => '${m.group(1)}=***');

  /// GET 并手动跟随重定向（让 Cookie 管理器看到每一跳的 Set-Cookie）。
  Future<Response<dynamic>> getFollow(String url,
      {int maxHops = 8, ResponseType type = ResponseType.plain}) async {
    var current = url;
    Response<dynamic>? res;
    for (var hop = 0; hop <= maxHops; hop++) {
      res = await dio.get<dynamic>(current, options: Options(responseType: type));
      final status = res.statusCode ?? 0;
      final loc = res.headers.value('location');
      _log('GET $current → $status${loc != null ? ' → $loc' : ''}');
      if (status >= 300 && status < 400 && loc != null && loc.isNotEmpty) {
        current = Uri.parse(current).resolve(loc).toString();
        continue;
      }
      // 部分页面用 meta refresh / JS 跳转
      if (type == ResponseType.plain && status == 200) {
        final next = _metaRefreshTarget(res.data?.toString() ?? '', current);
        if (next != null && hop < maxHops) {
          _log('   meta/js refresh → $next');
          current = next;
          continue;
        }
      }
      return res;
    }
    return res!;
  }

  static String? _metaRefreshTarget(String html, String base) {
    final m = RegExp(
            r'''<meta[^>]*http-equiv=["']?refresh["']?[^>]*content=["'][^"']*url=([^"'>\s]+)''',
            caseSensitive: false)
        .firstMatch(html);
    if (m != null) return Uri.parse(base).resolve(m.group(1)!).toString();
    final j = RegExp(r'''(?:window\.)?location(?:\.href)?\s*=\s*["']([^"']+)["']''')
        .firstMatch(html);
    if (j != null && html.length < 4000) {
      return Uri.parse(base).resolve(j.group(1)!).toString();
    }
    return null;
  }

  static String _title(String html) {
    final m = RegExp(r'<title>(.*?)</title>', caseSensitive: false, dotAll: true).firstMatch(html);
    return m?.group(1)?.trim() ?? '';
  }

  // ---------------------------------------------------------------- 登录

  /// 打开登录页：获取公钥并建立会话。
  Future<void> prepare() async {
    final res = await getFollow('$sepBase/?loginFrom=$portalCourseEntry');
    final html = res.data?.toString() ?? '';
    final m = RegExp(r"jsePubKey\s*=\s*'([^']+)'").firstMatch(html);
    if (m == null) {
      throw UcasSepException('未能从 SEP 登录页获取加密公钥，请稍后重试', trace);
    }
    _pubKey = m.group(1)!;
  }

  /// 验证码图片（JPEG 字节）。
  Future<Uint8List> fetchCaptcha() async {
    if (_pubKey == null) await prepare();
    final res = await dio.get<List<int>>(
      '$sepBase/changePic?code=${DateTime.now().millisecondsSinceEpoch}',
      options: Options(responseType: ResponseType.bytes),
    );
    _log('GET /changePic → ${res.statusCode} (${res.data?.length ?? 0} bytes)');
    final data = res.data;
    if (data == null || data.isEmpty) {
      throw UcasSepException('验证码图片获取失败', trace);
    }
    return Uint8List.fromList(data);
  }

  /// 登录。成功返回 true；账号、密码或验证码错误抛 [UcasSepException]。
  Future<void> login(String username, String password, String captcha) async {
    if (_pubKey == null) await prepare();
    final encrypted = rsaEncryptPkcs1(password, _pubKey!);
    final res = await dio.post<dynamic>(
      '$sepBase/slogin',
      data: {
        'userName': username.trim(),
        'pwd': encrypted,
        'loginFrom': portalCourseEntry,
        'certCode': captcha.trim(),
        'sb': 'sb',
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        responseType: ResponseType.plain,
        headers: {'Referer': '$sepBase/', 'Origin': sepBase},
      ),
    );
    final status = res.statusCode ?? 0;
    final body = res.data?.toString() ?? '';
    _log('POST /slogin → $status (${body.length} bytes)');
    final err = extractError(body);
    if (err != null) throw UcasSepException(err, trace);
    if (status == 200 && body.contains("id='sepform'")) {
      throw UcasSepException('登录未成功（仍停留在登录页），请检查账号、密码与验证码', trace);
    }
    // 302 → 门户；跟随一次，确认已登录
    final loc = res.headers.value('location');
    if (loc != null && loc.isNotEmpty) {
      await getFollow(Uri.parse('$sepBase/slogin').resolve(loc).toString());
    }
  }

  static String? extractError(String html) {
    final m = RegExp(r'<div class="alert alert-error">(.*?)</div>', dotAll: true).firstMatch(html);
    if (m == null) return null;
    final text = html_parser.parseFragment(m.group(1)!).text?.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
    return text.isEmpty ? '登录失败' : text;
  }

  // ---------------------------------------------------------------- 选课系统

  /// 登录后进入选课系统并抓取个人课表 HTML。
  Future<String> fetchPersonSchedule() async {
    // 1) 门户入口页 → 带令牌的跳转链接
    final portal = await getFollow('$sepBase$portalCourseEntry');
    final portalHtml = portal.data?.toString() ?? '';
    final handoff = findHandoffLink(portalHtml, '$sepBase$portalCourseEntry');
    if (handoff != null) {
      await getFollow(handoff);
    } else {
      _log('   门户页未找到跳转链接（title=${_title(portalHtml)}），直接尝试个人课表');
    }
    // 2) 个人课表
    for (final url in personScheduleUrls) {
      final res = await getFollow(url);
      final html = res.data?.toString() ?? '';
      if (html.contains('coursetime/')) return html;
      _log('   个人课表页无课程链接（title=${_title(html)}）');
      // 可能需要先访问首页建立选课系统会话
      final home = Uri.parse(url).resolve('/courseManage/main').toString();
      final r2 = await getFollow(home);
      final h2 = r2.data?.toString() ?? '';
      final link = RegExp(r'''href=["']([^"']*personSchedule[^"']*)["']''').firstMatch(h2)?.group(1);
      if (link != null) {
        final r3 = await getFollow(Uri.parse(home).resolve(link).toString());
        final h3 = r3.data?.toString() ?? '';
        if (h3.contains('coursetime/')) return h3;
      }
    }
    throw UcasSepException(
        '已登录 SEP，但未能打开个人课表页。可能选课系统尚未开放，或跳转方式已变化', trace);
  }

  static String? findHandoffLink(String html, String base) {
    // 「2秒钟没有响应请点击<a href="…"><strong>这里</strong>」
    final m1 = RegExp(r'''请点击\s*<a[^>]*href=["']([^"']+)["']''').firstMatch(html);
    if (m1 != null) return Uri.parse(base).resolve(m1.group(1)!).toString();
    final m2 = RegExp(r'''href=["'](https?://(?:xkgo|xkcts)\.ucas\.ac\.cn[^"']*)["']''').firstMatch(html);
    if (m2 != null) return m2.group(1);
    final m3 = RegExp(r'''(?:href|src)=["']([^"']*Identity=[^"']+)["']''').firstMatch(html);
    if (m3 != null) return Uri.parse(base).resolve(m3.group(1)!).toString();
    return _metaRefreshTarget(html, base);
  }

  Future<void> logout() async {
    try {
      await dio.get<dynamic>('$sepBase/logout');
    } catch (_) {}
    await cookieJar.deleteAll();
    _pubKey = null;
  }

  // ---------------------------------------------------------------- RSA

  /// 与页面 JSEncrypt 一致：PKCS#1 v1.5 加密后 base64。
  static String rsaEncryptPkcs1(String plain, String spkiBase64) {
    final key = parseSpkiPublicKey(spkiBase64);
    final rnd = FortunaRandom();
    final seed = Uint8List.fromList(
        List<int>.generate(32, (_) => Random.secure().nextInt(256)));
    rnd.seed(KeyParameter(seed));
    final cipher = PKCS1Encoding(RSAEngine())
      ..init(true, ParametersWithRandom(PublicKeyParameter<RSAPublicKey>(key), rnd));
    final input = Uint8List.fromList(utf8.encode(plain));
    return base64Encode(cipher.process(input));
  }

  /// 解析 X.509 SubjectPublicKeyInfo（DER, base64）→ RSA 公钥。
  static RSAPublicKey parseSpkiPublicKey(String b64) {
    final der = base64Decode(b64.replaceAll(RegExp(r'\s'), ''));
    final r = _DerReader(der);
    r.expect(0x30); // SPKI SEQUENCE
    r.expect(0x30); // AlgorithmIdentifier
    r.skipValue(); // 跳过整个 AlgorithmIdentifier 内容
    r.expect(0x03); // BIT STRING
    r.pos++; // unused bits
    r.expect(0x30); // RSAPublicKey SEQUENCE
    final n = r.readInteger();
    final e = r.readInteger();
    return RSAPublicKey(n, e);
  }
}

class UcasSepException implements Exception {
  final String message;
  final List<String> trace;
  UcasSepException(this.message, [List<String>? trace]) : trace = List.of(trace ?? const []);
  @override
  String toString() => message;
}

/// 极简 DER 读取器（只处理本项目需要的 TLV）。
class _DerReader {
  final Uint8List bytes;
  int pos = 0;
  int _pendingLen = 0;
  _DerReader(this.bytes);

  int _readLength() {
    var len = bytes[pos++];
    if (len & 0x80 != 0) {
      final n = len & 0x7f;
      len = 0;
      for (var i = 0; i < n; i++) {
        len = (len << 8) | bytes[pos++];
      }
    }
    return len;
  }

  /// 读取 tag 与长度，游标停在内容起点。
  void expect(int tag) {
    if (pos >= bytes.length || bytes[pos] != tag) {
      throw FormatException('DER: 期望 tag 0x${tag.toRadixString(16)}，位置 $pos');
    }
    pos++;
    _pendingLen = _readLength();
  }

  /// 跳过上一个 expect() 的整个内容。
  void skipValue() => pos += _pendingLen;

  BigInt readInteger() {
    expect(0x02);
    final end = pos + _pendingLen;
    var v = BigInt.zero;
    for (var i = pos; i < end; i++) {
      v = (v << 8) | BigInt.from(bytes[i]);
    }
    pos = end;
    return v;
  }
}
