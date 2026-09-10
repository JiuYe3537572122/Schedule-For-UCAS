import 'package:flutter_test/flutter_test.dart';

import 'package:class_manager/services/schedule_parser.dart';
import 'package:class_manager/state/app_state.dart';

/// 导入课表时的自动配色：不同课程不同色，同名课程同色。
void main() {
  ParsedCourse pc(String name, int day, int start, int end, [String weeks = '1-16']) =>
      ParsedCourse(
          name: name,
          day: day,
          startPeriod: start,
          endPeriod: end,
          weeks: weeks);

  test('导入时不同课程自动分配不同颜色', () async {
    final state = AppState.memory();
    await state.importCourses([
      pc('数理统计(05)', 1, 6, 8),
      pc('高级人工智能', 2, 6, 9),
      pc('工程伦理', 5, 6, 7, '2'),
      pc('工程伦理', 5, 6, 7, '15'), // 同名课程，应复用颜色
      pc('网络与信息系统安全', 5, 11, 13, '1-8'),
    ]);

    expect(state.courses.length, 5);

    // 4 门不同课程 → 4 种颜色
    final distinct = state.courses.map((c) => c.colorValue).toSet();
    expect(distinct.length, 4, reason: '不同课程应使用不同颜色，实际 $distinct');

    // 同名课程颜色一致
    final eng = state.courses
        .where((c) => c.name == '工程伦理')
        .map((c) => c.colorValue)
        .toSet();
    expect(eng.length, 1, reason: '同名课程应复用同一颜色');

    // 不再是「全部同一个颜色」
    expect(state.courses.first.colorValue, isNot(state.courses[1].colorValue));
  });

  test('追加导入时避开已有课程的颜色', () async {
    final state = AppState.memory();
    await state.importCourses([pc('课程A', 1, 1, 2)]);
    final firstColor = state.courses.first.colorValue;

    await state.importCourses([pc('课程B', 2, 1, 2)]);
    final secondColor = state.courses.last.colorValue;

    expect(secondColor, isNot(firstColor), reason: '新课程应换一个颜色');
  });
}
