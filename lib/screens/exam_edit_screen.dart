import 'package:flutter/material.dart';

import 'package:class_manager/models/exam.dart';
import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/theme/palette.dart';
import 'package:class_manager/utils/weeks.dart';
import 'package:class_manager/widgets/app_background.dart';
import 'package:class_manager/widgets/glass.dart';

/// 考试编辑页：新增/编辑考试（名称、地点、日期、时间段、备注）。
class ExamEditScreen extends StatefulWidget {
  final Exam? exam;
  final AppState state;

  ExamEditScreen.exam(this.exam, this.state) : super(key: ValueKey(exam?.id ?? 'new'));

  @override
  State<ExamEditScreen> createState() => _ExamEditScreenState();
}

class _ExamEditScreenState extends State<ExamEditScreen> {
  late final TextEditingController _nameCtl;
  late final TextEditingController _locationCtl;
  late final TextEditingController _noteCtl;
  late DateTime _date;
  late String _startTime;
  late String _endTime;

  bool get _isNew => widget.exam == null;

  @override
  void initState() {
    super.initState();
    final e = widget.exam;
    _nameCtl = TextEditingController(text: e?.name ?? '');
    _locationCtl = TextEditingController(text: e?.location ?? '');
    _noteCtl = TextEditingController(text: e?.note ?? '');
    _date = e != null && e.date.isNotEmpty
        ? parseDate(e.date)
        : DateTime.now().add(const Duration(days: 7));
    _startTime = e?.startTime ?? '';
    _endTime = e?.endTime ?? '';
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _locationCtl.dispose();
    _noteCtl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final theme = themeColorOf(widget.state.settings);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.fromSeed(
                seedColor: theme, brightness: Brightness.dark)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final theme = themeColorOf(widget.state.settings);
    final current = isStart ? _startTime : _endTime;
    final init = current.isNotEmpty
        ? TimeOfDay(
            hour: int.parse(current.split(':')[0]),
            minute: int.parse(current.split(':')[1]))
        : const TimeOfDay(hour: 14, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: init,
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.fromSeed(
                seedColor: theme, brightness: Brightness.dark)),
        child: child!,
      ),
    );
    if (picked != null) {
      final s = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        if (isStart) {
          _startTime = s;
        } else {
          _endTime = s;
        }
      });
    }
  }

  Future<void> _save() async {
    final name = _nameCtl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请填写考试名称'), duration: Duration(seconds: 1)));
      return;
    }
    final e = Exam(
      id: widget.exam?.id,
      name: name,
      location: _locationCtl.text.trim(),
      date: fmtDate(_date),
      startTime: _startTime,
      endTime: _endTime,
      note: _noteCtl.text.trim(),
    );
    if (_isNew) {
      await widget.state.addExam(e);
    } else {
      await widget.state.updateExam(e);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final e = widget.exam;
    if (e == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kDeepSurface,
        title: const Text('删除考试', style: TextStyle(color: Colors.white)),
        content: Text('确定删除「${e.name}」吗？',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消', style: TextStyle(color: Colors.white70))),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('删除', style: TextStyle(color: Color(0xFFFF6B6B)))),
        ],
      ),
    );
    if (ok == true) {
      await widget.state.deleteExam(e);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = themeColorOf(widget.state.settings);
    return BackgroundedScaffold(
      child: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                GlassIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  size: 34,
                  blur: false,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                Text(_isNew ? '添加考试' : '编辑考试',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
                const Spacer(),
                LiquidGlass(
                  radius: BorderRadius.circular(18),
                  padding: EdgeInsets.zero,
                  tintColor: theme,
                  tintAlphaOverride: 0.75,
                  onTap: _save,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    child: Text('保存',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 60),
                children: [
                  _field('考试名称 *', _nameCtl, hint: '如：数理统计 期末考试'),
                  const SizedBox(height: 10),
                  _field('考试地点', _locationCtl, hint: '如：13-207'),
                  const SizedBox(height: 16),
                  // 日期
                  LiquidGlass(
                    radius: BorderRadius.circular(14),
                    tintAlphaOverride: 0.3,
                    blurOverride: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    onTap: _pickDate,
                    child: Row(
                      children: [
                        Icon(Icons.event_rounded, size: 19,
                            color: theme.withValues(alpha: 0.9)),
                        const SizedBox(width: 12),
                        const Text('考试日期',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 13.5)),
                        const Spacer(),
                        Text(fmtDate(_date),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded,
                            color: Colors.white.withValues(alpha: 0.5), size: 18),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // 时间段
                  Row(
                    children: [
                      Expanded(
                        child: LiquidGlass(
                          radius: BorderRadius.circular(14),
                          tintAlphaOverride: 0.3,
                    blurOverride: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                          onTap: () => _pickTime(isStart: true),
                          child: Column(
                            children: [
                              Text('开始时间',
                                  style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.6),
                                      fontSize: 11)),
                              const SizedBox(height: 4),
                              Text(_startTime.isEmpty ? '未设置' : _startTime,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: LiquidGlass(
                          radius: BorderRadius.circular(14),
                          tintAlphaOverride: 0.3,
                    blurOverride: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                          onTap: () => _pickTime(isStart: false),
                          child: Column(
                            children: [
                              Text('结束时间',
                                  style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.6),
                                      fontSize: 11)),
                              const SizedBox(height: 4),
                              Text(_endTime.isEmpty ? '未设置' : _endTime,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _field('备注', _noteCtl, hint: '选填', maxLines: 2),
                  if (!_isNew) ...[
                    const SizedBox(height: 16),
                    LiquidGlass(
                      radius: BorderRadius.circular(14),
                      padding: EdgeInsets.zero,
                      tintColor: const Color(0xFFFF6B6B),
                      tintAlphaOverride: 0.28,
                      onTap: _delete,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Text('删除考试',
                              style: TextStyle(
                                  color: Color(0xFFFF9A9A),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctl,
      {String? hint, int maxLines = 1}) {
    return LiquidGlass(
      radius: BorderRadius.circular(14),
      tintAlphaOverride: 0.3,
                    blurOverride: 0,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: TextField(
        controller: ctl,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white, fontSize: 14.5),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 13),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 12),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}
