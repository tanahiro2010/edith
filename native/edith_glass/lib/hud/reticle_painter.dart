import 'package:flutter/material.dart';

import 'hud_geometry.dart';
import 'hud_state.dart';

/// ドットサイト風のミニマルHUDを描く CustomPainter。
/// 中央に「細いリング＋ドット」だけを出し、上部にステータス、下部に名前タグを添える。
/// 論理座標は [HudGeometry]（256×256, Halo と同じ）で、実際の描画サイズへスケールする。
class ReticlePainter extends CustomPainter {
  ReticlePainter(this.state);

  final HudState state;

  static const Color cyan = Color(0xFF00E5FF);
  static const Color lockGreen = Color(0xFF7CFF6B);
  static const Color textColor = Color(0xFFEAF6FF);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / HudGeometry.size;
    canvas.save();
    canvas.translate((size.width - HudGeometry.size * s) / 2,
        (size.height - HudGeometry.size * s) / 2);
    canvas.scale(s, s);

    final accent = state.locked ? lockGreen : cyan;
    final c = const Offset(HudGeometry.cx, HudGeometry.cy);

    // 中心リング（細く小さく）
    canvas.drawCircle(
      c,
      HudGeometry.dotRing,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = accent,
    );
    // 中心ドット
    canvas.drawCircle(c, HudGeometry.dotCore, Paint()..color = accent);

    // 上部ステータス
    _text(canvas, state.status, const Offset(HudGeometry.cx, HudGeometry.statusY), accent, 11,
        bold: true, letterSpacing: 2);

    // 名前タグ（Level 1）＋補足（Level 2）
    if (state.name != null) {
      _text(canvas, state.name!, const Offset(HudGeometry.cx, HudGeometry.nameY), textColor, 18,
          bold: true);
      if (state.subInfo != null) {
        _text(canvas, state.subInfo!, const Offset(HudGeometry.cx, HudGeometry.subY), accent, 11);
      }
    }

    canvas.restore();
  }

  void _text(Canvas canvas, String text, Offset center, Color color, double size,
      {bool bold = false, double letterSpacing = 0}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          letterSpacing: letterSpacing,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 220);
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant ReticlePainter old) => old.state != state;
}
