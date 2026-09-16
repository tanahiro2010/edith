# E.D.I.T.H Glass Client (Flutter / Halo)

brilliant.xyz **Halo** スマートグラス用のホストクライアント（Flutter）。
グラスの HUD に **SF風レティクル（照準）** を中心表示し、カメラ映像を Face API で識別して
名前タグを出し、音声/テキスト指示を Voice Agent に流す。

> **実機なしで開発・デバッグ可能**。Halo 到着前は Flutter 描画（`PreviewGlassTransport`）が
> そのままグラス映像のプレビューになり、到着後は `HaloGlassTransport` に差し替えるだけ
> （HUD 描画は同じ幾何を Halo Lua 化して BLE で送る）。

![reticle](test/goldens/reticle_scanning.png)

## 何が動くか

- **HUD レティクル**: 256×256 円形ディスプレイ（Halo と同解像度）に、外周目盛りリング・
  コーナーブラケット・中央クロスヘア・照準リングを描画。認識時は緑＋ロックアーク演出。
  - Flutter 描画: `lib/hud/reticle_painter.dart`
  - 実機 Halo 用の同一幾何 Lua: `lib/hud/halo_reticle_lua.dart`（`frame.display.*`）
- **識別**: 「カメラの顔を識別」→ Face API `/faces/identify` → HUD に名前タグ＋一致度。
- **指示**: テキストを Voice Agent `/v1/agent/input` へ。`capture_face` アクションが来たら
  カメラ撮影→ `/faces/register` 登録を実行し、結果を Agent に返す。
- **音声**: `VoiceAgentApi.sendAudio()` で `/v1/agent/audio`（サーバ側ローカルSTT）に対応。

> MVP では「グラスのカメラフレーム」を同梱画像 `assets/sample_face.jpg` で代替している。
> 実機では `RxPhoto`（JPEG）フレームに差し替える。

## アーキテクチャ（デバイス非依存）

```
UI / ロジック
   │  render(HudState)                identify() / sendText()
   ▼                                    ▼
GlassTransport (抽象)              VoiceAgentApi / FaceApi (http)
   ├─ PreviewGlassTransport → Flutter で GlassView に描画（実機なし）
   └─ HaloGlassTransport   → haloReticleLua(state) を device.sendString で BLE 送信（実機）
```

同じ `HudState` が Preview と実機の両方を駆動する。`GlassTransport` を差し替えるだけで
Mac/Web → スマホ → Halo へクライアントを移せる。

## 実行

```bash
flutter pub get

# ブラウザで（要 Chrome）。バックエンド(:8000/:8010)を起動しておくと識別・指示も動く
flutter run -d chrome
# または macOS デスクトップアプリ
flutter run -d macos
```

> Flutter web からバックエンドを叩く場合、Face API / Voice Agent 側の CORS 設定が必要な
> ことがある（ブラウザ制限）。デスクトップ/モバイルアプリでは不要。

## 開発ツール（実機なしでの検証）

- **解析**: `flutter analyze`
- **テスト**: `flutter test`（レティクルの golden 描画 + Halo Lua 生成の単体テスト）
  - レティクルの実描画を更新: `flutter test --update-goldens` → `test/goldens/*.png`
- **バックエンド結合スモーク**（3サービス起動が前提）: `dart run tool/smoke.dart`
- **実機シミュレータ**: brilliant 公式の `halo-ws-simulator` を使うと、`HaloGlassTransport` の
  `sendLua` を実機同様に WebSocket 経由で流して HUD 描画を確認できる（依存差し替えのみで実機へ）。

## Halo 実機への配線（到着後）

`pubspec.yaml` に `brilliant_ble` / `brilliant_msg`（または `brilliant_sdk`）を追加し、
`main.dart` の transport を差し替える:

```dart
final device = await BrilliantBluetooth.connect(scanned);
final transport = HaloGlassTransport(sendLua: (lua) async {
  await device.sendBreakSignal();
  await device.sendString(lua, awaitResponse: false);
});
// カメラは device の RxPhoto、マイクは RxAudio を購読して FaceApi/VoiceAgentApi へ。
```
