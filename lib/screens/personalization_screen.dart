import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/theme/palette.dart';
import 'package:class_manager/widgets/app_background.dart';
import 'package:class_manager/widgets/glass.dart';

/// 个性化页。
class PersonalizationScreen extends StatelessWidget {
  const PersonalizationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final settings = state.settings;
    final theme = themeColorOf(settings);

    return BackgroundedScaffold(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          // ---- 标题栏 ----
          Row(
            children: [
              GlassIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                size: 34,
                blur: false,
                onTap: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 12),
              const Text('个性化',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 18),

          // ---- 个人姓名 ----
          _SectionTitle('个人姓名'),
          const SizedBox(height: 10),
          _NameCard(state: state),
          const SizedBox(height: 18),

          // ---- 主题颜色 ----
          _SectionTitle('主题颜色'),
          const SizedBox(height: 10),
          LiquidGlass(
            radius: BorderRadius.circular(18),
            tintAlphaOverride: 0.3,
            blurOverride: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < kThemeColors.length; i++)
                  GestureDetector(
                    onTap: () => state.updateSettings(
                        settings.copyWith(themeColorIndex: i)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: kThemeColors[i],
                        shape: BoxShape.circle,
                        border: settings.themeColorIndex == i
                            ? Border.all(color: Colors.white, width: 2.5)
                            : Border.all(
                                color: Colors.white.withValues(alpha: 0.25)),
                      ),
                      child: settings.themeColorIndex == i
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 17)
                          : null,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ---- 玻璃效果大卡片：一行一项，细线分隔 ----
          LiquidGlass(
            radius: BorderRadius.circular(22),
            padding: const EdgeInsets.symmetric(vertical: 6),
            tintAlphaOverride: 0.26,
            blurOverride: 0,
            child: Column(
              children: [
                GlassSwitchRow(
                  title: '显示网格',
                  subtitle: '关闭后课表背景的白色网格消失',
                  value: settings.showGrid,
                  onChanged: (v) =>
                      state.updateSettings(settings.copyWith(showGrid: v)),
                ),
                GlassSliderRow(
                  title: '背景模糊',
                  value: settings.backgroundBlur,
                  min: 0, max: 1,
                  label: (v) => (v * 100).round().toString(),
                  onChanged: (v) =>
                      state.updateSettings(settings.copyWith(backgroundBlur: v)),
                  showDivider: true,
                ),
                GlassSliderRow(
                  title: '卡片透明',
                  value: settings.cardTransparency,
                  min: 0, max: 1,
                  label: (v) => (v * 100).round().toString(),
                  onChanged: (v) =>
                      state.updateSettings(settings.copyWith(cardTransparency: v)),
                  showDivider: true,
                ),
                GlassSliderRow(
                  title: '卡片背景模糊',
                  value: settings.cardBlur,
                  min: 0, max: 1,
                  label: (v) => (v * 100).round().toString(),
                  onChanged: (v) =>
                      state.updateSettings(settings.copyWith(cardBlur: v)),
                  showDivider: true,
                ),
                GlassSwitchRow(
                  title: '液态玻璃',
                  subtitle: '性能要求高',
                  value: settings.liquidGlass,
                  onChanged: (v) =>
                      state.updateSettings(settings.copyWith(liquidGlass: v)),
                  showDivider: true,
                ),
                GlassSwitchRow(
                  title: '果冻效果',
                  subtitle: '按压卡片时缩放回弹',
                  value: settings.jellyEffect,
                  onChanged: (v) =>
                      state.updateSettings(settings.copyWith(jellyEffect: v)),
                  showDivider: true,
                ),
                GlassSliderRow(
                  title: '饱和度',
                  value: settings.saturation,
                  min: 0, max: 2,
                  label: (v) => v.toStringAsFixed(1),
                  onChanged: (v) =>
                      state.updateSettings(settings.copyWith(saturation: v)),
                  showDivider: true,
                ),
                GlassSliderRow(
                  title: '折射',
                  value: settings.refraction,
                  min: 0, max: 1,
                  label: (v) => (v * 100).round().toString(),
                  onChanged: (v) =>
                      state.updateSettings(settings.copyWith(refraction: v)),
                  showDivider: true,
                ),
                GlassSliderRow(
                  title: '色散',
                  value: settings.dispersion,
                  min: 0, max: 1,
                  label: (v) => (v * 100).round().toString(),
                  onChanged: (v) =>
                      state.updateSettings(settings.copyWith(dispersion: v)),
                  showDivider: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ---- 背景图片 ----
          _SectionTitle('背景图片'),
          const SizedBox(height: 10),
          LiquidGlass(
            radius: BorderRadius.circular(18),
            tintAlphaOverride: 0.3,
            blurOverride: 0,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              children: [
                // 缩略图
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                    image: settings.wallpaperPath != null &&
                            File(settings.wallpaperPath!).existsSync()
                        ? DecorationImage(
                            // 缩略图按 160px 解码，避免整张相册照片进内存
                            image: ResizeImage(
                              FileImage(File(settings.wallpaperPath!)),
                              width: 160,
                              height: 160,
                              policy: ResizeImagePolicy.fit,
                            ),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: settings.wallpaperPath == null
                      ? Icon(Icons.image_rounded,
                          color: Colors.white.withValues(alpha: 0.6))
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        settings.wallpaperPath == null
                            ? '使用内置默认壁纸'
                            : '已导入壁纸',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text('选择手机相册中的图片作为背景',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 11)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _pickWallpaper(context),
                  child: Text('选择图片',
                      style: TextStyle(
                          color: theme, fontWeight: FontWeight.w800)),
                ),
                if (settings.wallpaperPath != null)
                  IconButton(
                    onPressed: () => state.updateSettings(
                        settings.copyWith(clearWallpaper: true)),
                    icon: Icon(Icons.restart_alt_rounded,
                        color: Colors.white.withValues(alpha: 0.7), size: 20),
                    tooltip: '恢复默认',
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text('所有设置即时生效并保存在本地',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45), fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickWallpaper(BuildContext context) async {
    final state = context.read<AppState>();
    final f = await FilePicker.pickFile(type: FileType.image);
    if (f == null) return;
    Uint8List? bytes;
    try {
      bytes = await f.readAsBytes();
    } catch (_) {
      if (f.path != null) {
        try {
          bytes = await File(f.path!).readAsBytes();
        } catch (_) {}
      }
    }
    if (bytes == null) return;
    try {
      final path = await state.importWallpaper(bytes, f.name);
      await state.updateSettings(
          state.settings.copyWith(wallpaperPath: path));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('壁纸已导入'), duration: Duration(seconds: 1)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导入失败：$e')));
      }
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(title,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
              fontWeight: FontWeight.w800)),
    );
  }
}

/// 个人姓名输入卡片（用于「我的」页问候语）。
class _NameCard extends StatefulWidget {
  final AppState state;
  const _NameCard({required this.state});

  @override
  State<_NameCard> createState() => _NameCardState();
}

class _NameCardState extends State<_NameCard> {
  late final TextEditingController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: widget.state.settings.userName);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = themeColorOf(widget.state.settings);
    return LiquidGlass(
      radius: BorderRadius.circular(18),
      tintAlphaOverride: 0.3,
      blurOverride: 0,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(Icons.person_outline_rounded, size: 18, color: theme),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _ctl,
              style: const TextStyle(color: Colors.white, fontSize: 14.5),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                hintText: '输入名字，用于「我的」页问候语',
                hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (v) => widget.state
                  .updateSettings(widget.state.settings.copyWith(userName: v)),
            ),
          ),
        ],
      ),
    );
  }
}
