import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/theme/palette.dart';

/// 液态玻璃面板：BackdropFilter 模糊 + 渐变着色 + 高光描边 + 可选的色散/果冻效果。
///
/// 对应「卡片背景模糊」「卡片透明」「液态玻璃」「果冻效果」「色散」等设置。
class LiquidGlass extends StatefulWidget {
  final Widget child;
  final BorderRadius radius;
  final EdgeInsetsGeometry? padding;
  final Color tintColor; // 着色基准色
  final double? tintAlphaOverride;
  final double? blurOverride;
  final bool? liquidOverride;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? glowColor;
  final EdgeInsetsGeometry? margin;

  /// 是否绘制投影；大量小卡片（课表格子）关闭以降低绘制开销。
  final bool elevated;

  /// 是否启用按压果冻回弹（课表小卡片关闭：回弹动画会与页面切换叠加）。
  final bool jelly;

  const LiquidGlass({
    super.key,
    required this.child,
    this.radius = const BorderRadius.all(Radius.circular(16)),
    this.padding,
    this.tintColor = Colors.white,
    this.tintAlphaOverride,
    this.blurOverride,
    this.liquidOverride,
    this.onTap,
    this.onLongPress,
    this.glowColor,
    this.margin,
    this.elevated = true,
    this.jelly = true,
  });

  @override
  State<LiquidGlass> createState() => _LiquidGlassState();
}

class _LiquidGlassState extends State<LiquidGlass> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppState>().settings;
    final liquid = widget.liquidOverride ?? settings.liquidGlass;
    // 两种模式都做高斯模糊：关闭液态玻璃 = 普通高斯模糊卡片
    final sigma = (widget.blurOverride ?? settings.cardBlur * 20).clamp(0.0, 40.0);
    // 着色强度 → 不透明度：参照 iOS Liquid Glass（填充极淡，约 0.05~0.2）
    final tint = widget.tintAlphaOverride != null
        ? (widget.tintAlphaOverride! * 0.38).clamp(0.0, 0.55)
        : (0.05 + (1 - settings.cardTransparency) * 0.20).clamp(0.03, 0.30);
    final dispersion = liquid ? settings.dispersion : 0.0;

    Widget content = ClipRRect(
      borderRadius: widget.radius,
      child: Stack(
        children: [
          if (sigma > 0.5)
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: const SizedBox.expand(),
              ),
            ),
          // 淡色玻璃底（iOS 风格：几乎透明，仅轻微冷调）
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: widget.radius,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    widget.tintColor.withValues(alpha: tint),
                    widget.tintColor.withValues(alpha: tint * 0.55),
                  ],
                ),
              ),
            ),
          ),
          // 玻璃边缘：外描边 + 顶部高光线 + 底部微光 + 斜向光泽
          if (liquid)
            Positioned.fill(
              child: CustomPaint(painter: _GlassEdgePainter(widget.radius)),
            )
          else
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: widget.radius,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
              ),
            ),
          if (widget.padding != null)
            Padding(padding: widget.padding!, child: widget.child)
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: widget.child,
            ),
        ],
      ),
    );

    // 色散：外圈红/青渐变玻璃环
    if (dispersion > 0.03) {
      content = Container(
        decoration: BoxDecoration(
          borderRadius: widget.radius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFEF4444).withValues(alpha: 0.45 * dispersion),
              Colors.white.withValues(alpha: 0.10 * dispersion),
              Colors.transparent,
              const Color(0xFF38BDF8).withValues(alpha: 0.45 * dispersion),
            ],
          ),
          boxShadow: widget.elevated
              ? [
                  BoxShadow(
                    color: (widget.glowColor ?? Colors.black)
                        .withValues(alpha: 0.25 + 0.1 * dispersion),
                    blurRadius: 14 + 8 * dispersion,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        padding: EdgeInsets.all(0.8 + dispersion),
        child: content,
      );
    } else if (widget.elevated) {
      content = Container(
        decoration: BoxDecoration(
          borderRadius: widget.radius,
          boxShadow: [
            BoxShadow(
              color: (widget.glowColor ?? Colors.black).withValues(
                  alpha: liquid ? 0.30 : 0.20),
              blurRadius: liquid ? 26 : 14,
              offset: Offset(0, liquid ? 8 : 5),
            ),
          ],
        ),
        child: content,
      );
    }

    // 果冻效果：按压缩放 + 弹性回弹
    if (widget.jelly && settings.jellyEffect && (widget.onTap != null || widget.onLongPress != null)) {
      content = GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.955 : 1.0,
          duration: _pressed
              ? const Duration(milliseconds: 70)
              : const Duration(milliseconds: 480),
          curve: _pressed ? Curves.easeOut : Curves.elasticOut,
          child: content,
        ),
      );
    } else if (widget.onTap != null || widget.onLongPress != null) {
      content = GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: content,
      );
    }

    return Container(margin: widget.margin, child: content);
  }
}

