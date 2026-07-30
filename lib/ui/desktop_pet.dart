import 'package:flutter/material.dart';
import 'app_state.dart';
import 'ingot_drop.dart';
import 'smoke_particle.dart';

/// 桌面宠物：悬浮窗内渲染的财神神台。
///
/// - 空闲态显示「空香炉」神台图；燃烧态显示「带香+红点余烬+静态烟」的神台图，并叠加 CustomPainter 粒子烟雾。
/// - 点击神台触发上香（未燃尽不可叠加）。
/// - 香燃尽时由 [IngotDropLayer] 播放元宝掉落动画。
class DesktopPet extends StatelessWidget {
  final AppState state;
  const DesktopPet({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (ctx, _) {
        final burning = state.activeGroup != null;
        return GestureDetector(
          onTap: () {
            if (state.canLight) state.light();
          },
          child: AspectRatio(
            aspectRatio: 1,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.asset(
                  burning
                      ? 'assets/images/caishen_shrine.png'
                      : 'assets/images/caishen_shrine_idle.png',
                  fit: BoxFit.contain,
                ),
                if (burning) SmokeLayer(burning: burning),
                IngotDropLayer(state: state),
              ],
            ),
          ),
        );
      },
    );
  }
}
