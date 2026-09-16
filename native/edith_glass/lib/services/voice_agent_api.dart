import 'dart:convert';

import 'package:http/http.dart' as http;

/// Agent がクライアントに要求するデバイス操作（capture_face 等, PRD §20）。
class AgentAction {
  AgentAction({required this.id, required this.type, required this.payload});
  final String id;
  final String type;
  final Map<String, dynamic> payload;

  factory AgentAction.fromJson(Map<String, dynamic> j) => AgentAction(
        id: j['id'] as String,
        type: j['type'] as String,
        payload: (j['payload'] as Map?)?.cast<String, dynamic>() ?? {},
      );
}

class AgentReply {
  AgentReply({required this.sessionId, required this.message, required this.actions, this.transcript});
  final String sessionId;
  final String message;
  final List<AgentAction> actions;
  final String? transcript;
}

/// Voice Agent (`/v1/agent/*`) クライアント。
class VoiceAgentApi {
  VoiceAgentApi(this.baseUrl, {http.Client? client}) : _client = client ?? http.Client();
  final String baseUrl;
  final http.Client _client;
  String? sessionId;

  /// テキスト指示を送る（PRD §8.1）。
  Future<AgentReply> sendText(String content) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/v1/agent/input'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'sessionId': sessionId, 'type': 'text', 'content': content}),
    );
    if (res.statusCode >= 400) {
      throw Exception('agent input failed: ${res.statusCode} ${res.body}');
    }
    return _parse(utf8.decode(res.bodyBytes));
  }

  /// 音声を送る（PRD §8/§12, Push-to-Talk）。STT はサーバ側でローカル実行。
  Future<AgentReply> sendAudio(List<int> bytes, {String filename = 'speech.webm'}) async {
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/v1/agent/audio'))
      ..fields['language'] = 'ja'
      ..files.add(http.MultipartFile.fromBytes('audio', bytes, filename: filename));
    if (sessionId != null) req.fields['sessionId'] = sessionId!;
    final res = await http.Response.fromStream(await _client.send(req));
    if (res.statusCode >= 400) {
      throw Exception('agent audio failed: ${res.statusCode} ${res.body}');
    }
    return _parse(utf8.decode(res.bodyBytes));
  }

  /// クライアントが実行した Action の結果を返す（PRD §8）。
  Future<void> reportActionResult(String requestId, Map<String, dynamic> result) async {
    await _client.post(
      Uri.parse('$baseUrl/v1/agent/actions/$requestId/result'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(result),
    );
  }

  AgentReply _parse(String body) {
    final j = jsonDecode(body) as Map<String, dynamic>;
    sessionId = (j['sessionId'] as String?) ?? sessionId;
    final actions = (j['actions'] as List? ?? [])
        .map((a) => AgentAction.fromJson((a as Map).cast<String, dynamic>()))
        .toList();
    return AgentReply(
      sessionId: sessionId ?? '',
      message: (j['message'] as String?) ?? '',
      actions: actions,
      transcript: j['transcript'] as String?,
    );
  }
}