/// iOS Liquid Glass 边缘：1px 亮边 + 顶部内侧高光线 + 底部微光 + 斜向光泽。
///
/// 参照 CSS 实现：
/// `border: 1px rgba(255,255,255,.18)`，
/// `inset 0 1px 0 rgba(255,255,255,.25)`、`inset 0 -1px 0 rgba(255,255,255,.06)`。
class _GlassEdgePainter extends CustomPainter {
  const _GlassEdgePainter(this.radius);

  final BorderRadius radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = radius.toRRect(rect);

    canvas.save();
    canvas.clipRRect(rrect);

    // 斜向光泽：左上极淡的白，右下极淡的暗
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: 0.05),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(rect),
    );

    // 顶部内侧高光线
    canvas.drawRect(
      Rect.fromLTWH(0, 1, size.width, 1),
      Paint()..color = Colors.white.withValues(alpha: 0.25),
    );
    // 底部内侧微光
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 2, size.width, 1),
      Paint()..color = Colors.white.withValues(alpha: 0.06),
    );

    canvas.restore();

    // 外描边
    canvas.drawRRect(
      rrect.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.18),
    );
  }

  @override
  bool shouldRepaint(covariant _GlassEdgePainter oldDelegate) =>
      oldDelegate.radius != radius;
}

/// 小号玻璃图标按钮（主页右上角 + / 分享 / 菜单）。
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;

  /// 二级页面的返回按钮可关闭背景模糊，减少页面切换时的离屏开销。
  final bool blur;
  const GlassIconButton(
      {super.key, required this.icon, this.onTap, this.size = 38, this.blur = true});

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      radius: BorderRadius.circular(size / 2),
      padding: EdgeInsets.zero,
      tintAlphaOverride: blur ? 0.28 : 0.45,
      blurOverride: blur ? null : 0,
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(icon, size: 19, color: Colors.white),
      ),
    );
  }
}

/// 大卡片内设置行的外壳：可选顶部细线分隔（对应图二的细线分区）。
class _SettingRowShell extends StatelessWidget {
  final bool showDivider;
  final EdgeInsetsGeometry padding;
  final Widget child;

  const _SettingRowShell({
    required this.showDivider,
    required this.padding,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: showDivider
          ? BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 0.6,
                ),
              ),
            )
          : null,
      child: child,
    );
  }
}

/// 设置滑杆行（个性化大卡片内使用，行间用细线分隔）。
class GlassSliderRow extends StatelessWidget {
  final String title;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final String Function(double)? label;
  final bool showDivider;

  const GlassSliderRow({
    super.key,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.label,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = themeColorOf(context.watch<AppState>().settings);
    final v = label?.call(value) ?? value.toStringAsFixed(2);
    return _SettingRowShell(
      showDivider: showDivider,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(title,
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: SizedBox(
              height: 44,
              child: SliderTheme(
                data: const SliderThemeData(
                  trackHeight: 3,
                  thumbColor: Colors.white,
                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: 9),
                  overlayShape: RoundSliderOverlayShape(overlayRadius: 16),
                ).copyWith(
                  activeTrackColor: theme,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.14),
                ),
                child: Slider(
                  value: value.clamp(min, max),
                  min: min,
                  max: max,
                  onChanged: onChanged,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 34,
            child: Text(v,
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: theme,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// 设置开关行（个性化大卡片内使用，行间用细线分隔）。
class GlassSwitchRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showDivider;
  final EdgeInsetsGeometry padding;

  const GlassSwitchRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.showDivider = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  });

  @override
  Widget build(BuildContext context) {
    final theme = themeColorOf(context.watch<AppState>().settings);
    return _SettingRowShell(
      showDivider: showDivider,
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 10.5)),
              ],
            ),
          ),
          SwitchTheme(
            data: SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith(
                  (s) => Colors.white),
              trackColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.selected)
                      ? theme
                      : Colors.white.withValues(alpha: 0.18)),
              trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
            ),
            child: Switch(value: value, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}

