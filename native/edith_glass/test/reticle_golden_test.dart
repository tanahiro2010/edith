import 'package:edith_glass/hud/glass_view.dart';
import 'package:edith_glass/hud/hud_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// レティクルHUDを実際に Flutter で描画し PNG(golden) として書き出す。
// `flutter test --update-goldens` で test/goldens/*.png が生成される。
// （テキストは flutter_test の既定フォントのため golden 上は箱で出るが、
//   図形＝レティクル本体の描画を検証できる。実行時は実フォントで描画される。）
void main() {
  testWidgets('reticle golden — scanning / locked', (tester) async {
    Future<void> pump(HudState state) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: SizedBox(width: 512, height: 512, child: GlassView(state: state)),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await pump(const HudState(status: 'SCANNING'));
    await expectLater(
      find.byType(GlassView),
      matchesGoldenFile('goldens/reticle_scanning.png'),
    );

    await pump(const HudState(status: 'TARGET LOCKED', name: 'TANAKA', subInfo: 'SALES 99%', locked: true));
    await expectLater(
      find.byType(GlassView),
      matchesGoldenFile('goldens/reticle_locked.png'),
    );
  });
}
