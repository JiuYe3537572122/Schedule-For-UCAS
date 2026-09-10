import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:class_manager/main.dart' show kAppName;
import 'package:class_manager/models/course.dart';
import 'package:class_manager/models/periods.dart';
import 'package:class_manager/models/semester.dart';
import 'package:class_manager/screens/course_edit_screen.dart';
import 'package:class_manager/screens/import_preview_screen.dart';
import 'package:class_manager/services/ucas_person_schedule_parser.dart';
import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/theme/palette.dart';
import 'package:class_manager/utils/weeks.dart';
import 'package:class_manager/widgets/glass.dart';
import 'package:class_manager/utils/routes.dart';

/// 主页：第 N 周 + 周一~周日 7 天全周课表（同页显示）。
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = themeColorOf(state.settings);

    return SafeArea(
      child: Column(
        children: [
          // ---- 顶部：第 N 周 + 图标按钮 ----
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Row(
              children: [
                Expanded(child: _WeekTitle(theme: theme)),
                const SizedBox(width: 8),
                GlassIconButton(
                  icon: Icons.add_rounded,
                  onTap: () => Navigator.of(context).push(
                    glassRoute(CourseEditScreen.course(null, context.read<AppState>())),
                  ),
                ),
                const SizedBox(width: 8),
                GlassIconButton(
                  icon: Icons.ios_share_rounded,
                  onTap: () => _showShareSheet(context),
                ),
                const SizedBox(width: 8),
                GlassIconButton(
                  icon: Icons.menu_rounded,
                  onTap: () => _showMenuSheet(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // ---- 全周 7 天课表 ----
          const Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: 26),
              child: _WeekPager(),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- 周标题 ----------------

class _WeekTitle extends StatelessWidget {
  final Color theme;
  const _WeekTitle({required this.theme});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final week = state.browseWeek;
    final sem = state.currentSemester;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => _showWeekPicker(context),
              child: Row(
                children: [
                  const Text('第', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                  Text('$week', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: theme)),
                  const Text('周', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.swap_vert_rounded,
                size: 16, color: Colors.white.withValues(alpha: 0.45)),
            const SizedBox(width: 2),
            Flexible(
              child: Text('上下拖动切换周',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 10.5, color: Colors.white.withValues(alpha: 0.45))),
            ),
          ],
        ),
        GestureDetector(
          onTap: () => showSemesterSheet(context),
          child: Text(
            '${sem.label} · ${sem.start.month}/${sem.start.day} 开学 · ${sem.weekCount} 周',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 10.5, color: Colors.white.withValues(alpha: 0.6)),
          ),
        ),
      ],
    );
  }
}

void _showWeekPicker(BuildContext context) {
  final state = context.read<AppState>();
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => LiquidGlass(
      radius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 16),
      tintAlphaOverride: 0.34,
      child: SizedBox(
        height: 380,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('选择周次', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5, mainAxisSpacing: 8, crossAxisSpacing: 8),
                itemCount: state.maxWeek,
                itemBuilder: (_, i) {
                  final w = i + 1;
                  final sel = w == state.browseWeek;
                  final d1 = state.dateOf(w, 1);
                  return GestureDetector(
                    onTap: () {
                      state.setBrowseWeek(w);
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: sel ? themeColorOf(state.settings) : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('$w', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                          Text('${d1.month}/${d1.day}', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 9)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ---------------- 全周课表 ----------------

const double _gutterW = 44;
const double _headerH = 46;

// ---------------- 上下拖动翻页 ----------------

/// 上下拖动翻页切换周次：拖动时页面跟手滑动，松手后翻页或回弹。
///
/// 性能要点：
/// - 每周的课表页组件按周缓存（同一实例复用）并包在 [RepaintBoundary] 里，
///   动画期间只改变平移量，不重建课表；
/// - 拖拽进度用 [ValueNotifier] 驱动 [AnimatedBuilder]，不再逐帧 setState。
class _WeekPager extends StatefulWidget {
  const _WeekPager();

  @override
  State<_WeekPager> createState() => _WeekPagerState();
}

class _WeekPagerState extends State<_WeekPager>
    with TickerProviderStateMixin {
  /// 拖拽进度：>0 向「下一周」翻，<0 向「上一周」翻，范围 -1..1。
  final ValueNotifier<double> _progress = ValueNotifier<double>(0);
  late final AnimationController _settle;
  double _from = 0;
  double _to = 0;
  bool _commitOnEnd = false;

  /// 提交翻页后，等父级用新周次重建时再把进度归零（避免一帧回跳）。
  bool _resetProgressOnBuild = false;

  /// 外部切换周次（周次选择 / 「回到本周」）时的整页滑动动画。
  late final AnimationController _external;
  int _extFrom = 1;
  int _extTo = 1;
  int _extDir = 1;
  int _lastWeek = 0;

  /// 正在逐周回跳（回到本周）时，忽略拖拽打断。
  bool _catchingUp = false;

  /// 每周课表页的组件缓存。
  final Map<int, Widget> _pages = <int, Widget>{};

  Widget _page(int week) => _pages.putIfAbsent(
        week,
        () => RepaintBoundary(
          key: ValueKey<String>('week-page-$week'),
          child: FullWeekSchedule(week: week),
        ),
      );

  @override
  void initState() {
    super.initState();
    _settle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )
      ..addListener(() {
        _progress.value =
            _from + (_to - _from) * Curves.easeOutCubic.transform(_settle.value);
      })
      ..addStatusListener((status) {
        if (status != AnimationStatus.completed) return;
        if (!_commitOnEnd) return;
        _commitOnEnd = false;
        if (!mounted) return;
        final state = context.read<AppState>();
        final delta = _progress.value > 0 ? 1 : -1;
        final target = state.browseWeek + delta;
        _lastWeek = target; // 内部提交，避免重复触发外部动画
        _resetProgressOnBuild = true;
        state.setBrowseWeek(target);
      });

    _external = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..addStatusListener((status) {
        if (status != AnimationStatus.completed) return;
        if (!mounted) return;
        setState(() {
          _extFrom = _extTo;
          _extDir = 1;
        });
      });
  }

  @override
  void dispose() {
    _settle.dispose();
    _external.dispose();
    _progress.dispose();
    super.dispose();
  }

  void _animateTo(double target, {bool commit = false}) {
    _from = _progress.value;
    _to = target;
    _commitOnEnd = commit;
    _settle.forward(from: 0);
  }

  void _onDragUpdate(DragUpdateDetails d, double height) {
    if (_catchingUp) return;
    if (_settle.isAnimating) return;
    if (_external.isAnimating) {
      _external.stop();
      setState(() => _extFrom = _extTo);
    }
    final state = context.read<AppState>();
    final week = state.browseWeek;
    var next = _progress.value - (d.primaryDelta ?? 0) / (height * 0.75);
    if (week <= 1 && next < 0) next = 0;
    if (week >= state.maxWeek && next > 0) next = 0;
    _progress.value = next.clamp(-1.0, 1.0);
  }

  void _onDragEnd(DragEndDetails d, double height) {
    if (_catchingUp) return;
    final state = context.read<AppState>();
    final week = state.browseWeek;
    final fling = -(d.primaryVelocity ?? 0) / 900;
    final target = _progress.value + fling;
    if (target > 0.22 && week < state.maxWeek) {
      _animateTo(1, commit: true);
    } else if (target < -0.22 && week > 1) {
      _animateTo(-1, commit: true);
    } else {
      _animateTo(0);
    }
  }

  /// 「回到本周」：逐周滑动返回。
  Future<void> _backToThisWeek() async {
    final state = context.read<AppState>();
    final target = state.currentWeek;
    if (state.browseWeek == target) return;
    _external.duration = const Duration(milliseconds: 140);
    setState(() => _catchingUp = true);
    var guard = 0;
    while (mounted && state.browseWeek != target && guard++ < kMaxWeek + 2) {
      final gap = (target - state.browseWeek).abs();
      final dir = target > state.browseWeek ? 1 : -1;
      state.setBrowseWeek(state.browseWeek + dir);
      final stepMs = (360 / gap).clamp(40, 110).round();
      await Future<void>.delayed(Duration(milliseconds: stepMs));
    }
    if (mounted) setState(() => _catchingUp = false);
    _external.duration = const Duration(milliseconds: 260);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final week = state.browseWeek;
    final maxWeek = state.maxWeek;
    final theme = themeColorOf(state.settings);

    if (_lastWeek == 0) _lastWeek = week;
    if (week != _lastWeek) {
      final from = _lastWeek;
      _lastWeek = week;
      _extFrom = from;
      _extTo = week;
      _extDir = week > from ? 1 : -1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _external.forward(from: 0);
      });
    }
    if (_resetProgressOnBuild) {
      _resetProgressOnBuild = false;
      _progress.value = 0;
    }

    return LayoutBuilder(builder: (context, cons) {
      final h = cons.maxHeight;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (d) => _onDragUpdate(d, h),
        onVerticalDragEnd: (d) => _onDragEnd(d, h),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRect(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_progress, _external]),
                  builder: (context, _) {
                    if (_extFrom != _extTo) {
                      final t = _external.value;
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          FractionalTranslation(
                            translation: Offset(0, -_extDir * t),
                            child: _page(_extFrom),
                          ),
                          FractionalTranslation(
                            translation: Offset(0, _extDir * (1 - t)),
                            child: _page(_extTo),
                          ),
                        ],
                      );
                    }
                    final p = _progress.value;
                    final dir = p >= 0 ? 1 : -1;
                    final a = p.abs();
                    final neighbor = (week + dir).clamp(1, maxWeek);
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        FractionalTranslation(
                          translation: Offset(0, -dir * a),
                          child: _page(week),
                        ),
                        if (a > 0.0001)
                          FractionalTranslation(
                            translation: Offset(0, dir * (1 - a)),
                            child: _page(neighbor),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
            if (week != state.currentWeek)
              Align(
                alignment: const Alignment(0.92, -0.05),
                child: _BackToThisWeek(theme: theme, onTap: _backToThisWeek),
              ),
          ],
        ),
      );
    });
  }
}

