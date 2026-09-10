import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:class_manager/state/app_state.dart';

/// 带玻璃背景的页面骨架：推入的二级页面复用全局背景，
/// 避免 MaterialPageRoute 的不透明表面把背景盖成纯黑。
class BackgroundedScaffold extends StatelessWidget {
  final Widget child;
  const BackgroundedScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const AppBackground(),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(child: child),
        ),
      ],
    );
  }
}

/// 全屏背景：用户壁纸 → 内置默认壁纸 → 渐变兜底。
///
/// 背景配色固定，**不随「主题颜色」变化**（主题色只作用于按钮、卡片、
/// 滑杆等控件）。仅「背景模糊 / 饱和度 / 折射」等设置会影响背景。
class AppBackground extends StatelessWidget {
  const AppBackground({super.key});

  /// 内置默认壁纸：雁栖湖校区主楼（国科大新闻网「光影国科大」第 141 期）。
  static const String defaultWallpaperAsset =
      'assets/wallpaper/default_wallpaper.jpg';

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppState>().settings;
    final path = settings.wallpaperPath;
    final hasUserWallpaper = path != null && File(path).existsSync();
    // 限制解码尺寸：用户相册照片往往是 4000×3000 以上，按屏幕尺寸解码即可
    final ImageProvider provider = ResizeImage(
      hasUserWallpaper
          ? FileImage(File(path))
          : const AssetImage(defaultWallpaperAsset),
      width: 1440,
      height: 2560,
      policy: ResizeImagePolicy.fit,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        _WallpaperLayer(
          image: provider,
          blur: settings.backgroundBlur,
        ),
        // 折射：一层错位幽灵背景（仅用户自选壁纸时）
        if (settings.refraction > 0.03 && hasUserWallpaper)
          Positioned.fill(
            child: Transform.translate(
              offset: Offset(settings.refraction * 16, settings.refraction * 4),
              child: Opacity(
                opacity: 0.35 + settings.refraction * 0.4,
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(
                      sigmaX: 6 * settings.refraction,
                      sigmaY: 6 * settings.refraction),
                  child: Image(image: provider, fit: BoxFit.cover),
                ),
              ),
            ),
          ),
        // 暗角，保证前景文字可读
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.32),
                  Colors.black.withValues(alpha: 0.52),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 壁纸层（应用背景模糊；加载失败时回退到内置渐变）。
class _WallpaperLayer extends StatelessWidget {
  final ImageProvider image;
  final double blur;
  const _WallpaperLayer({required this.image, required this.blur});

  @override
  Widget build(BuildContext context) {
    Widget img = Image(
      image: image,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const WaveBackground(),
    );
    if (blur > 0.02) {
      img = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: blur * 18, sigmaY: blur * 18),
        child: img,
      );
    }
    return img;
  }
}

/// 内置流动波浪渐变（壁纸不可用时的兜底；固定配色，不随主题色变化）。
class WaveBackground extends StatelessWidget {
  const WaveBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _WavePainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _WavePainter extends CustomPainter {
  static const Color _accent = Color(0xFF3C6FD1);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // 深蓝底
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B1E3F), Color(0xFF123A78), Color(0xFF0A1630)],
        ).createShader(rect),
    );

    void blob(Offset center, double rx, double ry, Color color, double angle) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      final r = Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2);
      final shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0.0)],
      ).createShader(r);
      canvas.drawOval(r, Paint()..shader = shader);
      canvas.restore();
    }

    blob(Offset(size.width * 0.15, size.height * 0.16),
        size.width * 0.55, size.height * 0.30,
        _accent.withValues(alpha: 0.30), -0.35);
    blob(Offset(size.width * 0.9, size.height * 0.38),
        size.width * 0.60, size.height * 0.26,
        _accent.withValues(alpha: 0.18), 0.3);
    blob(Offset(size.width * 0.4, size.height * 0.85),
        size.width * 0.75, size.height * 0.38,
        _accent.withValues(alpha: 0.22), 0.2);
    blob(Offset(size.width * -0.1, size.height * 0.68),
        size.width * 0.5, size.height * 0.22,
        const Color(0xFF7FA6E8).withValues(alpha: 0.14), -0.2);

    // 一缕斜向流光带
    canvas.save();
    canvas.rotate(-0.22);
    final bandRect = Rect.fromLTWH(-size.width * 0.4, size.height * 0.42,
        size.width * 2.0, size.height * 0.10);
    canvas.drawRect(
      bandRect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x007FB2FF), Color(0x2E9CC4FF), Color(0x007FB2FF)],
        ).createShader(bandRect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) => false;
}
