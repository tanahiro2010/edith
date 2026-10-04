import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'face_box.dart';
import 'face_box_painter.dart';
import 'hud_geometry.dart';
import 'hud_state.dart';
import 'reticle_painter.dart';

/// 「グラス越しに見える映像」= 円形256ディスプレイ + カメラ映像 + 追従枠 + ドットサイト。
/// 実機到着前は、この Flutter 描画がそのままプレビュー/シミュレータビューになる。
class GlassView extends StatelessWidget {
  const GlassView({
    super.key,
    required this.state,
    this.background,
    this.liveBackground,
    this.previewAspect = 1,
    this.mirror = false,
    this.faces,
  });

  final HudState state;

  /// 静止フレーム背景（撮影した1枚など）。null なら黒。
  final ImageProvider? background;

  /// ライブ映像背景（カメラプレビュー等）。指定時は background より優先。
  final Widget? liveBackground;

  /// ライブ映像のアスペクト比（幅/高）。カバー配置と枠マッピングを一致させる。
  final double previewAspect;

  /// 前面カメラのプレビュー左右反転に合わせる。
  final bool mirror;

  /// 追従する顔枠（補間済み）。変化を購読して枠だけ再描画する。
  final ValueListenable<List<FaceBox>>? faces;

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
              if (liveBackground != null)
                Positioned.fill(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: previewAspect * 1000,
                      height: 1000,
                      child: liveBackground!,
                    ),
                  ),
                )
              else if (background != null)
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
              // 顔追従枠（枠だけ再描画）
              if (faces != null)
                Positioned.fill(
                  child: ValueListenableBuilder<List<FaceBox>>(
                    valueListenable: faces!,
                    builder: (_, list, __) => CustomPaint(
                      painter: FaceBoxPainter(
                        faces: list,
                        aspect: previewAspect,
                        mirror: mirror,
                      ),
                    ),
                  ),
                ),
              // 中央ドットサイト＋名前タグ
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