/// 周一~周日同时显示的 7 列全周课表（13 节 × 7 天）。
class FullWeekSchedule extends StatelessWidget {
  final int week;
  const FullWeekSchedule({super.key, required this.week});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final settings = state.settings;
    final theme = themeColorOf(settings);
    final sem = state.currentSemester;

    final all = state.currentCourses
        .where((c) => state.courseActiveInWeek(c, week))
        .toList()
      ..sort((a, b) => a.startPeriod.compareTo(b.startPeriod));

    // 同日重叠课程分栏
    final lanes = <int, List<int>>{};
    final laneOf = <Course, int>{};
    for (final c in all) {
      final l = lanes.putIfAbsent(c.day, () => []);
      var placed = false;
      for (var i = 0; i < l.length; i++) {
        if (l[i] < c.startPeriod) {
          l[i] = c.endPeriod;
          laneOf[c] = i;
          placed = true;
          break;
        }
      }
      if (!placed) {
        laneOf[c] = l.length;
        l.add(c.endPeriod);
      }
    }
    final laneCountOf = <int, int>{
      for (final e in lanes.entries) e.key: e.value.length,
    };

    final now = DateTime.now();
    final isTodayWeek = sem.weekOfDate(now) == week;
    final todayCol = isTodayWeek ? now.weekday : -1;

