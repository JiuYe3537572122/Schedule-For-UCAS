import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:class_manager/services/ucas_person_schedule_parser.dart';
import 'package:class_manager/services/ucas_sep_client.dart';
import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/theme/palette.dart';
import 'package:class_manager/widgets/app_background.dart';
import 'package:class_manager/widgets/glass.dart';

/// 登录 SEP 并抓取个人课表。成功时以 [PersonSchedule] 作为路由返回值。
class UcasLoginScreen extends StatefulWidget {
  const UcasLoginScreen({super.key});

  @override
  State<UcasLoginScreen> createState() => _UcasLoginScreenState();
}

class _UcasLoginScreenState extends State<UcasLoginScreen> {
  late final TextEditingController _userCtl;
  late final TextEditingController _pwdCtl;
  final TextEditingController _codeCtl = TextEditingController();
  final UcasSepClient _client = UcasSepClient();

  Uint8List? _captcha;
  bool _loadingCaptcha = false;
  bool _busy = false;
  bool _remember = true;
  bool _showPwd = false;
  String _status = '';
  String _error = '';
  List<String> _trace = const [];

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    final s = state.settings;
    _userCtl = TextEditingController(text: s.sepUsername);
    _pwdCtl = TextEditingController();
    _remember = s.sepRemember;
    // 密码存放在系统安全存储，异步读取后回填
    state.loadSepPassword().then((pwd) {
      if (mounted && pwd.isNotEmpty && _pwdCtl.text.isEmpty) _pwdCtl.text = pwd;
    });
    _refreshCaptcha();
  }

  @override
  void dispose() {
    _userCtl.dispose();
    _pwdCtl.dispose();
    _codeCtl.dispose();
    super.dispose();
  }

  Future<void> _refreshCaptcha() async {
    setState(() {
      _loadingCaptcha = true;
      _error = '';
    });
    try {
      final bytes = await _client.fetchCaptcha();
      if (!mounted) return;
      setState(() {
        _captcha = bytes;
        _codeCtl.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '无法连接 SEP：${e is UcasSepException ? e.message : e}';
        _trace = e is UcasSepException ? e.trace : _client.trace;
      });
    } finally {
      if (mounted) setState(() => _loadingCaptcha = false);
    }
  }

  Future<void> _submit() async {
    final user = _userCtl.text.trim();
    final pwd = _pwdCtl.text;
    final code = _codeCtl.text.trim();
    if (user.isEmpty || pwd.isEmpty) {
      setState(() => _error = '请输入 SEP 用户名和密码');
      return;
    }
    if (code.isEmpty) {
      setState(() => _error = '请输入验证码');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
      _status = '正在登录 SEP…';
    });
    final state = context.read<AppState>();
    try {
      await _client.login(user, pwd, code);
      if (!mounted) return;
      setState(() => _status = '登录成功，正在打开选课系统个人课表…');
      final html = await _client.fetchPersonSchedule();
      final ps = parsePersonScheduleHtml(html);
      if (ps.isEmpty) {
        throw UcasSepException('个人课表页没有课程（本学期尚未选课？）', _client.trace);
      }
      // 记住账号 / 密码（仅本机；密码走系统安全存储）
      await state.updateSettings(state.settings.copyWith(
        sepUsername: user,
        sepRemember: _remember,
      ));
      if (_remember) {
        await state.saveSepPassword(pwd);
      } else {
        await state.clearSepPassword();
      }
      if (!mounted) return;
      Navigator.of(context).pop(ps);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is UcasSepException ? e.message : '$e';
        _trace = e is UcasSepException ? e.trace : _client.trace;
        _status = '';
      });
      // 验证码一次性，失败后刷新
      _refreshCaptcha();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = themeColorOf(context.watch<AppState>().settings);
    return BackgroundedScaffold(
      child: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                GlassIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  size: 34,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                const Text('登录选课系统导入',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                children: [
                  LiquidGlass(
                    radius: BorderRadius.circular(14),
                    tintColor: theme,
                    tintAlphaOverride: 0.12,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Text(
                      '使用 SEP（sep.ucas.ac.cn）账号登录，果小课会自动打开选课系统的「个人课表」并导入本学期课程。'
                      '账号密码只发送给 SEP，不经过任何第三方服务器。',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11.5, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _field('SEP 用户名', _userCtl, hint: '通常为国科大邮箱', keyboard: TextInputType.emailAddress),
                  const SizedBox(height: 10),
                  _field('密码', _pwdCtl,
                      hint: 'SEP 登录密码',
                      obscure: !_showPwd,
                      suffix: IconButton(
                        onPressed: () => setState(() => _showPwd = !_showPwd),
                        icon: Icon(_showPwd ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            size: 18, color: Colors.white.withValues(alpha: 0.6)),
                      )),
                  const SizedBox(height: 10),
                  // 验证码
                  Row(
                    children: [
                      Expanded(
                        child: _field('验证码', _codeCtl,
                            hint: '看图输入', keyboard: TextInputType.visiblePassword, autofillOff: true),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _loadingCaptcha ? null : _refreshCaptcha,
                        child: Container(
                          width: 120,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _loadingCaptcha
                              ? const Center(
                                  child: SizedBox(
                                      width: 18, height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2)))
                              : _captcha == null
                                  ? Center(
                                      child: Text('点击重试',
                                          style: TextStyle(color: kDeepSurface.withValues(alpha: 0.7), fontSize: 11)))
                                  : Image.memory(_captcha!, fit: BoxFit.fill, gaplessPlayback: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('点击验证码图片可刷新',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 10.5)),
                  const SizedBox(height: 8),
                  GlassSwitchRow(
                    title: '记住账号和密码',
                    subtitle: '密码经系统安全存储加密保存在本机，用于下次刷新课表时免输入',
                    value: _remember,
                    onChanged: (v) => setState(() => _remember = v),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 46,
                    child: LiquidGlass(
                      radius: BorderRadius.circular(14),
                      padding: EdgeInsets.zero,
                      tintColor: theme,
                      tintAlphaOverride: _busy ? 0.35 : 0.8,
                      onTap: _busy ? null : _submit,
                      child: Center(
                        child: _busy
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                      width: 16, height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                                  const SizedBox(width: 10),
                                  Text(_status,
                                      style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
                                ],
                              )
                            : const Text('登录并导入课表',
                                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    LiquidGlass(
                      radius: BorderRadius.circular(14),
                      tintColor: const Color(0xFFFF6B6B),
                      tintAlphaOverride: 0.25,
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_error,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                          if (_trace.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Theme(
                              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                title: Text('调试信息（反馈问题时可复制）',
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11.5)),
                                iconColor: Colors.white70,
                                collapsedIconColor: Colors.white70,
                                children: [
                                  SelectableText(_trace.join('\n'),
                                      style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.75), fontSize: 10.5, height: 1.4)),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () => Clipboard.setData(ClipboardData(text: '$_error\n${_trace.join('\n')}')),
                                      child: const Text('复制', style: TextStyle(color: Colors.white)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctl,
      {String? hint,
      bool obscure = false,
      Widget? suffix,
      TextInputType? keyboard,
      bool autofillOff = false}) {
    return LiquidGlass(
      radius: BorderRadius.circular(14),
      tintAlphaOverride: 0.14,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: TextField(
        controller: ctl,
        obscureText: obscure,
        keyboardType: keyboard,
        autocorrect: false,
        enableSuggestions: !autofillOff,
        style: const TextStyle(color: Colors.white, fontSize: 14.5),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 13),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 12),
          border: InputBorder.none,
          suffixIcon: suffix,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}
