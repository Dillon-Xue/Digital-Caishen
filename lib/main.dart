import 'package:flutter/material.dart';
import 'package:digital_caishen/domain/incense_manager.dart';
import 'package:digital_caishen/domain/persistence.dart';
import 'ui/app_state.dart';
import 'ui/control_panel.dart';
import 'ui/floating_pet_app.dart';

/// 主应用入口（普通 Activity 与悬浮窗引擎共用）。
///
/// 加载持久化状态 → 构建燃香管理器与全局状态控制器 [AppState]。
/// 通过「初始路由」区分渲染内容：
///   - 原生悬浮窗引擎传入 "/floating" → 渲染桌面宠物（财神神台）
///   - 普通启动（默认 "/"）         → 渲染控制面板
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final persistence = await Persistence.create();
  final snapshot = persistence.load();
  final clock = () => DateTime.now().millisecondsSinceEpoch;
  final manager = snapshot == null
      ? IncenseManager(now: clock)
      : IncenseManager.fromSnapshot(snapshot, now: clock);
  final state = AppState(manager, persistence);

  final route = WidgetsBinding.instance.platformDispatcher.defaultRouteName;
  final floating = route == '/floating';

  runApp(MaterialApp(
    title: '财神驾到',
    theme: ThemeData(scaffoldBackgroundColor: Colors.white),
    // 悬浮窗需透明背景，仅显示神台、其余区域透出下层应用。
    color: floating ? const Color(0x00000000) : null,
    home: floating ? FloatingPetHome(state: state) : ControlPanel(state: state),
    debugShowCheckedModeBanner: false,
  ));
}
