import 'package:flutter_test/flutter_test.dart';

import 'package:class_manager/models/course.dart';
import 'package:class_manager/models/semester.dart';
import 'package:class_manager/services/schedule_parser.dart';
import 'package:class_manager/state/app_state.dart';
import 'package:class_manager/utils/weeks.dart';

/// 学期模型与按学期隔离课程。
void main() {
  group('Semester', () {
    test('按开学日期推断周数与名称，并规范到周一', () {
      final autumn = Semester.fromStart(DateTime(2026, 9, 2)); // 周三 → 周一 8-31
      expect(autumn.startDate, '2026-08-31');
      expect(autumn.weekCount, 20);
      expect(autumn.label, '2026年秋季学期');
      final spring = Semester.fromStart(DateTime(2027, 2, 22));
      expect(spring.weekCount, 18);
      expect(spring.label, '2027年春季学期');
    });

    test('预置学期与日期换算', () {
      final s = kBuiltinSemesters.first;
      expect(s.key, kDefaultSemesterKey);
      expect(s.weekOfDate(DateTime(2026, 8, 31)), 1);
      expect(s.weekOfDate(DateTime(2026, 10, 1)), 5);
      expect(s.weekOfDate(DateTime(2027, 1, 17)), 20);
      expect(fmtDate(s.dateOf(20, 7)), '2027-01-17');
      expect(s.holidayOn(DateTime(2026, 10, 1))?.name, '国庆');
      expect(s.holidayOn(DateTime(2026, 10, 2)), isNull);
    });

    test('JSON 往返', () {
      final list = [
        Semester.fromStart(DateTime(2027, 8, 30), termId: 12345),
        const Semester(startDate: '2028-02-28', weekCount: 16, label: '自定义'),
      ];
      final back = Semester.decodeList(Semester.encodeList(list));
      expect(back.length, 2);
      expect(back[0].termId, 12345);
      expect(back[1].weekCount, 16);
      expect(back[1].label, '自定义');
      expect(Semester.decodeList('not json'), isEmpty);
    });
  });

  group('Weeks 按学期周数', () {
    test('18 周学期全选压缩为全周', () {
      expect(Weeks.compress(List.generate(18, (i) => i + 1), maxWeek: 18), '');
      expect(Weeks.compress(List.generate(18, (i) => i + 1), maxWeek: 20), '1-18');
      expect(Weeks.parse('', maxWeek: 18).length, 18);
      expect(Weeks.canonical('19-20', maxWeek: 18), '18', reason: '超出学期周数被裁剪');
    });
  });

  group('AppState 学期隔离', () {
    ParsedCourse pc(String name, int day) =>
        ParsedCourse(name: name, day: day, startPeriod: 1, endPeriod: 2, weeks: '1-16');

    test('导入到指定学期；切换学期后只显示该学期课程', () async {
      final state = AppState.memory();
      expect(state.currentSemester.key, kDefaultSemesterKey);
      await state.importCourses([pc('A', 1)]);
      final spring = await state.ensureSemester(DateTime(2027, 2, 22));
      await state.importCourses([pc('B', 2), pc('C', 3)], semesterKey: spring.key);

      expect(state.courses.length, 3);
      expect(state.currentCourses.map((c) => c.name), ['A']);
      expect(state.courseCountOf(spring.key), 2);

      await state.setCurrentSemester(spring.key);
      expect(state.currentCourses.map((c) => c.name).toSet(), {'B', 'C'});
      expect(state.maxWeek, 18);
    });

    test('清空导入只清当前学期', () async {
      final state = AppState.memory();
      await state.importCourses([pc('A', 1)]);
      final spring = await state.ensureSemester(DateTime(2027, 2, 22));
      await state.importCourses([pc('B', 2)], semesterKey: spring.key);
      await state.importCourses([pc('A2', 1)], replace: true);
      expect(state.currentCourses.map((c) => c.name), ['A2']);
      expect(state.courseCountOf(spring.key), 1);
    });

    test('ensureSemester 自动建学期并带上 termId / label', () async {
      final state = AppState.memory();
      final s = await state.ensureSemester(DateTime(2027, 8, 30), label: '2027年秋季学期', termId: 99);
      expect(s.key, '2027-08-30');
      expect(s.termId, 99);
      expect(state.semesters.any((x) => x.key == '2027-08-30'), isTrue);
      // 再次调用返回同一学期，不重复
      final again = await state.ensureSemester(DateTime(2027, 9, 1));
      expect(again.key, '2027-08-30');
      expect(state.semesters.where((x) => x.key == '2027-08-30').length, 1);
    });

    test('删除学期连带删除课程并回退当前学期', () async {
      final state = AppState.memory();
      final spring = await state.ensureSemester(DateTime(2028, 2, 28)); // 非预置学期
      await state.importCourses([pc('B', 2)], semesterKey: spring.key);
      await state.setCurrentSemester(spring.key);
      await state.deleteSemester(spring.key);
      expect(state.courses, isEmpty);
      expect(state.currentSemester.key, isNot(spring.key));
    });

    test('替换来源课程保留颜色与备注', () async {
      final state = AppState.memory();
      await state.addCourse(Course(
          name: 'X', day: 1, startPeriod: 1, endPeriod: 2, weeks: '1-8',
          colorValue: 0xFF123456, note: '我的备注', sourceId: 42));
      await state.replaceCoursesFromSource(42, [
        ParsedCourse(name: 'X', day: 2, startPeriod: 3, endPeriod: 4, weeks: '9-16', sourceId: 42),
      ]);
      final c = state.currentCourses.single;
      expect(c.day, 2);
      expect(c.weeks, '9-16');
      expect(c.colorValue, 0xFF123456);
      expect(c.note, '我的备注');
    });
  });
}
