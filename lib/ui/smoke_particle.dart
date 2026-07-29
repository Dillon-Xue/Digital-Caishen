import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// 粒子烟雾层。
///
/// 叠加在燃烧态神台图上方，从三炷香顶持续冒出袅袅细烟。
/// 不拦截点击，保证下层 [GestureDetector] 仍能触发上香。
class SmokeLayer extends StatefulWidget {
  /// 是否正在燃烧；为 false 时停止发射新粒子，已有粒子自然消散。
  final bool burning;

  const SmokeLayer({super.key, required this.burning});

  @override
  State<SmokeLayer> createState() => _SmokeLayerState();
}

class _SmokeLayerState extends State<SmokeLayer>
    with SingleTickerProviderStateMixin {
  static const double _daySeconds = 24 * 60 * 60;

  late final SmokeParticlePainter _painter;
  late final AnimationController _controller;
  double _previousElapsed = 0;

  @override
  void initState() {
    super.initState();
    _painter = SmokeParticlePainter();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    )..addListener(_onFrame);
    if (widget.burning) {
      _painter.resumeEmitting();
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant SmokeLayer old) {
    super.didUpdateWidget(old);
    if (widget.burning) {
      _painter.resumeEmitting();
      if (!_controller.isAnimating) _controller.forward();
    } else {
      _painter.stopEmitting();
    }
  }

  void _onFrame() {
    final elapsed = _controller.value * _daySeconds;
    final dt = elapsed - _previousElapsed;
    _previousElapsed = elapsed;
    // 防止切后台 dt 过大导致粒子爆炸
    if (dt > 0 && dt < 0.2) {
      _painter.tick(dt);
    }
    if (!_painter.emitting && _painter.isIdle && _controller.isAnimating) {
      _controller.stop();
      _previousElapsed = 0;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onFrame);
    _controller.dispose();
    _painter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _painter,
        size: Size.infinite,
      ),
    );
  }
}

/// 单个烟雾粒子。
class _SmokeParticle {
  double x; // 0..1，相对画布宽度
  double y; // 0..1，相对画布高度
  final double vx;
  final double vy;
  final double maxAge;
  double age;
  double size;
  double opacity;
  final double driftPhase;

  _SmokeParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.maxAge,
    required this.driftPhase,
  })  : age = 0,
        size = 0,
        opacity = 0;
}

/// CustomPainter：负责发射、更新与绘制烟雾粒子。
class SmokeParticlePainter extends CustomPainter with ChangeNotifier {
  final List<_SmokeParticle> _particles = [];
  final Random _random = Random();

  /// 三炷香顶的大致归一化坐标（基于 1024×1024 神台图目测）。
  static const List<Offset> _emitters = [
    Offset(0.45, 0.42),
    Offset(0.50, 0.40),
    Offset(0.55, 0.42),
  ];

  bool _emitting = true;

  bool get emitting => _emitting;

  bool get isIdle => _particles.isEmpty;

  void stopEmitting() => _emitting = false;

  void resumeEmitting() => _emitting = true;

  void tick(double dt) {
    _emit(dt);
    _update(dt);
    notifyListeners();
  }

  void _emit(double dt) {
    if (!_emitting || _particles.length >= 60) return;
    // 每帧按概率发射，平均约每秒 18 颗粒子（三炷香分摊）
    const emitChance = 0.35;
    if (_random.nextDouble() > emitChance) return;

    final emitter = _emitters[_random.nextInt(_emitters.length)];
    final particle = _SmokeParticle(
      x: emitter.dx + (_random.nextDouble() - 0.5) * 0.04,
      y: emitter.dy + (_random.nextDouble() - 0.5) * 0.02,
      vx: (_random.nextDouble() - 0.5) * 0.04,
      vy: -0.10 - _random.nextDouble() * 0.04,
      maxAge: 1.8 + _random.nextDouble() * 1.2,
      driftPhase: _random.nextDouble() * 2 * pi,
    );
    _particles.add(particle);
  }

  void _update(double dt) {
    for (var i = _particles.length - 1; i >= 0; i--) {
      final p = _particles[i];
      p.age += dt;
      if (p.age >= p.maxAge) {
        _particles.removeAt(i);
        continue;
      }

      final t = p.age / p.maxAge;
      final life = 1.0 - t;

      // 上升 + 正弦漂移
      p.x += (p.vx + sin(p.age * 1.8 + p.driftPhase) * 0.06) * dt;
      p.y += p.vy * dt;

      // 粒子由小变大、变淡
      p.size = lerpDouble(4, 14, t) ?? 8;
      p.opacity = life * 0.30;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (_particles.isEmpty) return;

    for (final p in _particles) {
      final center = Offset(p.x * size.width, p.y * size.height);
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: p.opacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawCircle(center, p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
