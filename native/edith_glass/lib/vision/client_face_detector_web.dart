import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import '../hud/face_box.dart';
import 'client_face_detector.dart';

// web/edith_mediapipe.js が公開するグローバル関数。
@JS('edithFaceStart')
external JSPromise<JSString> _start();
@JS('edithFaceBoxes')
external JSString _boxesJson();
@JS('edithFaceAspect')
external JSNumber _aspectJs();
@JS('edithFaceCapture')
external JSString _captureJs();
@JS('edithFaceVideoEl')
external web.HTMLVideoElement _videoEl();
@JS('edithFaceListCameras')
external JSPromise<JSString> _listCamerasJs();
@JS('edithFaceSwitchCamera')
external JSPromise<JSString> _switchCameraJs(JSString deviceId);
@JS('edithFaceMirror')
external JSBoolean _mirrorJs();

const _viewType = 'edith-mp-view';
bool _factoryRegistered = false;

ClientFaceDetector? createClientFaceDetector() => WebMediaPipeDetector();

/// ブラウザ内 MediaPipe による顔検出器。プレビューも枠も端末内で完結（往復なし）。
class WebMediaPipeDetector implements ClientFaceDetector {
  final ValueNotifier<List<FaceBox>> _boxes = ValueNotifier<List<FaceBox>>(const []);
  Timer? _poll;
  double _aspect = 1;
  bool _started = false;
  bool _mirror = true; // カメラ切替で変わる（フロント=反転 / バック=等倍）

  @override
  ValueListenable<List<FaceBox>> get boxes => _boxes;

  @override
  double get aspect => _aspect;

  @override
  bool get mirror => _mirror;

  @override
  Future<bool> start() async {
    final result = (await _start().toDart).toDart;
    if (result != 'ok') return false;

    if (!_factoryRegistered) {
      ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) => _videoEl());
      _factoryRegistered = true;
    }
    _started = true;
    _mirror = _mirrorJs().toDart;
    _poll = Timer.periodic(const Duration(milliseconds: 33), (_) => _tick());
    return true;
  }

  @override
  Future<List<CameraOption>> listCameras() async {
    if (!_started) return const [];
    try {
      final json = (await _listCamerasJs().toDart).toDart;
      final decoded = jsonDecode(json) as List;
      return [
        for (final e in decoded) CameraOption.fromJson((e as Map).cast<String, dynamic>()),
      ];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<bool> switchCamera(String deviceId) async {
    if (!_started) return false;
    final result = (await _switchCameraJs(deviceId.toJS).toDart).toDart;
    if (result != 'ok') return false;
    _aspect = _aspectJs().toDartDouble;
    _mirror = _mirrorJs().toDart;
    return true;
  }

  void _tick() {
    try {
      _aspect = _aspectJs().toDartDouble;
      final decoded = jsonDecode(_boxesJson().toDart) as List;
      _boxes.value = [
        for (final e in decoded) FaceBox.fromJson((e as Map).cast<String, dynamic>()),
      ];
    } catch (_) {
      // 一時的なパース失敗は無視
    }
  }

  @override
  Widget preview() =>
      _started ? const HtmlElementView(viewType: _viewType) : const SizedBox.shrink();

  @override
  Future<Uint8List?> capture() async {
    final dataUrl = _captureJs().toDart;
    final comma = dataUrl.indexOf(',');
    if (comma < 0) return null;
    return base64Decode(dataUrl.substring(comma + 1));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _boxes.dispose();
  }
}
