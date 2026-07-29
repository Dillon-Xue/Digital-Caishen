/// 一组香的数据模型。
///
/// 规则（来自 PRD）：三炷香同时点燃、同时燃尽，每次结算掉落 1 个金元宝；
/// 一组香未燃尽时不可叠加；燃烧时长固定 30 分钟。
class IncenseGroup {
  final String id;
  final int startTime; // 点燃时刻，epoch 毫秒
  final int durationMs; // 燃烧时长，固定 30 分钟
  final bool completed; // 是否已燃尽并结算

  const IncenseGroup({
    required this.id,
    required this.startTime,
    required this.durationMs,
    this.completed = false,
  });

  /// 燃尽时刻 = 点燃时刻 + 时长
  int get endTime => startTime + durationMs;

  IncenseGroup copyWith({bool? completed}) => IncenseGroup(
        id: id,
        startTime: startTime,
        durationMs: durationMs,
        completed: completed ?? this.completed,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'startTime': startTime,
        'durationMs': durationMs,
        'completed': completed,
      };

  factory IncenseGroup.fromJson(Map<String, dynamic> json) => IncenseGroup(
        id: json['id'] as String,
        startTime: json['startTime'] as int,
        durationMs: json['durationMs'] as int,
        completed: json['completed'] as bool? ?? false,
      );
}
