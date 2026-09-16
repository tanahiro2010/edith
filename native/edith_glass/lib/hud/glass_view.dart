import 'package:flutter/material.dart';

import 'hud_geometry.dart';
import 'hud_state.dart';
import 'reticle_painter.dart';

/// 「グラス越しに見える映像」= 円形256ディスプレイ + （任意の）カメラ映像 + レティクル。
/// 実機到着前は、この Flutter 描画がそのままプレビュー/シミュレータビューになる。
class GlassView extends StatelessWidget {
  const GlassView({super.key, required this.state, this.background});

  final HudState state;

  /// カメラ映像の代わりに敷く背景（実機では RxPhoto のフレーム）。null なら黒。
  final ImageProvider? background;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: ClipOval(
        child: Container(
          color: const Color(0xFF06080A),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (background != null)
                Opacity(
                  opacity: 0.9,
                  child: Image(image: background!, fit: BoxFit.cover),
                ),
              // 周辺減光（グラスらしい暗さ）
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 0.75,
                    colors: [Colors.transparent, Color(0xCC000000)],
                    stops: [0.6, 1.0],
                  ),
                ),
              ),
              CustomPaint(
                painter: ReticlePainter(state),
                size: const Size.square(HudGeometry.size),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
