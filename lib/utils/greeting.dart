/// 问候语：按时间段生成问候与一句简短提醒（用于「我的」页）。
class Greeting {
  /// 时段名称，如「晚上好」。
  final String hello;

  /// 一句话提醒。
  final String reminder;

  const Greeting(this.hello, this.reminder);

  /// 带上姓名的问候，如「晚上好，闫梓萱」。
  String withName(String name) =>
      name.trim().isEmpty ? hello : '$hello，${name.trim()}';
}

/// 时间段划分：
/// 深夜 23:00–04:59 · 清晨 05:00–06:59 · 早上 07:00–10:59 ·
/// 中午 11:00–12:59 · 下午 13:00–16:59 · 傍晚 17:00–18:59 · 晚上 19:00–22:59
Greeting greetingFor(DateTime now) {
  final h = now.hour;
  if (h >= 23 || h < 5) {
    return const Greeting('夜深了', '别熬太晚，早点休息吧');
  }
  if (h < 7) {
    return const Greeting('清晨好', '新的一天开始了，慢慢来也没关系');
  }
  if (h < 11) {
    return const Greeting('早上好', '别忘了吃早餐，今天也要元气满满');
  }
  if (h < 13) {
    return const Greeting('中午好', '记得好好吃饭，午休一会儿');
  }
  if (h < 17) {
    return const Greeting('下午好', '专注的同时，也要记得起身活动');
  }
  if (h < 19) {
    return const Greeting('傍晚好', '晚课加油，别太累啦');
  }
  return const Greeting('晚上好', '今天也辛苦啦，记得早点休息');
}