    return LayoutBuilder(builder: (context, cons) {
      final width = cons.maxWidth;
      final colW = (width - _gutterW) / 7;
      final slotH =
          ((cons.maxHeight - _headerH) / kPeriodCount).clamp(16.0, 64.0);
      final totalH = _headerH + kPeriodCount * slotH;

      return SingleChildScrollView(
        physics: totalH <= cons.maxHeight + 0.5
            ? const NeverScrollableScrollPhysics()
            : const ClampingScrollPhysics(),
        child: SizedBox(
          width: width,
          height: totalH,
          child: Stack(
            children: [
              // ---- 星期表头 ----
              Positioned(
                left: _gutterW,
                top: 0,
                right: 0,
                height: _headerH,
                child: Row(
                  children: [
                    for (var d = 1; d <= 7; d++)
                      Expanded(
                        child: _DayHeader(
                          day: d,
                          date: state.dateOf(week, d),
                          isToday: d == todayCol,
                          holiday: sem.holidayOn(state.dateOf(week, d))?.name,
                          theme: theme,
                        ),
                      ),
                  ],
                ),
              ),
              // ---- 网格 + 时段分隔线 + 今日列（单次绘制）----
              Positioned(
                left: 0,
                top: _headerH,
                width: width,
                height: kPeriodCount * slotH,
                child: RepaintBoundary(
                  child: ScheduleGrid(
                    slotH: slotH,
                    colW: colW,
                    gutterW: _gutterW,
                    showGrid: settings.showGrid,
                    todayCol: todayCol,
                    todayColor: theme,
                  ),
                ),
              ),
              // ---- 节次时间轴 ----
              for (var i = 0; i < kPeriodCount; i++)
                Positioned(
                  left: 0,
                  top: _headerH + i * slotH,
                  width: _gutterW,
                  height: slotH,
                  child: _PeriodLabel(index: i),
                ),
              // ---- 课程卡片 ----
              for (final c in all)
                _buildCourseCard(
                    context, c, colW, slotH, laneOf[c] ?? 0, laneCountOf[c.day] ?? 1),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildCourseCard(BuildContext context, Course c, double colW,
      double slotH, int lane, int laneCount) {
    final subW = colW / laneCount;
    return Positioned(
      left: _gutterW + (c.day - 1) * colW + lane * subW + 1.8,
      top: _headerH + (c.startPeriod - 1) * slotH + 2,
      width: subW - 3.2,
      height: c.span * slotH - 3.5,
      child: _MiniCourseCard(
        course: c,
        onTap: () => Navigator.of(context).push(
          glassRoute(CourseEditScreen.course(c, context.read<AppState>())),
        ),
        onLongPress: () => showCourseActions(context, c),
      ),
    );
  }
}

/// 节次时间轴上的一格（序号 + 起止时间 + 备注）。
class _PeriodLabel extends StatelessWidget {
  final int index; // 0..12
  const _PeriodLabel({required this.index});

  @override
  Widget build(BuildContext context) {
    final p = kPeriods[index];
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('${index + 1}',
                style: TextStyle(
                  fontSize: 15.5,
                  height: 1.0,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.95),
                )),
            const SizedBox(height: 3),
            Text(
              '${p.start}\n${p.end}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 8.5,
                height: 1.15,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.62),
              ),
            ),
            if (p.note.isNotEmpty)
              Text(
                p.note,
                style: TextStyle(
                  fontSize: 7.5,
                  height: 1.1,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 课表网格背景：13 × 7 圆角格、上午 / 下午 / 晚上分隔线、今日列高亮，
/// 用一次 [CustomPaint] 绘制，替代逐格的 Container。
class ScheduleGrid extends StatelessWidget {
  final double slotH;
  final double colW;
  final double gutterW;
  final bool showGrid;
  final int todayCol; // 1..7，-1 表示无
  final Color todayColor;

  const ScheduleGrid({
    super.key,
    required this.slotH,
    required this.colW,
    required this.gutterW,
    required this.showGrid,
    required this.todayCol,
    required this.todayColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GridPainter(
        slotH: slotH,
        colW: colW,
        gutterW: gutterW,
        showGrid: showGrid,
        todayCol: todayCol,
        todayColor: todayColor,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _GridPainter extends CustomPainter {
  final double slotH;
  final double colW;
  final double gutterW;
  final bool showGrid;
  final int todayCol;
  final Color todayColor;

  const _GridPainter({
    required this.slotH,
    required this.colW,
    required this.gutterW,
    required this.showGrid,
    required this.todayCol,
    required this.todayColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (showGrid) {
      final fill = Paint()..color = Colors.white.withValues(alpha: 0.028);
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = Colors.white.withValues(alpha: 0.045);
      const r = Radius.circular(8);
      for (var i = 0; i < kPeriodCount; i++) {
        for (var d = 0; d < 7; d++) {
          final rect = Rect.fromLTWH(
            gutterW + d * colW + 1.2,
            i * slotH + 1.4,
            colW - 2.4,
            slotH - 2.8,
          );
          final rr = RRect.fromRectAndRadius(rect, r);
          canvas.drawRRect(rr, fill);
          canvas.drawRRect(rr, stroke);
        }
      }
    }
    // 时段分隔线
    final divider = Paint()..color = Colors.white.withValues(alpha: 0.16);
    for (var i = 1; i < kPeriodCount; i++) {
      if (isSlotBoundaryAfter(i)) {
        canvas.drawRect(
            Rect.fromLTWH(gutterW + 2, i * slotH - 0.5, size.width - gutterW - 4, 1),
            divider);
      }
    }
    // 今日列
    if (todayCol >= 1) {
      final rect = Rect.fromLTWH(
          gutterW + (todayCol - 1) * colW + 1.2, 0, colW - 2.4, kPeriodCount * slotH);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(10)),
        Paint()..color = todayColor.withValues(alpha: 0.07),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) =>
      old.slotH != slotH ||
      old.colW != colW ||
      old.gutterW != gutterW ||
      old.showGrid != showGrid ||
      old.todayCol != todayCol ||
      old.todayColor != todayColor;
}

/// 7 列课表中的单门课程小卡片（轻量玻璃：不做背景模糊、不投影，翻页更流畅）。
class _MiniCourseCard extends StatelessWidget {
  final Course course;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _MiniCourseCard({required this.course, this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final c = course;
    final color = Color(c.colorValue);
    final partial = !Weeks.isAll(c.weeks);
    return LiquidGlass(
      radius: BorderRadius.circular(10),
      tintColor: color,
      tintAlphaOverride: 1.4,
      blurOverride: 0,
      elevated: false,
      jelly: false,
      padding: const EdgeInsets.fromLTRB(3.5, 4, 3.5, 3),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Center(
                  child: Text(
                    c.name,
                    maxLines: 9,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      height: 1.18,
                      shadows: [Shadow(color: Colors.black45, blurRadius: 3)],
                    ),
                  ),
                ),
              ),
              if (c.location.isNotEmpty)
                Text(
                  c.location,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 8.5,
                    height: 1.15,
                  ),
                ),
            ],
          ),
          if (partial)
            Positioned(
              top: 0,
              right: 0,
              child: Icon(Icons.circle,
                  size: 5, color: Colors.white.withValues(alpha: 0.9)),
            ),
        ],
      ),
    );
  }
}

/// 星期表头（周X + 日期，今天高亮，节假日标注）。
class _DayHeader extends StatelessWidget {
  final int day;
  final DateTime date;
  final bool isToday;
  final String? holiday;
  final Color theme;

  const _DayHeader({
    required this.day,
    required this.date,
    required this.isToday,
    required this.theme,
    this.holiday,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1.2),
      decoration: BoxDecoration(
        color: isToday ? theme.withValues(alpha: 0.32) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                weekdayName(day),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: isToday ? Colors.white : Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                holiday == null ? fmtDateShort(date) : '${fmtDateShort(date)} $holiday',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: isToday || holiday != null ? FontWeight.w700 : FontWeight.w500,
                  color: holiday != null
                      ? const Color(0xFFFF8A80)
                      : isToday
                          ? Colors.white.withValues(alpha: 0.95)
                          : Colors.white.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 回到本周悬浮按钮。
class _BackToThisWeek extends StatelessWidget {
  final Color theme;
  final VoidCallback onTap;
  const _BackToThisWeek({required this.theme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      radius: BorderRadius.circular(22),
      tintColor: theme,
      tintAlphaOverride: 0.45,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      onTap: onTap,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.arrow_back_rounded, size: 13, color: Colors.white),
          SizedBox(width: 4),
          Text('回到本周',
              style: TextStyle(
                  color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

// ---------------- 面板 ----------------

void showCourseActions(BuildContext context, Course c) {
  final state = context.read<AppState>();
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => LiquidGlass(
      radius: BorderRadius.circular(24),
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 16),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      tintAlphaOverride: 0.34,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(c.name,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('${weekdayName(c.day)} · ${periodOf(c.startPeriod).range} ~ ${periodOf(c.endPeriod).range} · ${Weeks.describe(c.weeks)}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12)),
          const SizedBox(height: 14),
          _ActionRow(
            icon: Icons.edit_rounded,
            label: '编辑课程',
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                  glassRoute(CourseEditScreen.course(c, context.read<AppState>())));
            },
          ),
          _ActionRow(
            icon: Icons.palette_rounded,
            label: '更换颜色',
            onTap: () {
              Navigator.of(context).pop();
              showColorPickModal(context, c);
            },
          ),
          const Divider(color: Colors.white12, height: 18),
          _ActionRow(
            icon: Icons.delete_outline_rounded,
            label: '删除课程',
            danger: true,
            onTap: () async {
              Navigator.of(context).pop();
              await state.deleteCourse(c);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已删除课程'), duration: Duration(seconds: 1)),
                );
              }
            },
          ),
        ],
      ),
    ),
  );
}

/// 更换课程颜色弹窗。
Future<void> showColorPickModal(BuildContext context, Course c) {
  final state = context.read<AppState>();
  var selected = c.colorValue;
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) => LiquidGlass(
        radius: BorderRadius.circular(24),
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 16),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        tintAlphaOverride: 0.34,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('课程卡片颜色',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final color in kCourseColors)
                  GestureDetector(
                    onTap: () => setModalState(() => selected = color),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border: selected == color
                            ? Border.all(color: Colors.white, width: 2.5)
                            : Border.all(color: Colors.white.withValues(alpha: 0.25)),
                      ),
                      child: selected == color
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: LiquidGlass(
                radius: BorderRadius.circular(14),
                padding: EdgeInsets.zero,
                tintColor: Color(selected),
                tintAlphaOverride: 0.8,
                onTap: () async {
                  await state.updateCourse(c.copyWith(colorValue: selected));
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                child: const Center(
                  child: Text('确定',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;
  final VoidCallback onTap;
  const _ActionRow({required this.icon, required this.label, this.danger = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFFF6B6B) : Colors.white;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color.withValues(alpha: 0.9)),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 14.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ---------------- 分享 / 菜单 ----------------

void _showShareSheet(BuildContext context) {
  final state = context.read<AppState>();
  final week = state.browseWeek;
  final sb = StringBuffer()..writeln('【$kAppName · 第$week周课表】');
  for (var d = 1; d <= 7; d++) {
    final list = state.coursesOn(d, week);
    if (list.isEmpty) continue;
    sb.writeln('${weekdayName(d)} ${fmtDateShort(state.dateOf(week, d))}：');
    for (final c in list) {
      sb.writeln('  ${periodOf(c.startPeriod).range}~${periodOf(c.endPeriod).range} ${c.name}'
          '${c.location.isNotEmpty ? " @${c.location}" : ""}（${Weeks.describe(c.weeks)}）');
    }
  }
  final text = sb.toString();
  final ids = state.currentCourses
      .map((c) => c.sourceId)
      .whereType<int>()
      .toSet()
      .toList();
  final token = ids.isEmpty ? null : buildShareToken(ids);

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => LiquidGlass(
      radius: BorderRadius.circular(24),
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 16),
      padding: const EdgeInsets.all(18),
      tintAlphaOverride: 0.34,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('分享本周课表',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Container(
            height: 150,
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SingleChildScrollView(
              child: Text(text,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11.5, height: 1.5)),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: LiquidGlass(
                    radius: BorderRadius.circular(14),
                    padding: EdgeInsets.zero,
                    tintColor: themeColorOf(state.settings),
                    tintAlphaOverride: 0.8,
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: text));
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已复制到剪贴板'), duration: Duration(seconds: 1)),
                        );
                      }
                    },
                    child: const Center(
                      child: Text('复制文字',
                          style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
              ),
              if (token != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: LiquidGlass(
                      radius: BorderRadius.circular(14),
                      padding: EdgeInsets.zero,
                      tintAlphaOverride: 0.18,
                      onTap: () async {
                        await Clipboard.setData(ClipboardData(text: token));
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('已复制课表口令，同学粘贴到「导入课表」即可'),
                                duration: Duration(seconds: 2)),
                          );
                        }
                      },
                      child: const Center(
                        child: Text('复制课表口令',
                            style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    ),
  );
}

void _showMenuSheet(BuildContext context) {
  final state = context.read<AppState>();
  final hasUcas = state.currentCourses.any((c) => c.isFromUcas);
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => LiquidGlass(
      radius: BorderRadius.circular(24),
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 16),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      tintAlphaOverride: 0.34,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ActionRow(
            icon: Icons.upload_file_rounded,
            label: '导入课表（个人课表网页 / 课表口令）',
            onTap: () {
              Navigator.of(context).pop();
              showImportEntrySheet(context);
            },
          ),
          if (hasUcas)
            _ActionRow(
              icon: Icons.refresh_rounded,
              label: '刷新课表（重新获取时间地点）',
              onTap: () {
                Navigator.of(context).pop();
                runScheduleRefresh(context);
              },
            ),
          if (hasUcas)
            _ActionRow(
              icon: Icons.sync_rounded,
              label: '重新登录选课系统同步课表',
              onTap: () {
                Navigator.of(context).pop();
                runSepLoginImport(context);
              },
            ),
          _ActionRow(
            icon: Icons.add_circle_outline_rounded,
            label: '添加课程',
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                  glassRoute(CourseEditScreen.course(null, context.read<AppState>())));
            },
          ),
          _ActionRow(
            icon: Icons.event_rounded,
            label: '学期（${state.currentSemester.label}）',
            onTap: () {
              Navigator.of(context).pop();
              showSemesterSheet(context);
            },
          ),
        ],
      ),
    ),
  );
}

// ---------------- 学期 ----------------

/// 学期弹层：切换 / 新建 / 修改开学日期 / 删除。
void showSemesterSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _SemesterSheet(),
  );
}

class _SemesterSheet extends StatelessWidget {
  const _SemesterSheet();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = themeColorOf(state.settings);
    final current = state.currentSemester;
    return LiquidGlass(
      radius: BorderRadius.circular(24),
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 16),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      tintAlphaOverride: 0.34,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('学期',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('课程按学期分开保存，切换学期后主页只显示该学期的课程',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final s in state.semesters)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: LiquidGlass(
                      radius: BorderRadius.circular(14),
                      tintColor: s.key == current.key ? theme : Colors.white,
                      tintAlphaOverride: s.key == current.key ? 0.6 : 0.14,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      onTap: () async {
                        await state.setCurrentSemester(s.key);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.label,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 2),
                                Text('${s.startDate} 开学 · ${s.weekCount} 周 · ${state.courseCountOf(s.key)} 门课',
                                    style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.65), fontSize: 11)),
                              ],
                            ),
                          ),
                          if (s.key == current.key)
                            const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 18),
          _ActionRow(
            icon: Icons.edit_calendar_rounded,
            label: '修改当前学期开学日期（${current.startDate}）',
            onTap: () {
              Navigator.of(context).pop();
              pickStartDate(context);
            },
          ),
          _ActionRow(
            icon: Icons.tune_rounded,
            label: '修改当前学期周数（${current.weekCount} 周）',
            onTap: () => _pickWeekCount(context, current),
          ),
          _ActionRow(
            icon: Icons.add_rounded,
            label: '新建学期',
            onTap: () {
              Navigator.of(context).pop();
              createSemester(context);
            },
          ),
          if (state.semesters.length > 1)
            _ActionRow(
              icon: Icons.delete_outline_rounded,
              label: '删除当前学期及其课程',
              danger: true,
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: kDeepSurface,
                    title: const Text('删除学期', style: TextStyle(color: Colors.white)),
                    content: Text('将删除「${current.label}」及其 ${state.courseCountOf(current.key)} 门课程，确定吗？',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消', style: TextStyle(color: Colors.white70))),
                      TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('删除', style: TextStyle(color: Color(0xFFFF6B6B)))),
                    ],
                  ),
                );
                if (ok == true) {
                  await state.deleteSemester(current.key);
                  if (context.mounted) Navigator.of(context).pop();
                }
              },
            ),
        ],
      ),
    );
  }

  Future<void> _pickWeekCount(BuildContext context, Semester current) async {
    final state = context.read<AppState>();
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: kDeepSurface,
        title: const Text('学期周数', style: TextStyle(color: Colors.white)),
        children: [
          for (final n in [16, 18, 20])
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(n),
              child: Text('$n 周${n == current.weekCount ? '（当前）' : ''}',
                  style: const TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
    if (picked != null && picked != current.weekCount) {
      await state.upsertSemester(current.copyWith(weekCount: picked));
      state.setBrowseWeek(state.browseWeek);
    }
  }
}

/// 新建学期：选开学日期 → 自动推断周数与名称。
Future<void> createSemester(BuildContext context) async {
  final state = context.read<AppState>();
  final picked = await showDatePicker(
    context: context,
    initialDate: DateTime.now(),
    firstDate: DateTime(2020),
    lastDate: DateTime(2035),
    helpText: '选择第 1 周的任意一天',
    builder: (ctx, child) => Theme(
      data: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
            seedColor: themeColorOf(state.settings), brightness: Brightness.dark),
      ),
      child: child!,
    ),
  );
  if (picked == null) return;
  final sem = await state.ensureSemester(picked);
  await state.setCurrentSemester(sem.key);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('已切换到 ${sem.label}（${sem.startDate} 开学，${sem.weekCount} 周）'),
        duration: const Duration(seconds: 2)));
  }
}

/// 修改当前学期开学日期。
Future<void> pickStartDate(BuildContext context) async {
  final state = context.read<AppState>();
  final initial = parseDate(state.settings.startDate);
  final picked = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2020),
    lastDate: DateTime(2035),
    builder: (ctx, child) => Theme(
      data: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
            seedColor: themeColorOf(state.settings), brightness: Brightness.dark),
      ),
      child: child!,
    ),
  );
  if (picked != null) {
    await state.setStartDate(fmtDate(picked));
  }
}
