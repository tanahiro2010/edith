/// バックエンドのベースURL。実機/スマホから使う場合は localhost をホストのIPに変える。
/// 既定値は `--dart-define` で上書きでき、実行時はアプリ内設定で差し替えられる
/// （[loadApiConfig]/[saveApiConfig] を参照）。
class ApiConfig {
  const ApiConfig({
    this.agentBaseUrl = _defaultAgent,
    this.faceBaseUrl = _defaultFace,
  });

  /// ビルド時の既定。例: `flutter run --dart-define=EDITH_AGENT_URL=http://192.168.0.5:8010`
  static const String _defaultAgent =
      String.fromEnvironment('EDITH_AGENT_URL', defaultValue: 'http://localhost:8010');
  static const String _defaultFace =
      String.fromEnvironment('EDITH_FACE_URL', defaultValue: 'https://face.unischool.jp');

  /// Voice Agent (TypeScript/Hono)
  final String agentBaseUrl;

  /// Face API (Python/FastAPI)
  final String faceBaseUrl;

  static const ApiConfig defaults = ApiConfig();

  ApiConfig copyWith({String? agentBaseUrl, String? faceBaseUrl}) => ApiConfig(
        agentBaseUrl: agentBaseUrl ?? this.agentBaseUrl,
        faceBaseUrl: faceBaseUrl ?? this.faceBaseUrl,
      );
}
