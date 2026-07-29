import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_state.dart';

/// 主应用界面（正常 Activity 中显示）。
/// 展示元宝计数、上香状态，并提供「上香」与「开启/关闭悬浮窗」操作。
class ControlPanel extends StatefulWidget {
  final AppState state;
  const ControlPanel({super.key, required this.state});

  @override
  State<ControlPanel> createState() => _ControlPanelState();
}

class _ControlPanelState extends State<ControlPanel> {
  static const MethodChannel _channel = MethodChannel('app_control');
  bool _floating = false;
  String _hint = '';

  Future<void> _openFloating() async {
    try {
      final ok = await _channel.invokeMethod<bool>('startFloating');
      if (ok == true) {
        setState(() {
          _floating = true;
          _hint = '悬浮窗已开启';
        });
      } else {
        // 权限未授予：原生侧已引导用户去系统设置授权
        setState(() => _hint = '请在系统设置中允许「显示在其他应用上」后重试');
      }
    } on PlatformException catch (e) {
      setState(() => _hint = '开启失败：${e.message}');
    }
  }

  Future<void> _closeFloating() async {
    try {
      await _channel.invokeMethod('stopFloating');
      setState(() {
        _floating = false;
        _hint = '悬浮窗已关闭';
      });
    } on PlatformException catch (e) {
      setState(() => _hint = '关闭失败：${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return Scaffold(
      appBar: AppBar(title: const Text('财神驾到')),
      body: ListenableBuilder(
        listenable: state,
        builder: (ctx, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('累计元宝：${state.totalCoins}',
                  style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 16),
              Text(
                state.activeGroup == null
                    ? '状态：空闲，可上香'
                    : '状态：上香中 ${(state.progress * 100).toInt()}%',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: state.canLight ? () => state.light() : null,
                child: const Text('上香'),
              ),
              const SizedBox(height: 12),
              if (!_floating)
                ElevatedButton(
                  onPressed: _openFloating,
                  child: const Text('开启悬浮窗'),
                )
              else
                ElevatedButton(
                  onPressed: _closeFloating,
                  child: const Text('关闭悬浮窗'),
                ),
              const SizedBox(height: 12),
              if (_hint.isNotEmpty)
                Text(_hint, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
