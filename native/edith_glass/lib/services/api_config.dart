/// バックエンドのベースURL。実機/スマホから使う場合は localhost をホストのIPに変える。
/// Flutter web(Chrome)・macOS デスクトップからはそのまま localhost で届く。
class ApiConfig {
  const ApiConfig({
    this.agentBaseUrl = 'http://localhost:8010',
    this.faceBaseUrl = 'http://localhost:8000',
  });

  /// Voice Agent (TypeScript/Hono)
  final String agentBaseUrl;

  /// Face API (Python/FastAPI)
  final String faceBaseUrl;

  static const ApiConfig defaults = ApiConfig();
}
