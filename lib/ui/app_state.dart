import 'dart:async';
import 'package:flutter/material.dart';
import 'package:digital_caishen/domain/incense_group.dart';
import 'package:digital_caishen/domain/incense_manager.dart';
import 'package:digital_caishen/domain/persistence.dart';

/// 全局状态控制器：持有 [IncenseManager]，按秒驱动结算并广播给 UI。
///
/// 采用单一数据源 + 定时结算，天然兼容「应用退到后台/关闭后重新打开」的离线补偿：
/// 启动时先结算一次（补偿离线期间燃尽的香），之后每秒结算一次。
class AppState extends ChangeNotifier {
  final IncenseManager _manager;
  final Persistence _persistence;
  Timer? _timer;

  final StreamController<int> _ingotDropController =
      StreamController<int>.broadcast();

  /// 元宝掉落事件流（每结算完成一组香，发出掉落数量），供动画层订阅。
  Stream<int> get ingotDrops => _ingotDropController.stream;

  final StreamController<void> _tapController =
      StreamController<void>.broadcast();

  /// 悬浮窗内轻点事件流（每次点击都发出，无论是否成功上香），用于触发
  /// 点头动画、祝福气泡、撒金币等互动反馈。
  Stream<void> get tapEvents => _tapController.stream;

  AppState(this._manager, this._persistence) {
    _settleAndPersist(); // 离线补偿
    _startTicker();
  }

  IncenseManager get manager => _manager;
  int get totalCoins => _manager.totalCoins;
  IncenseGroup? get activeGroup => _manager.activeGroup;
  bool get canLight => _manager.canLight;

  double get progress =>
      activeGroup == null ? 0.0 : _manager.progressOf(activeGroup!);

  /// 上香。返回是否成功（失败=有香在燃烧，不可叠加）。
  bool light() {
    final g = _manager.lightIncense();
    if (g == null) return false;
    _persist();
    notifyListeners();
    return true;
  }

  /// 触发一次悬浮窗轻点的互动反馈（点头/祝福气泡/撒金币）。
  /// 不论 [light] 是否成功都调用，保证每次点击都有反馈。
  void notifyTap() => _tapController.add(null);

  List<IncenseGroup> _settleAndPersist() {
    final done = _manager.settle();
    if (done.isNotEmpty) _persist();
    return done;
  }

  void _startTicker() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final done = _settleAndPersist();
      notifyListeners();
      if (done.isNotEmpty) _ingotDropController.add(done.length);
    });
  }

  void _persist() => _persistence.save(_manager.snapshot());

  @override
  void dispose() {
    _timer?.cancel();
    _ingotDropController.close();
    _tapController.close();
    super.dispose();
  }
}
