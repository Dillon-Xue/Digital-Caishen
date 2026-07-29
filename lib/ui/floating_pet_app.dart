import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:digital_caishen/ui/app_state.dart';
import 'package:digital_caishen/ui/desktop_pet.dart';

/// 悬浮窗渲染主页：桌面宠物（财神神台）+ 接收原生「轻点」回调触发上香。
///
/// 由原生 [FloatingWindowService] 以初始路由 "/floating" 启动的独立 FlutterEngine 渲染。
/// 原生层拦截悬浮窗区域内的轻点后，通过 MethodChannel("floating_window") 的
/// "onClick" 方法回调至此，触发 [AppState.light]（上香）。
class FloatingPetHome extends StatefulWidget {
  final AppState state;
  const FloatingPetHome({super.key, required this.state});

  @override
  State<FloatingPetHome> createState() => _FloatingPetHomeState();
}

class _FloatingPetHomeState extends State<FloatingPetHome> {
  static const _channel = MethodChannel('floating_window');

  @override
  void initState() {
    super.initState();
    // 接收原生层转发的「轻点」事件，触发上香。
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onClick') {
        widget.state.light();
        return true;
      }
      return null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DesktopPet(state: widget.state);
  }
}
