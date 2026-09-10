import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:class_manager/models/course.dart';
import 'package:class_manager/models/exam.dart';
import 'package:class_manager/models/periods.dart';
import 'package:class_manager/screens/ucas_login_screen.dart';
import 'package:class_manager/services/schedule_importer.dart';
import 'package:class_manager/services/schedule_parser.dart';
import 'package:class_manager/services/ucas_bitmask.dart';
import 'package:class_manager/services/ucas_course_resolver.dart';
import 'package:class_manager/services/ucas_person_schedule_parser.dart';
import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/theme/palette.dart';
import 'package:class_manager/utils/weeks.dart';
import 'package:class_manager/widgets/app_background.dart';
import 'package:class_manager/widgets/glass.dart';
import 'package:class_manager/utils/routes.dart';

// =====================================================================
// 入口：导入方式选择
// =====================================================================

/// 导入课表入口弹层：个人课表网页 / 粘贴口令 / 高级表格。
void showImportEntrySheet(BuildContext context) {
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
          const Text('导入课表',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('推荐直接登录 SEP，果小课会自动抓取选课系统的个人课表',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
          const SizedBox(height: 10),
          _EntryRow(
            icon: Icons.login_rounded,
            title: '登录选课系统自动导入',
            subtitle: 'SEP 账号 + 验证码，一步完成',
            onTap: () {
              Navigator.of(context).pop();
              runSepLoginImport(context);
            },
          ),
          _EntryRow(
            icon: Icons.language_rounded,
            title: '导入个人课表网页',
            subtitle: '另存的 .html / .mhtml / .har 文件',
            onTap: () {
              Navigator.of(context).pop();
              runPersonScheduleImport(context);
            },
          ),
          _EntryRow(
            icon: Icons.content_paste_rounded,
            title: '粘贴课程链接 / 课表口令',
            subtitle: '同学分享的 guoxiaoke: 口令，或 coursetime 链接',
            onTap: () {
              Navigator.of(context).pop();
              showPasteImportDialog(context);
            },
          ),
          _EntryRow(
            icon: Icons.table_chart_outlined,
            title: '高级：自制表格',
            subtitle: 'docx / xlsx 课表表格（不推荐）',
            onTap: () {
              Navigator.of(context).pop();
              runTableImport(context);
            },
          ),
        ],
      ),
    ),
  );
}

class _EntryRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _EntryRow({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.white.withValues(alpha: 0.9)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w600)),
                  Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10.5)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: Colors.white.withValues(alpha: 0.45)),
          ],
        ),
      ),
    );
  }
}

Future<Uint8List?> _readPicked(PlatformFile f) async {
  try {
    return await f.readAsBytes();
  } catch (_) {
    if (f.path != null) {
      try {
        return await File(f.path!).readAsBytes();
      } catch (_) {}
    }
  }
  return null;
}

void _toast(BuildContext context, String msg, {int seconds = 2}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), duration: Duration(seconds: seconds)));
}

// =====================================================================
// 路径 I3：登录 SEP 自动抓取
// =====================================================================

Future<void> runSepLoginImport(BuildContext context) async {
  final ps = await Navigator.of(context).push<PersonSchedule>(
    glassRoute<PersonSchedule>(const UcasLoginScreen()),
  );
  if (ps == null || !context.mounted) return;
  await openPreviewWithResolve(context, ps.ids,
      schedule: ps,
      sourceName: '选课系统 · ${ps.semesterLabel.isEmpty ? '个人课表' : ps.semesterLabel}');
}

// =====================================================================
// 路径 I2 / I0：个人课表网页
// =====================================================================

Future<void> runPersonScheduleImport(BuildContext context) async {
  final f = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: ['html', 'htm', 'mhtml', 'mht', 'har', 'txt'],
  );
  if (f == null) return;
  final bytes = await _readPicked(f);
  if (bytes == null) {
    if (context.mounted) _toast(context, '无法读取文件');
    return;
  }
  final ps = parsePersonScheduleBytes(bytes);
  if (!context.mounted) return;
  if (ps == null || ps.isEmpty) {
    _toast(context, '未在文件中找到课程链接。请确认另存的是「学期课表 → 个人课表」页面', seconds: 3);
    return;
  }
  await openPreviewWithResolve(context, ps.ids, schedule: ps, sourceName: f.name);
}

