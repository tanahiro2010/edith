import 'package:flutter/foundation.dart';

import '../hud/halo_reticle_lua.dart';
import '../hud/hud_state.dart';

/// HUD 描画先の抽象。ホストのロジックは常にこの [render] を呼ぶだけで、
/// 描画先が「Flutterプレビュー」か「実機Halo(BLE経由でLua送信)」かを意識しない。
/// PRD の設計思想（Agent/クライアントとデバイスを分離）と同じ考え方をクライアント内にも適用。
abstract class GlassTransport {
  /// 現在の HUD 状態（プレビュー描画が購読する）。
  ValueListenable<HudState> get hud;

  /// HUD を指定状態に更新する。
  Future<void> render(HudState state);

  void dispose();
}

/// 実機なしの開発用。状態を [ValueNotifier] に反映し、GlassView が Flutter 描画する。
class PreviewGlassTransport implements GlassTransport {
  PreviewGlassTransport([HudState initial = HudState.idle])
      : _hud = ValueNotifier<HudState>(initial);

  final ValueNotifier<HudState> _hud;

  @override
  ValueListenable<HudState> get hud => _hud;

  @override
  Future<void> render(HudState state) async => _hud.value = state;

  @override
  void dispose() => _hud.dispose();
}

/// 実機 Halo 用。[render] のたびに同じレティクル幾何を Lua 化して
/// `device.sendString(lua)` 相当の [sendLua] に流す。
///
/// アプリ起動時に brilliant_sdk を配線する例:
/// ```dart
/// final device = await BrilliantBluetooth.connect(scanned); // package:brilliant_ble
/// final transport = HaloGlassTransport(
///   sendLua: (lua) async {
///     await device.sendBreakSignal();
///     await device.sendString(lua, awaitResponse: false);
///   },
/// );
/// ```
/// brilliant_sdk に直接依存しないことで、SDK 未導入でもこのアプリはビルド・テストできる。
class HaloGlassTransport implements GlassTransport {
  HaloGlassTransport({required this.sendLua, HudState initial = HudState.idle})
      : _hud = ValueNotifier<HudState>(initial);

  /// 実機の `device.sendString` に相当。Lua 文字列を受け取り HUD へ送る。
  final Future<void> Function(String lua) sendLua;

  final ValueNotifier<HudState> _hud;

  @override
  ValueListenable<HudState> get hud => _hud;

  @override
  Future<void> render(HudState state) async {
    _hud.value = state;
    await sendLua(haloReticleLua(state));
  }

  @override
  void dispose() => _hud.dispose();
}
