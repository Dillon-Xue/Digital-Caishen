import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_state.dart';
import 'coin_burst.dart';
import 'ingot_drop.dart';
import 'smoke_particle.dart';

/// 桌面宠物：悬浮窗内渲染的财神神台。
///
/// - 空闲态显示「空香炉」神台图；燃烧态显示「带香+红点余烬+静态烟」的神台图，并叠加 CustomPainter 粒子烟雾。
/// - 点击反馈（每次轻点都触发，不论是否成功上香）：
///   神台弹性「点头」缩放 + 一句随机祝福气泡飘出 + 轻微震动。
/// - 香燃尽时由 [IngotDropLayer] 播放元宝掉落动画。
/// - 上香/拖拽/长按隐藏由原生层 [FloatingWindowService] 的 OnTouchListener 处理，
///   轻点经 MethodChannel("floating_window").onClick → [AppState.notifyTap] 驱动本层反馈。
class DesktopPet extends StatefulWidget {
  final AppState state;
  const DesktopPet({super.key, required this.state});

  @override
  State<DesktopPet> createState() => _DesktopPetState();
}

class _DesktopPetState extends State<DesktopPet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bump;
  String? _blessing;
  Timer? _blessingTimer;

  static const List<String> _blessings = [
    '财源广进！',
    '恭喜发财！',
    '招财进宝！',
    '今日宜发财',
    '心诚则灵',
    '万事如意',
  ];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _bump = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    widget.state.tapEvents.listen((_) => _onTap());
  }

  void _onTap() {
    // 弹性点头：1.0 -> 1.08 -> 1.0
    _bump.forward(from: 0);
    // 轻微震动（独立引擎下一般可用；异常则忽略）
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
    setState(() {
      _blessing = _blessings[_random.nextInt(_blessings.length)];
    });
    _blessingTimer?.cancel();
    _blessingTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _blessing = null);
    });
  }

  @override
  void dispose() {
    _blessingTimer?.cancel();
    _bump.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final burning = widget.state.activeGroup != null;
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _bump,
            builder: (ctx, child) {
              // sin 曲线让缩放在 1.0~1.08 之间来回一次，形成「点头」弹性感
              final scale = 1.0 + 0.08 * sin(_bump.value * pi);
              return Transform.scale(scale: scale, child: child);
            },
            child: Image.asset(
              burning
                  ? 'assets/images/caishen_shrine.png'
                  : 'assets/images/caishen_shrine_idle.png',
              fit: BoxFit.contain,
            ),
          ),
          if (burning) SmokeLayer(burning: burning),
          CoinBurstLayer(state: widget.state),
          IngotDropLayer(state: widget.state),
          if (_blessing != null)
            Positioned(
              top: 2,
              child: AnimatedOpacity(
                opacity: 1,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _blessing!,
                    style: const TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