// =====================================================================
// 路径 I1：粘贴
// =====================================================================

Future<void> showPasteImportDialog(BuildContext context) async {
  final ctl = TextEditingController();
  final text = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: kDeepSurface,
      title: const Text('粘贴课程链接 / 口令', style: TextStyle(color: Colors.white, fontSize: 16)),
      content: TextField(
        controller: ctl,
        maxLines: 6,
        autofocus: true,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'guoxiaoke:314787,314784,...\n或多条 https://xkcts.ucas.ac.cn:8443/course/coursetime/314787',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 11.5),
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消', style: TextStyle(color: Colors.white70))),
        TextButton(onPressed: () => Navigator.of(ctx).pop(ctl.text), child: const Text('导入', style: TextStyle(color: Colors.white))),
      ],
    ),
  );
  if (text == null || !context.mounted) return;
  final ids = extractCourseIds(text);
  if (ids.isEmpty) {
    _toast(context, '没有识别到课程编号');
    return;
  }
  await openPreviewWithResolve(context, ids, sourceName: '粘贴的 ${ids.length} 个课程编号');
}

// =====================================================================
// 在线补全 + 预览
// =====================================================================

/// 在线补全 + 打开预览页（所有导入路径的汇聚点）。
Future<void> openPreviewWithResolve(BuildContext context, List<int> ids,
    {PersonSchedule? schedule, String sourceName = ''}) async {
  final report = await _resolveWithProgress(context, ids);
  if (!context.mounted) return;

  final state = context.read<AppState>();
  final term = report?.term;
  final loginWall = report?.loginWall ?? false;

  // 目标学期：接口给出 firstDay → 自动建 / 匹配学期；否则用当前学期
  var targetKey = state.settings.currentSemesterKey;
  String? semesterNotice;
  if (term?.firstDay != null) {
    final sem = await state.ensureSemester(term!.firstDay!,
        label: term.shortName.isNotEmpty ? term.shortName : null, termId: term.id);
    targetKey = sem.key;
    if (sem.key != state.settings.currentSemesterKey) {
      semesterNotice = '课表属于 ${sem.label}（${sem.startDate} 开学），导入后将自动切换到该学期';
    }
  }
  final maxWeek = state.semesterByKey(targetKey).weekCount;

  // 组装预览条目
  final items = <PreviewItem>[];
  final resolvedIds = <int>{};
  if (report != null) {
    for (final rc in report.courses) {
      resolvedIds.add(rc.courseId);
      final fallbackName = schedule?.names[rc.courseId] ?? '';
      final parsed = rc.toParsedCourses(maxWeek: maxWeek, nameFallback: fallbackName);
      if (parsed.isEmpty) {
        items.add(PreviewItem(
          courseId: rc.courseId,
          name: rc.name.isNotEmpty ? rc.name : fallbackName,
          courses: const [],
          status: PreviewStatus.noSchedule,
        ));
      } else {
        items.add(PreviewItem(courseId: rc.courseId, name: parsed.first.name, courses: parsed));
      }
    }
  }
  // 失败 / 无网络：用网格离线兜底
  final failed = ids.where((id) => !resolvedIds.contains(id)).toList();
  for (final id in failed) {
    final err = report?.errors.where((e) => e.courseId == id).firstOrNull;
    final cells = schedule?.cells[id];
    final name = schedule?.names[id] ?? '课程 $id';
    if (cells != null && cells.isNotEmpty) {
      items.add(PreviewItem(
        courseId: id,
        name: name,
        courses: offlineCoursesFromCells(id, name, cells),
        status: PreviewStatus.offline,
        message: err?.label ?? '未联网',
      ));
    } else {
      items.add(PreviewItem(
        courseId: id,
        name: name,
        courses: const [],
        status: PreviewStatus.failed,
        message: err?.label ?? '未联网',
      ));
    }
  }
  // 按原始顺序
  items.sort((a, b) => ids.indexOf(a.courseId).compareTo(ids.indexOf(b.courseId)));

  if (!context.mounted) return;
  if (items.isEmpty) {
    _toast(context, '没有可导入的课程');
    return;
  }
  await Navigator.of(context).push(glassRoute(ImportPreviewScreen(
    items: items,
    sourceName: sourceName,
    semesterKey: targetKey,
    semesterNotice: semesterNotice,
    loginWall: loginWall,
    moocNotes: schedule?.moocNotes ?? const [],
  )));
}

