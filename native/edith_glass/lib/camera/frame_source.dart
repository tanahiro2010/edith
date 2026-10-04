import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// 「グラスのカメラフレーム」を供給する抽象。GlassTransport と同じ発想で、
/// 供給元（実カメラ / アセット / 将来の Halo RxPhoto）を差し替え可能にする。
abstract class FrameSource {
  Future<void> init();

  /// ライブ映像を持つか（true ならプレビュー表示可能）。
  bool get isLive;

  /// プレビュー映像のアスペクト比（幅/高）。枠のマッピングをプレビューに合わせるのに使う。
  double get aspectRatio;

  /// 前面（自撮り）カメラか。プレビューが左右反転しがちなのでミラー既定値の判断に使う。
  bool get isFront;

  /// ライブプレビュー用ウィジェット（無ければ null）。
  Widget? livePreview();

  /// 現在のフレームを JPEG バイト列として取得（識別・登録に送る）。
  Future<Uint8List> capture();

  Future<void> dispose();
}

/// 実カメラ（camera パッケージ）。iOS / Web(getUserMedia) / Android で動作。
/// macOS デスクトップは未対応のため init() が例外を投げ、呼び出し側が fallback する。
class CameraFrameSource implements FrameSource {
  CameraController? _controller;
  bool _front = false;

  @override
  bool get isLive => _controller?.value.isInitialized ?? false;

  @override
  double get aspectRatio {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return 1;
    final a = c.value.aspectRatio;
    return (a.isFinite && a > 0) ? a : 1;
  }

  @override
  bool get isFront => _front;

  @override
  Future<void> init() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw StateError('利用可能なカメラがありません');
    }
    // 対面用途なので前面カメラがあれば優先、無ければ先頭。
    final cam = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    _front = cam.lensDirection == CameraLensDirection.front;
    final controller = CameraController(cam, ResolutionPreset.medium, enableAudio: false);
    await controller.initialize();
    _controller = controller;
  }

  @override
  Widget? livePreview() =>
      _controller != null && _controller!.value.isInitialized ? CameraPreview(_controller!) : null;

  @override
  Future<Uint8List> capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      throw StateError('カメラが初期化されていません');
    }
    final XFile shot = await controller.takePicture();
    return shot.readAsBytes();
  }

  @override
  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }
}

/// 実カメラが無い環境（macOSデスクトップ・ヘッドレス等）用のフォールバック。
/// 同梱画像を「撮影したフレーム」として返す。
class AssetFrameSource implements FrameSource {
  AssetFrameSource(this.asset);
  final String asset;

  @override
  bool get isLive => false;

  @override
  double get aspectRatio => 1;

  @override
  bool get isFront => false;

  @override
  Future<void> init() async {}

  @override
  Widget? livePreview() => null;

  @override
  Future<Uint8List> capture() async =>
      (await rootBundle.load(asset)).buffer.asUint8List();

  @override
  Future<void> dispose() async {}
}

/// 実カメラを試し、使えなければアセットにフォールバックする。
Future<FrameSource> createFrameSource({required String fallbackAsset}) async {
  final cam = CameraFrameSource();
  try {
    await cam.init();
    return cam;
  } catch (_) {
    await cam.dispose();
    final fallback = AssetFrameSource(fallbackAsset);
    await fallback.init();
    return fallback;
  }
}
