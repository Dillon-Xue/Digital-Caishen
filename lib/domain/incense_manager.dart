import 'incense_group.dart';

/// 当前时间来源，便于测试时注入假时钟。
typedef Clock = int Function();

/// 燃香业务核心：负责点燃、计时进度、离线/实时结算、元宝计数。
///
/// 设计原则：
/// - 纯 Dart，不依赖 Flutter 框架，可单测。
/// - 状态变更后立即可序列化（[snapshot]），由外部持久化层落盘。
/// - 计时基于时间戳而非实时计时器，天然支持后台/离线补偿。
class IncenseManager {
  /// 燃烧时长固定 30 分钟（不可配置）。
  static const int incenseDurationMs = 30 * 60 * 1000;

  /// 三炷香同时点燃。
  static const int sticksPerGroup = 3;

  /// 一组香燃尽掉落 1 个金元宝（不是 3 个）。
  static const int ingotsPerGroup = 1;

  final Clock now;
  final List<IncenseGroup> _groups;
  int _totalCoins;

  IncenseManager({
    required this.now,
    List<IncenseGroup> groups = const [],
    this._totalCoins = 0,
  })  : _groups = List.from(groups);

  int get totalCoins => _totalCoins;

  /// 不可变快照，供 UI 展示。
  List<IncenseGroup> get groups => List.unmodifiable(_groups);

  /// 当前正在燃烧的一组香（若有）。已燃尽的不会被当作 active。
  IncenseGroup? get activeGroup {
    for (var i = _groups.length - 1; i >= 0; i--) {
      if (!_groups[i].completed) return _groups[i];
    }
    return null;
  }

  /// 是否还能上香：仅当没有正在燃烧的香时才允许（未燃尽不可叠加）。
  bool get canLight => activeGroup == null;

  /// 点燃三炷香。
  /// 返回新建的香组；若已有香在燃烧（不可叠加）则返回 null。
  IncenseGroup? lightIncense() {
    if (!canLight) return null;
    final group = IncenseGroup(
      id: 'incense_${now()}',
      startTime: now(),
      durationMs: incenseDurationMs,
    );
    _groups.add(group);
    return group;
  }

  /// 结算所有已到点的香。
  /// 遍历每组：若未燃尽且当前时间 >= 燃尽时刻，则标记为完成、发放元宝。
  /// 返回本次新完成的香组（供掉落动画使用）。
  /// 该逻辑对实时计时与「重新打开应用时的离线补偿」通用。
  List<IncenseGroup> settle() {
    final completed = <IncenseGroup>[];
    for (var i = 0; i < _groups.length; i++) {
      final g = _groups[i];
      if (!g.completed && now() >= g.endTime) {
        _groups[i] = g.copyWith(completed: true);
        _totalCoins += ingotsPerGroup;
        completed.add(_groups[i]);
      }
    }
    return completed;
  }

  /// 某组香的燃烧进度 0.0 ~ 1.0。
  double progressOf(IncenseGroup group) {
    if (group.completed) return 1.0;
    final elapsed = now() - group.startTime;
    if (elapsed <= 0) return 0.0;
    return (elapsed / group.durationMs).clamp(0.0, 1.0);
  }

  /// 序列化为可持久化的快照。
  ManagerSnapshot snapshot() => ManagerSnapshot(
        totalCoins: _totalCoins,
        groups: _groups.map((g) => g.toJson()).toList(),
      );

  /// 从快照恢复。
  factory IncenseManager.fromSnapshot(ManagerSnapshot snapshot, {required Clock now}) {
    return IncenseManager(
      now: now,
      groups: snapshot.groups
          .map((j) => IncenseGroup.fromJson(j))
          .toList(),
      totalCoins: snapshot.totalCoins,
    );
  }
}

/// 持久化快照结构（对应 PRD 中的 JSON 结构）。
class ManagerSnapshot {
  final int totalCoins;
  final List<Map<String, dynamic>> groups;

  ManagerSnapshot({required this.totalCoins, required this.groups});
}
