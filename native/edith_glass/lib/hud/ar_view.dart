import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'face_box.dart';
import 'face_box_painter.dart';
import 'hud_geometry.dart';
import 'hud_state.dart';
import 'reticle_painter.dart';

/// スマホ（iOS）ドッグフーディング用のフルスクリーンAR表示。
/// 円形 [GlassView] と同じ構成要素（カメラ映像＋追従枠＋中央レティクル）を、
/// 画面全体に広げて重ねる。実機 Halo 用の [GlassView] はそのまま温存している。
class ArView extends StatelessWidget {
  const ArView({
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
    // カメラ映像と顔枠を「同一の画像座標 SizedBox」に入れ、親の FittedBox(cover) で
    // まったく同じ変換を掛ける → どの画面比でも枠が映像とズレない。
    final imageLayer = FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: previewAspect * 1000,
        height: 1000,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (liveBackground != null)
              liveBackground!
            else if (background != null)
              Image(image: background!, fit: BoxFit.cover),
            if (faces != null)
              ValueListenableBuilder<List<FaceBox>>(
                valueListenable: faces!,
                builder: (_, list, __) => CustomPaint(
                  painter: FaceBoxPainter(
                    faces: list,
                    aspect: previewAspect,
                    mirror: mirror,
                    coverIntoSquare: false,
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return ColoredBox(
      color: const Color(0xFF06080A),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: imageLayer),
          // 周辺減光（グラスらしい締まり）
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 0.9,
                  colors: [Colors.transparent, Color(0x99000000)],
                  stops: [0.65, 1.0],
                ),
              ),
            ),
          ),
          // 中央ドットサイト＋名前タグ（画面中央・スクリーン座標）
          Positioned.fill(
            child: CustomPaint(
              painter: ReticlePainter(state),
              size: const Size.square(HudGeometry.size),
            ),
          ),
        ],
      ),
    );
  }
}
