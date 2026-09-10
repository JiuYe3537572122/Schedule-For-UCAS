import 'package:flutter_test/flutter_test.dart';

import 'package:class_manager/utils/greeting.dart';

/// 问候语时段划分与提醒文案。
void main() {
  Greeting at(int hour, [int minute = 0]) =>
      greetingFor(DateTime(2026, 9, 8, hour, minute));

  test('七个时间段划分正确', () {
    expect(at(23).hello, '夜深了');
    expect(at(0).hello, '夜深了');
    expect(at(4, 59).hello, '夜深了');

    expect(at(5).hello, '清晨好');
    expect(at(6, 59).hello, '清晨好');

    expect(at(7).hello, '早上好');
    expect(at(10, 59).hello, '早上好');

    expect(at(11).hello, '中午好');
    expect(at(12, 59).hello, '中午好');

    expect(at(13).hello, '下午好');
    expect(at(16, 59).hello, '下午好');

    expect(at(17).hello, '傍晚好');
    expect(at(18, 59).hello, '傍晚好');

    expect(at(19).hello, '晚上好');
    expect(at(22, 59).hello, '晚上好');
  });

  test('每个时段都有简短提醒', () {
    for (final h in [0, 5, 7, 11, 13, 17, 19]) {
      final g = at(h);
      expect(g.reminder.isNotEmpty, isTrue, reason: '$h 点缺少提醒文案');
    }
    expect(at(23).reminder, '别熬太晚，早点休息吧');
  });

  test('带姓名的问候', () {
    expect(at(20).withName('闫梓萱'), '晚上好，闫梓萱');
    expect(at(20).withName(''), '晚上好');
    expect(at(20).withName('   '), '晚上好');
  });
}
