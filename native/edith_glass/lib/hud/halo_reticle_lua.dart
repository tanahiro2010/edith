import 'dart:math' as math;

import 'hud_geometry.dart';
import 'hud_state.dart';

/// [ReticlePainter] と同じ幾何を、Halo 実機の描画API(`frame.display.*`)を呼ぶ
/// **Lua 文字列**として生成する。ホスト(Flutter)は brilliant_sdk の
/// `device.sendString(luaCode)` でこれを送り、グラスの 256×256 円形HUDに描く。
///
/// Halo Lua 描画API（docs.brilliant.xyz/halo）:
///   frame.display.clear([color]) / line(x0,y0,x1,y1,color)
///   circle(cx,cy,r,color,filled) / text(t,x,y,color) / set_font(id,size,scale)
/// 色は 0xRRGGBB。
String haloReticleLua(HudState state) {
  final cx = HudGeometry.cx.toInt();
  final cy = HudGeometry.cy.toInt();
  const cyan = '0x00E5FF';
  const dim = '0x0A7F92';
  const white = '0xEAF6FF';
  const lock = '0x7CFF6B';
  final acc = state.locked ? lock : cyan;

  final b = <String>[];
  b.add('frame.display.clear(0x000000)');

  // 目盛りリング + 12 ティック
  b.add('frame.display.circle($cx,$cy,${HudGeometry.ringRadius.toInt()},$dim,false)');
  b.add('for i=0,${HudGeometry.ringTicks - 1} do '
      'local a=i*(2*math.pi/${HudGeometry.ringTicks}) '
      'local c=math.cos(a) local s=math.sin(a) '
      'frame.display.line($cx+c*${HudGeometry.ringRadius.toInt()},$cy+s*${HudGeometry.ringRadius.toInt()},'
      '$cx+c*${HudGeometry.ringTickInner.toInt()},$cy+s*${HudGeometry.ringTickInner.toInt()},$dim) end');

  // コーナーブラケット
  const bk = HudGeometry.bracket;
  const arm = HudGeometry.bracketArm;
  for (final sx in const [-1, 1]) {
    for (final sy in const [-1, 1]) {
      final px = (HudGeometry.cx + sx * bk).toInt();
      final py = (HudGeometry.cy + sy * bk).toInt();
      b.add('frame.display.line($px,$py,${(px - sx * arm)},$py,$acc)');
      b.add('frame.display.line($px,$py,$px,${(py - sy * arm)},$acc)');
    }
  }

  // 中央クロスヘア
  final gap = HudGeometry.crossGap.toInt();
  final tick = HudGeometry.crossTick.toInt();
  b.add('frame.display.line($cx,${cy - gap},$cx,${cy - gap - tick},$acc)');
  b.add('frame.display.line($cx,${cy + gap},$cx,${cy + gap + tick},$acc)');
  b.add('frame.display.line(${cx - gap},$cy,${cx - gap - tick},$cy,$acc)');
  b.add('frame.display.line(${cx + gap},$cy,${cx + gap + tick},$cy,$acc)');

  // 中央の照準リング + ドット
  b.add('frame.display.circle($cx,$cy,${HudGeometry.aimRing.toInt()},$acc,false)');
  b.add('frame.display.circle($cx,$cy,2,$white,true)');

  // 上部ステータス（テキスト幅APIが無いため文字数から中央寄せを概算）
  b.add('frame.display.set_font(1,12,1)');
  b.add('frame.display.text("${_esc(state.status)}",${_centerX(state.status, 6)},22,$acc)');

  // 名前タグ（Level 1）＋補足（Level 2）
  if (state.name != null) {
    b.add('frame.display.set_font(1,18,1)');
    b.add('frame.display.text("${_esc(state.name!)}",${_centerX(state.name!, 9)},188,$white)');
    if (state.subInfo != null) {
      b.add('frame.display.set_font(1,12,1)');
      b.add('frame.display.text("${_esc(state.subInfo!)}",${_centerX(state.subInfo!, 6)},212,$acc)');
    }
  }

  return b.join('\n');
}

/// 概算の文字幅から中央寄せ x を求める（Halo にテキスト幅計測APIが無いため）。
int _centerX(String text, int charW) {
  final w = text.length * charW;
  return math.max(2, (HudGeometry.cx - w / 2).round());
}

String _esc(String s) => s.replaceAll('\\', r'\\').replaceAll('"', r'\"');
