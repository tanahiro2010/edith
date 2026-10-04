import 'package:flutter/material.dart';

import 'face_box.dart';

/// 検出した各顔にコーナーブラケット枠＋名前ラベルを描く（多人数対応）。
/// 座標は入力画像に対する正規化値で、プレビュー（BoxFit.cover 相当）と同じ [aspect] の
/// カバー変換で正方形ウィジェットへ写す。[mirror] は前面カメラの左右反転に合わせる。
class FaceBoxPainter extends CustomPainter {
  FaceBoxPainter({
    required this.faces,
    required this.aspect,
    required this.mirror,
  });

  final List<FaceBox> faces;
  final double aspect; // 画像の 幅/高
  final bool mirror;

  static const Color cyan = Color(0xFF00E5FF); // 未識別
  static const Color green = Color(0xFF7CFF6B); // 識別済み

  @override
  void paint(Canvas canvas, Size size) {
    if (faces.isEmpty) return;
    final side = size.shortestSide;

    double dispW, dispH;
    if (aspect >= 1) {
      dispH = side;
      dispW = side * aspect;
    } else {
      dispW = side;
      dispH = side / aspect;
    }
    final offX = (side - dispW) / 2;
    final offY = (side - dispH) / 2;

    for (final f in faces) {
      final named = f.name != null && f.name!.isNotEmpty;
      final label = named ? f.name! : (f.marker ?? ''); // 未識別は識別子(A,B..)
      final color = named ? green : cyan;

      double px = offX + f.x * dispW;
      final py = offY + f.y * dispH;
      final pw = f.w * dispW;
      final ph = f.h * dispH;
      if (mirror) px = side - (px + pw);
      final rect = Rect.fromLTWH(px, py, pw, ph);

      canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = color.withValues(alpha: 0.25),
      );
      _corners(
        canvas,
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
      if (label.isNotEmpty) _label(canvas, rect, label, color, side);
    }
  }

  void _corners(Canvas canvas, Rect r, Paint p) {
    final len = (r.shortestSide * 0.22).clamp(8.0, 30.0);
    canvas.drawLine(r.topLeft, r.topLeft + Offset(len, 0), p);
    canvas.drawLine(r.topLeft, r.topLeft + Offset(0, len), p);
    canvas.drawLine(r.topRight, r.topRight + Offset(-len, 0), p);
    canvas.drawLine(r.topRight, r.topRight + Offset(0, len), p);
    canvas.drawLine(r.bottomLeft, r.bottomLeft + Offset(len, 0), p);
    canvas.drawLine(r.bottomLeft, r.bottomLeft + Offset(0, -len), p);
    canvas.drawLine(r.bottomRight, r.bottomRight + Offset(-len, 0), p);
    canvas.drawLine(r.bottomRight, r.bottomRight + Offset(0, -len), p);
  }

  void _label(Canvas canvas, Rect r, String name, Color color, double side) {
    final tp = TextPainter(
      text: TextSpan(
        text: name,
        style: const TextStyle(color: Color(0xFF06080A), fontSize: 13, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: side * 0.6);

    const padH = 6.0;
    const padV = 3.0;
    final bw = tp.width + padH * 2;
    final bh = tp.height + padV * 2;
    // 枠の上に載せる（画面外なら下へ）
    double lx = r.left + (r.width - bw) / 2;
    double ly = r.top - bh - 4;
    if (ly < 0) ly = r.bottom + 4;
    lx = lx.clamp(0.0, side - bw);

    final bg = RRect.fromRectAndRadius(Rect.fromLTWH(lx, ly, bw, bh), const Radius.circular(4));
    canvas.drawRRect(bg, Paint()..color = color);
    tp.paint(canvas, Offset(lx + padH, ly + padV));
  }

  @override
  bool shouldRepaint(covariant FaceBoxPainter old) =>
      old.faces != faces || old.aspect != aspect || old.mirror != mirror;
}
