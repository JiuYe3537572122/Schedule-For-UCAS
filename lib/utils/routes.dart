import 'package:flutter/material.dart';

/// 轻量页面切换：新页面自底部滑入，旧页面原地不动。
///
/// Android 默认的 Zoom 过渡会对整个新页面做缩放 + 淡入，叠加页面里的多层
/// 背景模糊时每帧都要离屏重算；整页淡入本身也需要一次离屏合成。这里只做
/// 一次平移（无淡入、无缩放），是最便宜的过渡。
Route<T> glassRoute<T>(Widget page, {RouteSettings? settings}) {
  return PageRouteBuilder<T>(
    settings: settings,
    pageBuilder: (_, _, _) => page,
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(curved),
        child: child,
      );
    },
  );
}
