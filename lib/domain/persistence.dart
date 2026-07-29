import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'incense_manager.dart';

/// 本地持久化（SharedPreferences）。
///
/// 存储结构（与 PRD 一致）：
/// {
///   "totalCoins": 42,
///   "incenseList": [
///     { "id": "incense_...", "startTime": 1690000000000,
///       "durationMs": 1800000, "completed": false }
///   ]
/// }
class Persistence {
  static const String _kStoreKey = 'digital_caishen_state_v1';

  final SharedPreferences prefs;

  Persistence(this.prefs);

  static Future<Persistence> create() async {
    final prefs = await SharedPreferences.getInstance();
    return Persistence(prefs);
  }

  /// 读取快照；无数据返回 null。
  ManagerSnapshot? load() {
    final raw = prefs.getString(_kStoreKey);
    if (raw == null) return null;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final coins = (json['totalCoins'] as int?) ?? 0;
    final list = (json['incenseList'] as List?) ?? <dynamic>[];
    final groups = list
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return ManagerSnapshot(totalCoins: coins, groups: groups);
  }

  Future<void> save(ManagerSnapshot snapshot) async {
    final json = {
      'totalCoins': snapshot.totalCoins,
      'incenseList': snapshot.groups,
    };
    await prefs.setString(_kStoreKey, jsonEncode(json));
  }

  Future<void> clear() => prefs.remove(_kStoreKey);
}