/// 在线补全器工厂（测试时可替换为假实现）。
UcasCourseResolver Function() ucasResolverFactory = () => UcasCourseResolver();

/// 带进度弹窗的在线补全；网络完全不可用时返回 null。
///
/// 注意：不要在 [showDialog] 的 builder 里注册 future 回调——builder 可能被多次调用，
/// 会导致弹窗被 pop 多次并把下层页面一起弹掉（Navigator `_debugLocked` 断言）。
Future<ResolveReport?> _resolveWithProgress(BuildContext context, List<int> ids) async {
  final progress = ValueNotifier<(int, int)>((0, ids.length));
  final resolver = ucasResolverFactory();
  final navigator = Navigator.of(context);

  var dialogOpen = true;
  final dialogFuture = showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: kDeepSurface,
        content: ValueListenableBuilder<(int, int)>(
          valueListenable: progress,
          builder: (_, v, child) => Row(
            children: [
              const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
              const SizedBox(width: 16),
              Expanded(
                child: Text('正在从选课系统获取课程信息… ${v.$1}/${v.$2}',
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    ),
  ).whenComplete(() => dialogOpen = false);

  ResolveReport? report;
  try {
    report = await resolver.resolve(ids, onProgress: (d, t) => progress.value = (d, t));
  } catch (_) {
    report = null;
  }
  // 精确关闭一次进度弹窗
  if (dialogOpen && navigator.mounted) {
    navigator.pop();
  }
  await dialogFuture;
  progress.dispose();
  return report;
}

/// I0：由网格格子生成离线课程（周次全周）。
List<ParsedCourse> offlineCoursesFromCells(int id, String name, Set<(int, int)> cells) {
  final byDay = <int, List<int>>{};
  for (final (d, p) in cells) {
    byDay.putIfAbsent(d, () => []).add(p);
  }
  final result = <ParsedCourse>[];
  for (final e in byDay.entries) {
    final sorted = e.value.toSet().toList()..sort();
    for (final run in splitRuns(sorted)) {
      result.add(ParsedCourse(
        name: name,
        day: e.key,
        startPeriod: run.first.clamp(1, kPeriodCount),
        endPeriod: run.last.clamp(1, kPeriodCount),
        weeks: '',
        note: '离线导入，周次未知，联网后请「刷新课表」',
        sourceId: id,
      ));
    }
  }
  result.sort((a, b) => a.day != b.day ? a.day.compareTo(b.day) : a.startPeriod.compareTo(b.startPeriod));
  return result;
}

// =====================================================================
// 刷新课表
// =====================================================================

Future<void> runScheduleRefresh(BuildContext context) async {
  final state = context.read<AppState>();
  final ids = state.currentCourses.map((c) => c.sourceId).whereType<int>().toSet().toList();
  if (ids.isEmpty) {
    _toast(context, '当前学期没有来自选课系统的课程');
    return;
  }
  final report = await _resolveWithProgress(context, ids);
  if (!context.mounted) return;
  if (report == null) {
    _toast(context, '刷新失败：网络不可用');
    return;
  }
  final maxWeek = state.maxWeek;
  var updated = 0;
  for (final rc in report.courses) {
    if (!rc.hasSchedule) continue;
    await state.replaceCoursesFromSource(rc.courseId, rc.toParsedCourses(maxWeek: maxWeek));
    updated++;
  }
  if (!context.mounted) return;
  final failed = report.errors.length;
  _toast(context, '已刷新 $updated 门课程${failed > 0 ? '，$failed 门获取失败' : ''}'
      '${report.loginWall ? '（接口需要登录）' : ''}');
}

// =====================================================================
// 高级：自制表格
// =====================================================================

Future<void> runTableImport(BuildContext context) async {
  final f = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: ['docx', 'xlsx', 'xls', 'html', 'htm'],
  );
  if (f == null) return;
  final bytes = await _readPicked(f);
  if (bytes == null) {
    if (context.mounted) _toast(context, '无法读取文件');
    return;
  }
  final import = await importScheduleFile(f.name, bytes);
  if (!context.mounted) return;
  if (import.courses.isEmpty) {
    _toast(context, '未解析出课程：${import.note.isEmpty ? '文件格式未识别' : import.note}', seconds: 3);
    return;
  }
  final state = context.read<AppState>();
  await Navigator.of(context).push(glassRoute(ImportPreviewScreen(
    items: [
      for (var i = 0; i < import.courses.length; i++)
        PreviewItem(courseId: -1 - i, name: import.courses[i].name, courses: [import.courses[i]]),
    ],
    sourceName: f.name,
    semesterKey: state.settings.currentSemesterKey,
    note: import.note,
  )));
}

// =====================================================================
// 预览页
// =====================================================================

enum PreviewStatus { ok, offline, noSchedule, failed }

/// 预览列表中的一门课（可含多个时段）。
class PreviewItem {
  final int courseId;
  final String name;
  final List<ParsedCourse> courses;
  final PreviewStatus status;
  final String message;
  bool selected;

  PreviewItem({
    required this.courseId,
    required this.name,
    required this.courses,
    this.status = PreviewStatus.ok,
    this.message = '',
  }) : selected = courses.isNotEmpty;

  bool get importable => courses.isNotEmpty;
}

/// 导入预览：逐门勾选 / 修改，追加或覆盖导入。
class ImportPreviewScreen extends StatefulWidget {
  final List<PreviewItem> items;
  final String sourceName;
  final String semesterKey;
  final String? semesterNotice;
  final bool loginWall;
  final List<MoocNote> moocNotes;
  final String note;

  const ImportPreviewScreen({
    super.key,
    required this.items,
    required this.sourceName,
    required this.semesterKey,
    this.semesterNotice,
    this.loginWall = false,
    this.moocNotes = const [],
    this.note = '',
  });

  @override
  State<ImportPreviewScreen> createState() => _ImportPreviewScreenState();
}

class _ImportPreviewScreenState extends State<ImportPreviewScreen> {
  late final List<PreviewItem> _items = widget.items;
  bool _addMoocDeadlines = true;

  List<ParsedCourse> get _selectedCourses =>
      [for (final it in _items) if (it.selected) ...it.courses];

  Future<void> _doImport({required bool replace}) async {
    final state = context.read<AppState>();
    final list = _selectedCourses;
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('没有勾选任何课程'), duration: Duration(seconds: 1)));
      return;
    }
    await state.importCourses(list, replace: replace, semesterKey: widget.semesterKey);
    if (widget.semesterKey != state.settings.currentSemesterKey) {
      await state.setCurrentSemester(widget.semesterKey);
    }
    var moocAdded = 0;
    if (_addMoocDeadlines) {
      for (final m in widget.moocNotes) {
        if (m.end == null) continue;
        final name = '慕课截止 · ${m.name}';
        if (state.exams.any((e) => e.name == name)) continue;
        await state.addExam(Exam(name: name, date: fmtDate(m.end!), note: m.raw));
        moocAdded++;
      }
    }
    if (mounted) {
      Navigator.of(context).pop();
      final n = _items.where((i) => i.selected).length;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${replace ? '已清空本学期旧课表并导入' : '已追加导入'} $n 门课程'
              '${moocAdded > 0 ? '，$moocAdded 项慕课截止已加入考试倒计时' : ''}'),
          duration: const Duration(seconds: 2)));
    }
  }

  Future<void> _editItem(int index) async {
    final item = _items[index];
    if (item.courses.isEmpty) return;
    final edited = await Navigator.of(context).push<List<ParsedCourse>>(
      glassRoute<List<ParsedCourse>>(_ParsedEditScreen(item: item)),
    );
    if (edited != null) {
      setState(() => _items[index] = PreviewItem(
            courseId: item.courseId,
            name: edited.isNotEmpty ? edited.first.name : item.name,
            courses: edited,
            status: item.status,
            message: item.message,
          )..selected = item.selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = themeColorOf(state.settings);
    final sem = state.semesterByKey(widget.semesterKey);
    final okCount = _items.where((i) => i.status == PreviewStatus.ok).length;
    final failCount = _items.where((i) => i.status == PreviewStatus.failed || i.status == PreviewStatus.offline).length;
    return BackgroundedScaffold(
      child: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                GlassIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  size: 34,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                const Text('导入课表',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 8),
            // 文件信息
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LiquidGlass(
                radius: BorderRadius.circular(12),
                tintColor: theme,
                tintAlphaOverride: 0.12,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                child: Row(
                  children: [
                    Icon(Icons.description_outlined, size: 17, color: theme),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${widget.sourceName.isEmpty ? '导入' : widget.sourceName} · ${sem.label}（${sem.startDate} 开学）\n'
                        '已获取 $okCount 门${failCount > 0 ? ' · $failCount 门未获取（离线兜底 / 失败）' : ''}'
                        '${widget.note.isNotEmpty ? '\n${widget.note}' : ''}'
                        '${widget.semesterNotice != null ? '\n${widget.semesterNotice}' : ''}'
                        '${widget.loginWall ? '\n选课系统接口当前需要登录，已用网格离线数据代替（周次未知）' : ''}',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11.5, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            // 操作按钮
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: LiquidGlass(
                      radius: BorderRadius.circular(14),
                      padding: EdgeInsets.zero,
                      tintAlphaOverride: 0.18,
                      onTap: () => _doImport(replace: false),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 11),
                        child: Center(
                          child: Text('追加导入',
                              style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LiquidGlass(
                      radius: BorderRadius.circular(14),
                      padding: EdgeInsets.zero,
                      tintColor: theme,
                      tintAlphaOverride: 0.65,
                      onTap: () => _doImport(replace: true),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 11),
                        child: Center(
                          child: Text('清空本学期并导入',
                              style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 60),
                itemCount: _items.length + (widget.moocNotes.isNotEmpty ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i == _items.length) return _moocPanel(theme);
                  final item = _items[i];
                  final color = Color(kCourseColors[i % kCourseColors.length]);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: LiquidGlass(
                      radius: BorderRadius.circular(14),
                      tintAlphaOverride: item.importable ? 0.12 : 0.06,
                      padding: const EdgeInsets.all(12),
                      onTap: () => _editItem(i),
                      child: Row(
                        children: [
                          Checkbox(
                            value: item.selected,
                            onChanged: item.importable
                                ? (v) => setState(() => item.selected = v ?? false)
                                : null,
                            activeColor: theme,
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                          ),
                          Container(
                            width: 5,
                            height: 40,
                            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 3),
                                if (item.courses.isEmpty)
                                  Text(
                                    item.status == PreviewStatus.noSchedule ? '选课系统中没有时间安排' : '获取失败：${item.message}',
                                    style: TextStyle(color: const Color(0xFFFF9A9A).withValues(alpha: 0.9), fontSize: 11),
                                  )
                                else
                                  for (final pc in item.courses)
                                    Text(
                                      '${weekdayName(pc.day)} ${pc.periodsLabel} · ${Weeks.describe(pc.weeks)}'
                                      '${pc.location.isEmpty ? '' : ' · ${pc.location}'}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                                    ),
                                if (item.status == PreviewStatus.offline)
                                  Text('离线数据：周次按全周，联网后可刷新（${item.message}）',
                                      style: TextStyle(color: const Color(0xFFFFD180).withValues(alpha: 0.9), fontSize: 10.5)),
                              ],
                            ),
                          ),
                          Icon(Icons.edit_rounded, size: 16, color: Colors.white.withValues(alpha: 0.5)),
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
    );
  }

  Widget _moocPanel(Color theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: LiquidGlass(
        radius: BorderRadius.circular(14),
        tintAlphaOverride: 0.10,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('以下慕课课程不在课表网格中，无法导入为课程：',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            for (final m in widget.moocNotes)
              Text(
                '· ${m.name}${m.start != null && m.end != null ? '  ${fmtDateShort(m.start!)} ~ ${fmtDateShort(m.end!)}' : ''}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 11.5, height: 1.5),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                Checkbox(
                  value: _addMoocDeadlines,
                  onChanged: (v) => setState(() => _addMoocDeadlines = v ?? false),
                  activeColor: theme,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                ),
                const Expanded(
                  child: Text('把慕课截止日期加入「考试倒计时」',
                      style: TextStyle(color: Colors.white, fontSize: 12.5)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 单门课程（含多个时段）的快速编辑：改名 / 地点 / 教师，时段逐条调整。
class _ParsedEditScreen extends StatefulWidget {
  final PreviewItem item;
  const _ParsedEditScreen({required this.item});

  @override
  State<_ParsedEditScreen> createState() => _ParsedEditScreenState();
}

class _ParsedEditScreenState extends State<_ParsedEditScreen> {
  late final TextEditingController _nameCtl;
  late final TextEditingController _teacherCtl;
  late List<Course> _slots;

  @override
  void initState() {
    super.initState();
    final first = widget.item.courses.first;
    _nameCtl = TextEditingController(text: first.name);
    _teacherCtl = TextEditingController(text: first.teacher);
    _slots = [
      for (final pc in widget.item.courses)
        Course(
          name: pc.name,
          teacher: pc.teacher,
          location: pc.location,
          note: pc.note,
          day: pc.day,
          startPeriod: pc.startPeriod,
          endPeriod: pc.endPeriod,
          weeks: pc.weeks,
          sourceId: pc.sourceId,
          courseCode: pc.courseCode,
        ),
    ];
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _teacherCtl.dispose();
    super.dispose();
  }

  List<ParsedCourse> _build() => [
        for (final c in _slots)
          ParsedCourse(
            name: _nameCtl.text.trim(),
            teacher: _teacherCtl.text.trim(),
            location: c.location,
            note: c.note,
            day: c.day,
            startPeriod: c.startPeriod,
            endPeriod: c.endPeriod,
            weeks: c.weeks,
            sourceId: c.sourceId,
            courseCode: c.courseCode,
          ),
      ];

  @override
  Widget build(BuildContext context) {
    final theme = themeColorOf(context.watch<AppState>().settings);
    return BackgroundedScaffold(
      child: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                GlassIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  size: 34,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                const Text('修正课程信息',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                const Spacer(),
                LiquidGlass(
                  radius: BorderRadius.circular(18),
                  padding: EdgeInsets.zero,
                  tintColor: theme,
                  tintAlphaOverride: 0.75,
                  onTap: () => Navigator.of(context).pop(_build()),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    child: Text('完成',
                        style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 60),
                children: [
                  _field('课程名称 *', _nameCtl),
                  const SizedBox(height: 10),
                  _field('任课老师', _teacherCtl),
                  const SizedBox(height: 16),
                  for (var i = 0; i < _slots.length; i++) ...[
                    _SlotEditor(
                      slot: _slots[i],
                      onChanged: (c) => setState(() => _slots[i] = c),
                      onDelete: _slots.length > 1 ? () => setState(() => _slots.removeAt(i)) : null,
                    ),
                    const SizedBox(height: 10),
                  ],
                  Text('提示：点击星期 / 节次可快速调整；周次请用完整编辑（导入后点课程卡片）。',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 10.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctl) {
    return LiquidGlass(
      radius: BorderRadius.circular(14),
      tintAlphaOverride: 0.14,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: TextField(
        controller: ctl,
        style: const TextStyle(color: Colors.white, fontSize: 14.5),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}

class _SlotEditor extends StatelessWidget {
  final Course slot;
  final ValueChanged<Course> onChanged;
  final VoidCallback? onDelete;
  const _SlotEditor({required this.slot, required this.onChanged, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final c = slot;
    return LiquidGlass(
      radius: BorderRadius.circular(14),
      tintAlphaOverride: 0.14,
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onChanged(c.copyWith(day: c.day % 7 + 1)),
                  child: _cell('星期', weekdayName(c.day)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    final span = c.endPeriod - c.startPeriod;
                    var s = c.startPeriod + 1;
                    if (s + span > kPeriodCount) s = 1;
                    onChanged(c.copyWith(startPeriod: s, endPeriod: s + span));
                  },
                  child: _cell('节次', '${c.startPeriod}-${c.endPeriod}节'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: _cell('周次', Weeks.describe(c.weeks))),
              if (onDelete != null)
                IconButton(
                  onPressed: onDelete,
                  icon: Icon(Icons.close_rounded, size: 18, color: Colors.white.withValues(alpha: 0.6)),
                ),
            ],
          ),
          TextField(
            controller: TextEditingController(text: c.location)
              ..selection = TextSelection.collapsed(offset: c.location.length),
            onChanged: (v) => onChanged(c.copyWith(location: v)),
            style: const TextStyle(color: Colors.white, fontSize: 13.5),
            cursorColor: Colors.white,
            decoration: InputDecoration(
              labelText: '上课地点',
              labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(String label, String value) => Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10.5)),
            const SizedBox(height: 3),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800)),
          ],
        ),
      );
}
