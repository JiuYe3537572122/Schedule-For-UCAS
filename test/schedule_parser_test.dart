import 'package:flutter_test/flutter_test.dart';

import 'package:class_manager/services/schedule_parser.dart';
import 'package:class_manager/utils/weeks.dart';

void main() {
  group('周数工具', () {
    test('解析区间/单点/混合', () {
      expect(Weeks.parse('1-16'), List.generate(16, (i) => i + 1));
      expect(Weeks.parse('2,15'), [2, 15]);
      expect(Weeks.parse('1-4,6,9-12'), [1, 2, 3, 4, 6, 9, 10, 11, 12]);
      expect(Weeks.parse('1，3、6周').length, greaterThanOrEqualTo(1));
    });

    test('空串 = 全周', () {
      expect(Weeks.parse(''), List.generate(kMaxWeek, (i) => i + 1));
      expect(Weeks.isAll(''), isTrue);
    });

    test('压缩与规范化', () {
      expect(Weeks.compress([for (var w = 1; w <= 16; w++) w]), '1-16');
      expect(Weeks.compress([2, 15]), '2,15');
      expect(Weeks.canonical('1-3,4-5'), '1-5');
      expect(Weeks.contains('1-16', 8), isTrue);
      expect(Weeks.contains('2,15', 3), isFalse);
      expect(Weeks.describe(''), '全周');
    });

    test('学期周数上限为 20 周', () {
      expect(kMaxWeek, 20);
      expect(Weeks.parse(''), List.generate(20, (i) => i + 1));
      expect(Weeks.compress([for (var w = 1; w <= 20; w++) w]), '',
          reason: '1-20 周 = 全周');
      expect(Weeks.contains('19-20', 20), isTrue);
      expect(Weeks.canonical('19-30'), '19-20', reason: '超出上限的周次应被裁剪');
    });
  });

  group('开学日期换算', () {
    const start = '2026-08-31'; // 国科大 2026 秋季学期第 1 周周一
    test('第 1 周', () {
      expect(weekOf(DateTime(2026, 8, 31), start), 1);
      expect(weekOf(DateTime(2026, 9, 6), start), 1);
    });
    test('第 2 周', () {
      expect(weekOf(DateTime(2026, 9, 7), start), 2);
    });
    test('第 20 周与上限裁剪', () {
      expect(weekOf(DateTime(2027, 1, 11), start), 20);
      expect(weekOf(DateTime(2027, 3, 1), start), 20, reason: '超出学期按上限');
      expect(weekOf(DateTime(2027, 3, 1), start, maxWeek: 18), 18);
    });
    test('dateOfWeekDay 往返', () {
      expect(fmtDateShort(dateOfWeekDay(1, 1, start)), '8/31');
      expect(fmtDate(dateOfWeekDay(1, 7, start)), '2026-09-06');
      expect(fmtDate(dateOfWeekDay(2, 1, start)), '2026-09-07');
    });
  });

  group('虚拟网格解析（通用路径）', () {
    test('星期列映射 + 竖排合并跨度', () {
      final grid = [
        [
          const RawCell(lines: ['节次']),
          const RawCell(lines: ['时间']),
          const RawCell(lines: ['星期一']),
          const RawCell(lines: ['星期二']),
        ],
        [
          const RawCell(lines: ['第一节']),
          const RawCell(lines: ['08:00~08:45']),
          const RawCell(lines: ['1-16周', '高等数学', '张三', '一教101'], rowspan: 2),
          const RawCell(lines: []),
        ],
        [
          const RawCell(lines: ['第二节']),
          const RawCell(lines: ['08:50~09:35']),
          const RawCell(lines: []),
          const RawCell(lines: []),
        ],
      ];
      final result = parseScheduleGrid(grid);
      expect(result.length, 1);
      expect(result.first.day, 1);
      expect(result.first.startPeriod, 1);
      expect(result.first.endPeriod, 2);
      expect(result.first.name, '高等数学');
      expect(result.first.teacher, '张三');
      expect(result.first.location, '一教101');
      expect(result.first.weeks, '1-16');
    });
  });
}
