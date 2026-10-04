import 'dart:convert';

import 'package:http/http.dart' as http;

import '../hud/face_box.dart';

/// Face API の識別結果。
class IdentifyResult {
  IdentifyResult({required this.name, required this.similarity, this.info, this.sampleAdded = false});
  final String name;
  final double similarity;
  final Map<String, dynamic>? info;

  /// 別角度サンプルが自動学習（auto-enroll）で追加されたか。
  final bool sampleAdded;
}

/// 顔の識別・登録クライアント。ブラウザCORS回避と疎結合のため、Face API を直接ではなく
/// **Voice Agent の vision プロキシ(`/v1/vision/*`)経由**で呼ぶ（baseUrl は Agent の URL）。
/// 顔検出・Embedding 生成は Face API 側の責務。
class FaceApi {
  FaceApi(this.baseUrl, {http.Client? client}) : _client = client ?? http.Client();

  /// Voice Agent のベースURL（例: http://localhost:8010）。
  final String baseUrl;
  final http.Client _client;

  /// 画像から人物を識別する。一致が無ければ null（404）。
  /// [autoEnroll]=true のとき、別角度なら自動でサンプル学習される（Web版と同じ挙動）。
  Future<IdentifyResult?> identify(
    List<int> jpegBytes, {
    String filename = 'frame.jpg',
    bool autoEnroll = true,
    String source = 'edith-glass',
  }) async {
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/v1/vision/identify'))
      ..fields['auto_enroll'] = autoEnroll ? 'true' : 'false'
      ..fields['source'] = source
      ..files.add(http.MultipartFile.fromBytes('image', jpegBytes, filename: filename));
    final res = await http.Response.fromStream(await _client.send(req));
    // 404=一致なし / 422=顔が検出できない → どちらも「未識別(null)」として扱う
    // （連続自動識別で顔が写っていないフレームでも例外にしない）。
    if (res.statusCode == 404 || res.statusCode == 422) return null;
    if (res.statusCode >= 400) {
      throw Exception('identify failed: ${res.statusCode} ${res.body}');
    }
    final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final person = (j['person'] as Map).cast<String, dynamic>();
    return IdentifyResult(
      name: person['name'] as String,
      similarity: (j['similarity'] as num).toDouble(),
      info: (person['info'] as Map?)?.cast<String, dynamic>(),
      sampleAdded: j['sample_added'] == true,
    );
  }

  /// ライブ追跡用の高速な顔検出（枠のみ）。数Hzでポーリングする。
  /// 追跡ループを止めないため、エラー時は空結果を返す（例外を投げない）。
  Future<DetectResult> detect(List<int> jpegBytes, {String filename = 'frame.jpg'}) async {
    try {
      final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/v1/vision/detect'))
        ..files.add(http.MultipartFile.fromBytes('image', jpegBytes, filename: filename));
      final res = await http.Response.fromStream(await _client.send(req));
      if (res.statusCode >= 400) return DetectResult.empty;
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final faces = (j['faces'] as List? ?? [])
          .map((f) => FaceBox.fromJson((f as Map).cast<String, dynamic>()))
          .toList();
      return DetectResult((j['width'] as num).toInt(), (j['height'] as num).toInt(), faces);
    } catch (_) {
      return DetectResult.empty;
    }
  }

  /// 画像と名前で人物を登録する（register_person の実処理）。
  Future<String> register(List<int> jpegBytes, String name, {String filename = 'frame.jpg'}) async {
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/v1/vision/register'))
      ..fields['name'] = name
      ..files.add(http.MultipartFile.fromBytes('image', jpegBytes, filename: filename));
    final res = await http.Response.fromStream(await _client.send(req));
    if (res.statusCode >= 400) {
      throw Exception('register failed: ${res.statusCode} ${res.body}');
    }
    final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return j['id'] as String;
  }
}
