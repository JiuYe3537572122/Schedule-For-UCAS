import 'package:class_manager/models/semester.dart';

/// 应用个性化设置（对应「个性化」页的各项配置）。
class AppSettings {
  /// 当前学期键（= 该学期开学日期 'yyyy-MM-dd'）。
  String currentSemesterKey;

  /// 主题色索引（0..kThemeColors.length-1）。
  int themeColorIndex;

  /// 背景模糊（0..1）。
  double backgroundBlur;

  /// 卡片透明（0..1，越大越透明）。
  double cardTransparency;

  /// 卡片背景模糊（0..1）。
  double cardBlur;

  /// 液态玻璃（性能要求高）。
  bool liquidGlass;

  /// 果冻效果。
  bool jellyEffect;

  /// 饱和度（0..2，1 为原始）。
  double saturation;

  /// 折射（0..1）。
  double refraction;

  /// 色散（0..1）。
  double dispersion;

  /// 背景图片路径；null 表示使用内置默认壁纸。
  String? wallpaperPath;

  /// 显示课表网格（关闭后课表背景的白色网格消失）。
  bool showGrid;

  /// 个人姓名（用于「我的」页问候语）。
  String userName;

  /// SEP 用户名（登录选课系统导入课表用）。
  String sepUsername;

  /// 是否记住 SEP 账号密码。密码本身不在设置表里，
  /// 而是经系统安全存储加密保存（见 `services/secret_store.dart`）。
  bool sepRemember;

  AppSettings({
    this.currentSemesterKey = kDefaultSemesterKey,
    this.themeColorIndex = 0,
    this.backgroundBlur = 0.0,
    this.cardTransparency = 0.45,
    this.cardBlur = 0.6,
    this.liquidGlass = true,
    this.jellyEffect = true,
    this.saturation = 1.0,
    this.refraction = 0.0,
    this.dispersion = 0.0,
    this.wallpaperPath,
    this.showGrid = true,
    this.userName = '',
    this.sepUsername = '',
    this.sepRemember = true,
  });

  /// 兼容旧字段名：开学日期。
  String get startDate => currentSemesterKey;

  Map<String, Object?> toMap() => {
        'current_semester': currentSemesterKey,
        'theme_color_index': themeColorIndex,
        'background_blur': backgroundBlur,
        'card_transparency': cardTransparency,
        'card_blur': cardBlur,
        'liquid_glass': liquidGlass ? 1 : 0,
        'jelly_effect': jellyEffect ? 1 : 0,
        'saturation': saturation,
        'refraction': refraction,
        'dispersion': dispersion,
        'wallpaper_path': wallpaperPath,
        'show_grid': showGrid ? 1 : 0,
        'user_name': userName,
        'sep_username': sepUsername,
        'sep_remember': sepRemember ? 1 : 0,
      };

  factory AppSettings.fromMap(Map<String, Object?> m) {
    final wp = m['wallpaper_path'] as String?;
    return AppSettings(
      // 旧库只有 start_date，新库为 current_semester
      currentSemesterKey: (m['current_semester'] as String?) ??
          (m['start_date'] as String?) ??
          kDefaultSemesterKey,
      themeColorIndex: (m['theme_color_index'] as int?) ?? 0,
      backgroundBlur: (m['background_blur'] as num?)?.toDouble() ?? 0.0,
      cardTransparency: (m['card_transparency'] as num?)?.toDouble() ?? 0.45,
      cardBlur: (m['card_blur'] as num?)?.toDouble() ?? 0.6,
      liquidGlass: ((m['liquid_glass'] as int?) ?? 1) == 1,
      jellyEffect: ((m['jelly_effect'] as int?) ?? 1) == 1,
      saturation: (m['saturation'] as num?)?.toDouble() ?? 1.0,
      refraction: (m['refraction'] as num?)?.toDouble() ?? 0.0,
      dispersion: (m['dispersion'] as num?)?.toDouble() ?? 0.0,
      wallpaperPath: (wp == null || wp.isEmpty || wp == 'null') ? null : wp,
      showGrid: ((m['show_grid'] as int?) ?? 1) == 1,
      userName: (m['user_name'] as String?) ?? '',
      sepUsername: (m['sep_username'] as String?) ?? '',
      sepRemember: ((m['sep_remember'] as int?) ?? 1) == 1,
    );
  }

  AppSettings copyWith({
    String? currentSemesterKey,
    int? themeColorIndex,
    double? backgroundBlur,
    double? cardTransparency,
    double? cardBlur,
    bool? liquidGlass,
    bool? jellyEffect,
    double? saturation,
    double? refraction,
    double? dispersion,
    String? wallpaperPath,
    bool clearWallpaper = false,
    bool? showGrid,
    String? userName,
    String? sepUsername,
    bool? sepRemember,
  }) =>
      AppSettings(
        currentSemesterKey: currentSemesterKey ?? this.currentSemesterKey,
        themeColorIndex: themeColorIndex ?? this.themeColorIndex,
        backgroundBlur: backgroundBlur ?? this.backgroundBlur,
        cardTransparency: cardTransparency ?? this.cardTransparency,
        cardBlur: cardBlur ?? this.cardBlur,
        liquidGlass: liquidGlass ?? this.liquidGlass,
        jellyEffect: jellyEffect ?? this.jellyEffect,
        saturation: saturation ?? this.saturation,
        refraction: refraction ?? this.refraction,
        dispersion: dispersion ?? this.dispersion,
        wallpaperPath:
            clearWallpaper ? null : (wallpaperPath ?? this.wallpaperPath),
        showGrid: showGrid ?? this.showGrid,
        userName: userName ?? this.userName,
        sepUsername: sepUsername ?? this.sepUsername,
        sepRemember: sepRemember ?? this.sepRemember,
      );
}
