import 'dart:async';
import 'package:flutter/material.dart';
import 'app_state.dart';

/// 元宝掉落动画层。订阅 [AppState.ingotDrops]，每组香燃尽时让金元宝从顶部飘落。
class IngotDropLayer extends StatefulWidget {
  final AppState state;
  const IngotDropLayer({super.key, required this.state});

  @override
  State<IngotDropLayer> createState() => _IngotDropLayerState();
}

class _IngotDropLayerState extends State<IngotDropLayer> {
  final List<_FallingIngot> _ingots = [];
  StreamSubscription<int>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.state.ingotDrops.listen((count) {
      for (var i = 0; i < count; i++) {
        _spawn();
      }
    });
  }

  void _spawn() {
    late final _FallingIngot ingot;
    ingot = _FallingIngot(
      onDone: () {
        if (mounted) setState(() => _ingots.remove(ingot));
      },
    );
    setState(() => _ingots.add(ingot));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: _ingots);
  }
}

class _FallingIngot extends StatefulWidget {
  final VoidCallback onDone;
  const _FallingIngot({required this.onDone});

  @override
  State<_FallingIngot> createState() => _FallingIngotState();
}

class _FallingIngotState extends State<_FallingIngot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<Offset> _pos;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      });
    _pos = Tween<Offset>(
      begin: const Offset(0, -0.15),
      end: const Offset(0, 1.25),
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeIn));
    _opacity = Tween<double>(begin: 1.0, end: 0.2).animate(_c);
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 从神台中上方开始出现，落向底部外侧
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      bottom: 0,
      child: SlideTransition(
        position: _pos,
        child: FadeTransition(
          opacity: _opacity,
          child: Center(
            child: Image.asset(
              'assets/images/gold_ingot.png',
              width: 44,
              height: 44,
            ),
          ),
        ),
      ),
    );
  }
}
