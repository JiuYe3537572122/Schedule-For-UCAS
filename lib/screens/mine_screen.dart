import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:class_manager/main.dart' show kAppName;
import 'package:class_manager/screens/personalization_screen.dart';
import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/theme/palette.dart';
import 'package:class_manager/utils/greeting.dart';
import 'package:class_manager/widgets/glass.dart';
import 'package:class_manager/utils/routes.dart';

/// 我的页：问候 + 个性化入口 + 「关于 / 隐私政策」分组卡片。
class MineScreen extends StatelessWidget {
  const MineScreen({super.key});

  static const String kCampus = '国科大杭州高等研究院';

  static const String _aboutText =
      '$kAppName 是一款为中国科学院大学研究生设计的本地课表应用。'
      '在应用内登录 SEP 即可自动抓取选课系统「个人课表」并导入本学期全部课程；'
      '课程时间、地点与周次通过选课系统的公开课程信息接口自动补全。\n\n'
      '本应用基于开源项目 Schedule-For-WHU（作者 PriAssassin141，MIT 协议）改造，'
      '保留了其液态玻璃界面与上下翻页课表设计，在此致谢。\n\n'
      '应用图标使用中国科学院院徽，默认壁纸为雁栖湖校区主楼（图片来自国科大新闻网「光影国科大」栏目），'
      '版权均归中国科学院、中国科学院大学所有，本应用仅作学习用途，不用于任何商业目的。';
  static const String _privacyText =
      '希望您仔细阅读此《$kAppName 隐私政策》（以下简称“本政策”），'
      '详细了解本应用对隐私信息的使用策略。\n\n'
      '1. 本应用没有自己的账号体系，也不需要注册；所有课程、考试与个性化设置只保存在您的设备本地，'
      '不会被以任何形式收集或上传。\n\n'
      '2. 选择「登录选课系统自动导入」时，您输入的 SEP 用户名、密码与验证码只会直接发送给'
      '中国科学院大学 SEP 平台（sep.ucas.ac.cn）完成登录，不经过任何第三方服务器；'
      '登录会话仅在本次导入过程中使用。若勾选「记住账号和密码」，密码会经系统安全存储加密保存在本机'
      '（Android Keystore / Windows 凭据管理器），可随时在登录页取消勾选以清除。\n\n'
      '3. 导入或刷新课表时，本应用会向选课系统的公开课程信息接口（xkcts.ucas.ac.cn）'
      '发送课程编号以获取上课时间与地点，不包含账号、学号、姓名或任何个人数据。\n\n'
      '4. 不联网时，本应用的全部功能仍可使用（可手动添加课程或离线导入课表网页）。\n\n'
      '最后更新于 2026 年 9 月 10 日\n'
      '$kAppName';

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppState>().settings;
    final greeting = greetingFor(DateTime.now());
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
        children: [
          // ---- 按时间问候 ----
          Padding(
            padding: const EdgeInsets.only(left: 2, top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting.withName(settings.userName),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      height: 1.2),
                ),
                const SizedBox(height: 6),
                Text(
                  '✨ ${greeting.reminder}',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12.5),
                ),
                const SizedBox(height: 4),
                Text(
                  kCampus,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          // ---- 个性化 ----
          _SettingTile(
            icon: Icons.tune_rounded,
            title: '个性化设置',
            subtitle: '主题颜色 · 液态玻璃 · 背景模糊 · 壁纸',
            onTap: () => Navigator.of(context).push(
                glassRoute(const PersonalizationScreen())),
          ),
          const SizedBox(height: 12),
          // ---- 关于 / 隐私政策 ----
          LiquidGlass(
            radius: BorderRadius.circular(18),
            tintAlphaOverride: 0.16,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                _MenuRow(
                  icon: Icons.info_outline_rounded,
                  title: '关于$kAppName',
                  onTap: () => _showTextSheet(context, '关于$kAppName',
                      Icons.info_outline_rounded, _aboutText),
                ),
                _MenuRow(
                  icon: Icons.privacy_tip_outlined,
                  title: '隐私政策',
                  showDivider: true,
                  onTap: () => _showTextSheet(
                      context, '隐私政策', Icons.privacy_tip_outlined, _privacyText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTextSheet(
      BuildContext context, String title, IconData icon, String text) {
    final theme = themeColorOf(context.read<AppState>().settings);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => LiquidGlass(
        radius: BorderRadius.circular(24),
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 16),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        tintAlphaOverride: 0.34,
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetCtx).size.height * 0.62),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: theme),
                  const SizedBox(width: 8),
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    text,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 13,
                        height: 1.8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 大卡片内的一行（细线分隔，右侧箭头）。
class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool showDivider;
  final VoidCallback onTap;

  const _MenuRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: showDivider
          ? BoxDecoration(
              border: Border(
                top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08), width: 0.6),
              ),
            )
          : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.85)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600)),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: Colors.white.withValues(alpha: 0.45)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = themeColorOf(context.watch<AppState>().settings);
    return LiquidGlass(
      radius: BorderRadius.circular(18),
      tintAlphaOverride: 0.16,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: theme.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 11)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.45), size: 20),
        ],
      ),
    );
  }
}
