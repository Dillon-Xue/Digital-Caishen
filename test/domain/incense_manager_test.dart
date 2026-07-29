import 'package:flutter_test/flutter_test.dart';
import 'package:digital_caishen/domain/incense_manager.dart';

void main() {
  test('点燃后生成燃烧中的一组香，且未燃尽不可叠加', () {
    var t = 1000;
    final m = IncenseManager(now: () => t);
    final g = m.lightIncense();
    expect(g, isNotNull);
    expect(m.activeGroup, isNotNull);
    expect(m.canLight, isFalse); // 有香在燃烧，禁止叠加

    expect(m.lightIncense(), isNull); // 第二次点燃被拦截
  });

  test('燃尽后结算：发放 1 个元宝，且可再次上香', () {
    var t = 1000000;
    final m = IncenseManager(now: () => t);
    m.lightIncense();

    // 差 1ms 到点：不结算、无元宝
    t = 1000000 + IncenseManager.incenseDurationMs - 1;
    expect(m.settle(), isEmpty);
    expect(m.totalCoins, 0);

    // 到点：结算 1 组、+1 元宝、active 清空
    t = 1000000 + IncenseManager.incenseDurationMs;
    final done = m.settle();
    expect(done.length, 1);
    expect(m.totalCoins, 1);
    expect(m.activeGroup, isNull);
    expect(m.canLight, isTrue);
  });

  test('离线补偿：应用关闭期间香已燃尽，重开时一次性结算', () {
    var t = 0;
    final m = IncenseManager(now: () => t);
    m.lightIncense();

    // 模拟「用户离开很久后重新打开」
    t = IncenseManager.incenseDurationMs + 1000;
    final done = m.settle();
    expect(done.length, 1);
    expect(m.totalCoins, 1);
  });

  test('燃烧进度随时间从 0 增至 1', () {
    var t = 0;
    final m = IncenseManager(now: () => t);
    final g = m.lightIncense()!;
    expect(m.progressOf(g), 0.0);

    t = (IncenseManager.incenseDurationMs * 0.5).round();
    expect(m.progressOf(g), closeTo(0.5, 0.001));

    t = IncenseManager.incenseDurationMs;
    expect(m.progressOf(g), 1.0);
  });

  test('快照可序列化并还原', () {
    var t = 5000;
    final m = IncenseManager(now: () => t);
    m.lightIncense();
    final snap = m.snapshot();

    final m2 = IncenseManager.fromSnapshot(snap, now: () => t);
    expect(m2.totalCoins, m.totalCoins);
    expect(m2.groups.length, 1);
    expect(m2.groups.first.id, m.groups.first.id);
  });
}
