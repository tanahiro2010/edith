import 'package:edith_glass/hud/halo_reticle_lua.dart';
import 'package:edith_glass/hud/hud_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('haloReticleLua', () {
    test('画面クリアと基本プリミティブを含む', () {
      final lua = haloReticleLua(const HudState(status: 'SCANNING'));
      expect(lua, contains('frame.display.clear(0x000000)'));
      expect(lua, contains('frame.display.circle(128,128')); // 照準リング等
      expect(lua, contains('frame.display.line(')); // クロスヘア/ブラケット
      expect(lua, contains('SCANNING'));
      // 未認識時は名前タグを描かない
      expect(lua, isNot(contains('188,'))); // 名前の y=188 行が無い
    });

    test('認識時はアクセント色が lock 緑で名前タグを描く', () {
      final lua = haloReticleLua(
        const HudState(status: 'TARGET LOCKED', name: '田中太郎', subInfo: '営業部', locked: true),
      );
      expect(lua, contains('0x7CFF6B')); // lock 緑
      expect(lua, contains('田中太郎'));
      expect(lua, contains('営業部'));
    });

    test('ダブルクオートをエスケープする', () {
      final lua = haloReticleLua(const HudState(status: 'A"B'));
      expect(lua, contains(r'A\"B'));
    });
  });
}
