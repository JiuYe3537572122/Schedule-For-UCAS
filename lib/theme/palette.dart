import 'package:flutter/material.dart';

import '../models/app_settings.dart';

/// 主题色（对应「个性化 → 主题颜色」色环）。首项为国科大标准蓝。
const List<Color> kThemeColors = [
  Color(0xFF174994), // 国科大蓝
  Color(0xFF3478F6), // 蓝
  Color(0xFF4F46E5), // 靛蓝
  Color(0xFF8B5CF6), // 紫
  Color(0xFFE5487E), // 玫红
  Color(0xFF8B1A1F), // 国科大红
  Color(0xFFF59E42), // 橙
  Color(0xFF35C7A6), // 青绿
];

/// 课程卡片配色盘（导入时轮换分配，保证不同课程颜色尽量不同）。
const List<int> kCourseColors = [
  0xFF3FC9A2,
  0xFF4E9AF1,
  0xFF9186F3,
  0xFFF078A9,
  0xFFEF7E5C,
  0xFFF2A75C,
  0xFF7BC86C,
  0xFF54C6D6,
  0xFF6C7BF2,
  0xFFE15A8C,
];

/// 深色弹层 / 下拉背景（国科大蓝的深色版）。
const Color kDeepSurface = Color(0xFF0F2447);

Color themeColorOf(AppSettings s) =>
    kThemeColors[s.themeColorIndex.clamp(0, kThemeColors.length - 1)];

/// 饱和度颜色矩阵（0..2）。
List<double> saturationMatrix(double sat) {
  const lumR = 0.2126, lumG = 0.7152, lumB = 0.0722;
  final sr = (1 - sat) * lumR, sg = (1 - sat) * lumG, sb = (1 - sat) * lumB;
  return [
    sat + sr, sg, sb, 0, 0,
    sr, sat + sg, sb, 0, 0,
    sr, sg, sat + sb, 0, 0,
    0, 0, 0, 1, 0,
  ];
}
