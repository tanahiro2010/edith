import 'dart:math' as math;

import 'hud_geometry.dart';
import 'hud_state.dart';

/// [ReticlePainter] と同じミニマルHUD（ドットサイト＋名前タグ）を、Halo 実機の
/// 描画API(`frame.display.*`)を呼ぶ **Lua 文字列**として生成する。
/// ホスト(Flutter)は brilliant_sdk の `device.sendString(luaCode)` でこれを送り、
/// グラスの 256×256 円形HUDに描く。
///
/// Halo Lua 描画API（docs.brilliant.xyz/halo）:
///   frame.display.clear([color]) / circle(cx,cy,r,color,filled)
///   text(t,x,y,color) / set_font(id,size,scale)。色は 0xRRGGBB。
String haloReticleLua(HudState state) {
  final cx = HudGeometry.cx.toInt();
  final cy = HudGeometry.cy.toInt();
  const cyan = '0x00E5FF';
  const white = '0xEAF6FF';
  const lock = '0x7CFF6B';
  final acc = state.locked ? lock : cyan;

  final b = <String>[];
  b.add('frame.display.clear(0x000000)');

  // 中心リング＋ドット（ドットサイト）
  b.add('frame.display.circle($cx,$cy,${HudGeometry.dotRing.toInt()},$acc,false)');
  b.add('frame.display.circle($cx,$cy,${HudGeometry.dotCore.round()},$acc,true)');

  // 上部ステータス（テキスト幅APIが無いため文字数から中央寄せを概算）
  b.add('frame.display.set_font(1,12,1)');
  b.add('frame.display.text("${_esc(state.status)}",${_centerX(state.status, 6)},${HudGeometry.statusY.toInt()},$acc)');

  // 名前タグ（Level 1）＋補足（Level 2）
  if (state.name != null) {
    b.add('frame.display.set_font(1,18,1)');
    b.add('frame.display.text("${_esc(state.name!)}",${_centerX(state.name!, 9)},${(HudGeometry.nameY - 8).toInt()},$white)');
    if (state.subInfo != null) {
      b.add('frame.display.set_font(1,12,1)');
      b.add('frame.display.text("${_esc(state.subInfo!)}",${_centerX(state.subInfo!, 6)},${(HudGeometry.subY - 4).toInt()},$acc)');
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
