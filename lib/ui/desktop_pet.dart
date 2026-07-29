import 'package:flutter/material.dart';
import 'app_state.dart';
import 'ingot_drop.dart';

/// 桌面宠物：悬浮窗内渲染的财神神台。
///
/// - 空闲态显示「空香炉」神台图；燃烧态显示「带香+红点余烬+烟」的神台图。
/// - 点击神台触发上香（未燃尽不可叠加）。
/// - 燃烧时底部显示进度条，右上角显示元宝计数。
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
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(
                burning
                    ? 'assets/images/caishen_shrine.png'
                    : 'assets/images/caishen_shrine_idle.png',
                fit: BoxFit.contain,
              ),
              if (burning)
                Positioned(
                  bottom: 6,
                  left: 18,
                  right: 18,
                  child: LinearProgressIndicator(
                    value: state.progress,
                    minHeight: 4,
                    backgroundColor: Colors.white24,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.amberAccent),
                  ),
                ),
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('元宝 ${state.totalCoins}',
                      style: const TextStyle(color: Colors.amberAccent)),
                ),
              ),
              IngotDropLayer(state: state),
            ],
          ),
        );
      },
    );
  }
}
