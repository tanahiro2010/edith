import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'hud_geometry.dart';
import 'hud_state.dart';

/// SF風レティクル（HUD照準）を描く CustomPainter。
/// 論理座標は [HudGeometry]（256×256, Halo と同じ）で、実際の描画サイズへスケールする。
/// これは「グラス越しに見える映像」のプレビュー兼、実機描画(Halo Lua)と一致させる基準。
class ReticlePainter extends CustomPainter {
  ReticlePainter(this.state);

  final HudState state;

  static const Color cyan = Color(0xFF00E5FF);
  static const Color dim = Color(0xFF0A7F92);
  static const Color lockGreen = Color(0xFF7CFF6B);
  static const Color edge = Color(0xFF171E22);
  static const Color textColor = Color(0xFFEAF6FF);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / HudGeometry.size;
    canvas.save();
    // 正方形基準にセンタリングしてスケール。
    canvas.translate((size.width - HudGeometry.size * s) / 2,
        (size.height - HudGeometry.size * s) / 2);
    canvas.scale(s, s);

    final accent = state.locked ? lockGreen : cyan;
    final g = HudGeometry.size; // 256
    final c = Offset(HudGeometry.cx, HudGeometry.cy);

    final thin = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = edge;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = dim;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = accent;

    // 円形ディスプレイ外にはみ出さないようクリップ（実機は円形）。
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: g / 2)));

    // 1) ディスプレイ縁
    canvas.drawCircle(c, HudGeometry.edgeRadius, thin);

    // 2) 目盛りリング + 12 ティック
    canvas.drawCircle(c, HudGeometry.ringRadius, ring);
    for (var i = 0; i < HudGeometry.ringTicks; i++) {
      final a = i * (2 * math.pi / HudGeometry.ringTicks);
      final o = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + o * HudGeometry.ringRadius, c + o * HudGeometry.ringTickInner, ring);
    }

    // 3) コーナーブラケット
    const b = HudGeometry.bracket;
    const arm = HudGeometry.bracketArm;
    for (final sx in const [-1.0, 1.0]) {
      for (final sy in const [-1.0, 1.0]) {
        final p = c + Offset(sx * b, sy * b);
        canvas.drawLine(p, p + Offset(-sx * arm, 0), stroke);
        canvas.drawLine(p, p + Offset(0, -sy * arm), stroke);
      }
    }

    // 4) 中央クロスヘア（中心にギャップ）
    const gap = HudGeometry.crossGap;
    const tick = HudGeometry.crossTick;
    canvas.drawLine(c + const Offset(0, -gap), c + const Offset(0, -gap - tick), stroke);
    canvas.drawLine(c + const Offset(0, gap), c + const Offset(0, gap + tick), stroke);
    canvas.drawLine(c + const Offset(-gap, 0), c + const Offset(-gap - tick, 0), stroke);
    canvas.drawLine(c + const Offset(gap, 0), c + const Offset(gap + tick, 0), stroke);

    // 5) 中央の照準リング + ドット
    canvas.drawCircle(c, HudGeometry.aimRing, stroke..strokeWidth = 1);
    canvas.drawCircle(c, HudGeometry.aimDot, Paint()..color = textColor);

    // 6) ロック時：回転する外周アーク演出（静的に4本のアーク）
    if (state.locked) {
      final lock = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = accent;
      final rect = Rect.fromCircle(center: c, radius: 60);
      for (var i = 0; i < 4; i++) {
        final start = i * (math.pi / 2) + math.pi / 8;
        canvas.drawArc(rect, start, math.pi / 4, false, lock);
      }
    }

    // 7) 上部ステータス
    _text(canvas, state.status, Offset(c.dx, 30), accent, 11, bold: true, letterSpacing: 2);

    // 8) 名前タグ（Level 1）＋補足（Level 2）
    if (state.name != null) {
      _text(canvas, state.name!, Offset(c.dx, 196), textColor, 18, bold: true);
      if (state.subInfo != null) {
        _text(canvas, state.subInfo!, Offset(c.dx, 216), accent, 11);
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
