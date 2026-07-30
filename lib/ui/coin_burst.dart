import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'app_state.dart';

/// 撒金币特效层。订阅 [AppState.tapEvents]，每次轻点从财神中心撒出若干枚旋转金币，
/// 向随机方向飞散并淡出。
///
/// 不拦截点击（IgnorePointer），保证下层交互不受影响。
class CoinBurstLayer extends StatefulWidget {
  final AppState state;
  const CoinBurstLayer({super.key, required this.state});

  @override
  State<CoinBurstLayer> createState() => _CoinBurstLayerState();
}

class _CoinBurstLayerState extends State<CoinBurstLayer> {
  final List<_Coin> _coins = [];
  StreamSubscription<void>? _sub;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _sub = widget.state.tapEvents.listen((_) => _spawn());
  }

  void _spawn() {
    const count = 5;
    for (var i = 0; i < count; i++) {
      late final _Coin coin;
      coin = _Coin(
        random: _random,
        onDone: () {
          if (mounted) setState(() => _coins.remove(coin));
        },
      );
      setState(() => _coins.add(coin));
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: Stack(children: _coins));
  }
}

/// 单枚旋转飞散的金币。
class _Coin extends StatefulWidget {
  final Random random;
  final VoidCallback onDone;
  const _Coin({required this.random, required this.onDone});

  @override
  State<_Coin> createState() => _CoinState();
}

class _CoinState extends State<_Coin> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<Offset> _pos; // 相对父容器尺寸的分数位移
  late final Animation<double> _rot;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    final r = widget.random;
    final angle = r.nextDouble() * 2 * pi;
    final dist = 0.28 + r.nextDouble() * 0.22; // 飞散距离（父尺寸比例）
    final dx = cos(angle) * dist;
    final dy = sin(angle) * dist - 0.08; // 略向上偏，像被抛起

    _c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800 + r.nextInt(300)),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      });

    _pos = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(dx, dy),
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));

    _rot = Tween<double>(
      begin: 0,
      end: (1 + r.nextInt(2)) * 2 * pi, // 旋转 1~3 圈
    ).animate(_c);

    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _c, curve: const Interval(0.55, 1.0)),
    );

    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FractionalTranslation(
      translation: _pos.value,
      child: Transform.rotate(
        angle: _rot.value,
        child: Opacity(
          opacity: _opacity.value,
          child: Center(
            child: Image.asset(
              'assets/images/gold_ingot.png',
              width: 26,
              height: 26,
            ),
          ),
        ),
      ),
    );
  }
}
