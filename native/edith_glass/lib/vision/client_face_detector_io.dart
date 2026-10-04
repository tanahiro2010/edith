import 'client_face_detector.dart';

/// モバイル/デスクトップ向け。現状は ML Kit 未実装のため null を返し、
/// 呼び出し側はサーバ検出（/v1/vision/detect）にフォールバックする。
/// 今後ここに `google_mlkit_face_detection` + camera image stream で実装予定。
ClientFaceDetector? createClientFaceDetector() => null;
