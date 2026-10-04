import 'package:edith_glass/hud/face_box.dart';
import 'package:edith_glass/hud/glass_view.dart';
import 'package:edith_glass/hud/hud_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// 顔追従枠がHUDに正しく描画されるかを golden で確認する（座標マッピングの検証）。
void main() {
  testWidgets('face box overlay golden', (tester) async {
    // 2人：識別済み(名前あり=緑ラベル)と未識別(シアン枠)
    final faces = ValueNotifier<List<FaceBox>>(const [
      FaceBox(0.10, 0.22, 0.30, 0.40, 0.9, name: 'TANAKA'),
      FaceBox(0.58, 0.30, 0.28, 0.38, 0.8, marker: 'B'),
    ]);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 512,
              height: 512,
              child: GlassView(
                state: const HudState(status: 'TARGET LOCKED', name: 'TANAKA', locked: true),
                previewAspect: 1,
                mirror: false,
                faces: faces,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await expectLater(find.byType(GlassView), matchesGoldenFile('goldens/face_box.png'));
  });
}
