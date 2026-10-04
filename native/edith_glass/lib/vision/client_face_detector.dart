import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../hud/face_box.dart';
import 'client_face_detector_io.dart'
    if (dart.library.js_interop) 'client_face_detector_web.dart' as impl;

/// 選択可能なカメラ（内蔵・外部USB・フロント/バック）。
class CameraOption {
  const CameraOption({required this.deviceId, required this.label});
  final String deviceId;
  final String label;

  factory CameraOption.fromJson(Map<String, dynamic> j) => CameraOption(
        deviceId: (j['deviceId'] as String?) ?? '',
        label: (j['label'] as String?) ?? '',
      );
}

/// 端末内（クライアント）で顔を検出するリアルタイム検出器。往復通信なしで滑らか。
/// - Web: ブラウザの MediaPipe(FaceDetector) を利用
/// - モバイル/Haloホスト: ML Kit（今後、同じインターフェースで追加）
/// 使えない環境では [createClientFaceDetector] が null を返し、呼び出し側は
/// サーバ検出（/v1/vision/detect）にフォールバックする。
abstract class ClientFaceDetector {
  /// 検出とカメラを開始。成功したら true。
  Future<bool> start();

  /// プレビュー映像ウィジェット（HUD背景に敷く）。
  Widget preview();

  /// リアルタイムの顔枠（正規化座標）。
  ValueListenable<List<FaceBox>> get boxes;

  /// プレビュー映像のアスペクト比（幅/高）。
  double get aspect;

  /// プレビューが左右反転しているか（枠のマッピングを合わせる）。
  /// カメラ切替（フロント/バック）で変わりうる。
  bool get mirror;

  /// 利用可能なカメラ一覧（外部USBカメラ含む）。非対応なら空。
  Future<List<CameraOption>> listCameras();

  /// 指定カメラに切替。成功で true。[aspect] / [mirror] は切替後に更新される。
  Future<bool> switchCamera(String deviceId);

  /// 識別用に現在フレームを JPEG バイト列で取得。
  Future<Uint8List?> capture();

  void dispose();
}

/// 実行環境に応じた検出器を生成（非対応なら null）。
ClientFaceDetector? createClientFaceDetector() => impl.createClientFaceDetector();
