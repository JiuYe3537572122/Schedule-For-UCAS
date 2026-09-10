import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:class_manager/models/exam.dart';
import 'package:class_manager/screens/exam_edit_screen.dart';
import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/theme/palette.dart';
import 'package:class_manager/utils/links.dart';
import 'package:class_manager/widgets/glass.dart';
import 'package:class_manager/utils/routes.dart';

/// 教务快捷入口。
class _QuickLink {
  final IconData icon;
  final String label;
  final String url;
  const _QuickLink(this.icon, this.label, this.url);
}

const List<_QuickLink> _kQuickLinks = [
  _QuickLink(Icons.calendar_month_rounded, '学校校历',
      'https://www.ucas.ac.cn/xxxl/14a8ce90538f4882a513fd21895c2d0e.htm'),
  _QuickLink(Icons.table_chart_rounded, '个人课表',
      'https://xkgo.ucas.ac.cn:3000/course/personSchedule'),
  _QuickLink(Icons.login_rounded, 'SEP 门户', 'https://sep.ucas.ac.cn/'),
  _QuickLink(Icons.meeting_room_rounded, '教室查询',
      'https://jwcg.ucas.ac.cn/classroom/day'),
  _QuickLink(Icons.assignment_rounded, '考试安排',
      'https://jwcg.ucas.ac.cn/public/showExamInfo'),
  _QuickLink(Icons.menu_book_rounded, '公开开课表',
      'https://jwba.ucas.ac.cn/sc/public/coursePublic'),
];

/// 发现页：教务快捷入口 + 考试倒计时。
class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = themeColorOf(state.settings);
    final upcoming = state.exams.where((e) => !e.isOver).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final overExams = state.exams.where((e) => e.isOver).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
        children: [
          const Center(
            child: Text('发现',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 14),
          // ---- 教务快捷入口 ----
          LiquidGlass(
            radius: BorderRadius.circular(20),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            tintAlphaOverride: 0.22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('教务快捷入口',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.35,
                  children: [
                    for (final l in _kQuickLinks)
                      _QuickTile(link: l, theme: theme),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ---- 考试倒计时 ----
          LiquidGlass(
            radius: BorderRadius.circular(20),
            padding: const EdgeInsets.all(14),
            tintAlphaOverride: 0.22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('考试倒计时',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        glassRoute(ExamEditScreen.exam(null, context.read<AppState>())),
                      ),
                      child: const Icon(Icons.add_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (upcoming.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Center(
                      child: Text('暂无考试安排，点击右上角 + 添加',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 12)),
                    ),
                  )
                else
                  for (final e in upcoming) _ExamCard(exam: e),
                if (overExams.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _CollapsedOverPanel(
                    count: overExams.length,
                    exams: overExams,
                    theme: theme,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  final _QuickLink link;
  final Color theme;
  const _QuickTile({required this.link, required this.theme});

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      radius: BorderRadius.circular(14),
      tintColor: theme,
      tintAlphaOverride: 0.14,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      onTap: () => openExternalLink(context, link.url),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: theme.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(link.icon, color: Colors.white, size: 16),
          ),
          const SizedBox(height: 6),
          Text(link.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// 单张考试卡片（点击可修改考试信息）。
class _ExamCard extends StatelessWidget {
  final Exam exam;
  const _ExamCard({required this.exam});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = themeColorOf(state.settings);
    final n = exam.daysFromNow();
    final chipColor = n <= 1 ? theme : Colors.white.withValues(alpha: 0.16);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: LiquidGlass(
        radius: BorderRadius.circular(14),
        tintAlphaOverride: 0.13,
        padding: const EdgeInsets.all(12),
        onTap: () => Navigator.of(context).push(
          glassRoute(ExamEditScreen.exam(exam, context.read<AppState>())),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 34,
              decoration: BoxDecoration(
                color: theme,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(exam.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(
                    '${exam.location}　${exam.date}${exam.timeLabel.isEmpty ? '' : ' ${exam.timeLabel}'}',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 11),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: chipColor,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(exam.statusLabel,
                  style: TextStyle(
                      color: n <= 1 ? Colors.white : Colors.white.withValues(alpha: 0.85),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}

/// 已结束考试折叠面板。
class _CollapsedOverPanel extends StatefulWidget {
  final int count;
  final List<Exam> exams;
  final Color theme;
  const _CollapsedOverPanel({
    required this.count,
    required this.exams,
    required this.theme,
  });

  @override
  State<_CollapsedOverPanel> createState() => _CollapsedOverPanelState();
}

class _CollapsedOverPanelState extends State<_CollapsedOverPanel> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('已结束考试（${widget.count}）',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
        // 丝滑展开/收起：高度与透明度同步过渡
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 340),
          sizeCurve: Curves.easeOutCubic,
          firstCurve: const Interval(0.35, 1.0, curve: Curves.easeOut),
          secondCurve: const Interval(0.0, 0.65, curve: Curves.easeIn),
          crossFadeState:
              _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Column(
            children: [for (final e in widget.exams) _ExamCard(exam: e)],
          ),
        ),
      ],
    );
  }
}
