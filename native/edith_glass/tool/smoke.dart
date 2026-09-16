// 稼働中のバックエンド(Face API :8000 / Voice Agent :8010)に対して、
// Native の API クライアントが実際に通信できることを確認するスモークテスト。
//   dart run tool/smoke.dart
// ※ 3サービス（+DB）が起動している前提。
import 'dart:io';

import 'package:edith_glass/services/face_api.dart';
import 'package:edith_glass/services/voice_agent_api.dart';

Future<void> main() async {
  final face = FaceApi('http://localhost:8000');
  final agent = VoiceAgentApi('http://localhost:8010');

  final bytes = await File('assets/sample_face.jpg').readAsBytes();

  stdout.writeln('== Face API identify ==');
  final id = await face.identify(bytes);
  stdout.writeln(id == null ? '  一致なし' : '  ${id.name} (${(id.similarity * 100).toStringAsFixed(0)}%) info=${id.info}');

  stdout.writeln('== Voice Agent sendText("会話記録開始") ==');
  final r1 = await agent.sendText('会話記録開始');
  stdout.writeln('  message: ${r1.message}');

  stdout.writeln('== Voice Agent sendText("この人を山田さんとして覚えて") ==');
  final r2 = await agent.sendText('この人を山田さんとして覚えて');
  stdout.writeln('  message: ${r2.message}');
  stdout.writeln('  actions: ${r2.actions.map((a) => '${a.type}(${a.payload})').toList()}');

  stdout.writeln('\n✅ smoke passed');
  exit(0);
}
