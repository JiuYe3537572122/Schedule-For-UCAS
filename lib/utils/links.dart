import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/theme/palette.dart';
import 'package:class_manager/widgets/glass.dart';

/// 打开外部链接：优先调用系统浏览器；
/// 失败（或被拦截）时弹出可复制的链接兜底弹层。
Future<void> openExternalLink(BuildContext context, String url) async {
  var ok = false;
  try {
    ok = await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (!ok && context.mounted) {
    showLinkFallbackSheet(context, url);
  }
}

/// 兜底弹层：展示完整链接并支持一键复制。
void showLinkFallbackSheet(BuildContext context, String url) {
  final theme = themeColorOf(context.read<AppState>().settings);
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => LiquidGlass(
      radius: BorderRadius.circular(24),
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 16),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      tintAlphaOverride: 0.34,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('无法自动打开浏览器，请复制链接手动访问',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SelectableText(url,
                style: TextStyle(color: theme, fontSize: 12.5, height: 1.4)),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: LiquidGlass(
              radius: BorderRadius.circular(14),
              padding: EdgeInsets.zero,
              tintColor: theme,
              tintAlphaOverride: 0.75,
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: url));
                if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('链接已复制'),
                      duration: Duration(seconds: 1)));
                }
              },
              child: const Center(
                child: Text('复制链接',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
