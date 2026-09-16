import 'dart:convert';

import 'package:http/http.dart' as http;

/// Face API の識別結果。
class IdentifyResult {
  IdentifyResult({required this.name, required this.similarity, this.info});
  final String name;
  final double similarity;
  final Map<String, dynamic>? info;
}

/// Face API (`/faces/*`) クライアント。グラスカメラのフレームを送って人物を識別・登録する。
/// 顔検出・Embedding 生成は Face API 側の責務。
class FaceApi {
  FaceApi(this.baseUrl, {http.Client? client}) : _client = client ?? http.Client();
  final String baseUrl;
  final http.Client _client;

  /// 画像から人物を識別する。一致が無ければ null（404）。
  Future<IdentifyResult?> identify(List<int> jpegBytes, {String filename = 'frame.jpg'}) async {
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/faces/identify'))
      ..files.add(http.MultipartFile.fromBytes('image', jpegBytes, filename: filename));
    final res = await http.Response.fromStream(await _client.send(req));
    if (res.statusCode == 404) return null;
    if (res.statusCode >= 400) {
      throw Exception('identify failed: ${res.statusCode} ${res.body}');
    }
    final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final person = (j['person'] as Map).cast<String, dynamic>();
    return IdentifyResult(
      name: person['name'] as String,
      similarity: (j['similarity'] as num).toDouble(),
      info: (person['info'] as Map?)?.cast<String, dynamic>(),
    );
  }

  /// 画像と名前で人物を登録する（register_person の実処理）。
  Future<String> register(List<int> jpegBytes, String name, {String filename = 'frame.jpg'}) async {
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/faces/register'))
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
