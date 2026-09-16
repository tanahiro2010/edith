import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../glass/glass_transport.dart';
import '../hud/glass_view.dart';
import '../hud/hud_state.dart';
import '../services/api_config.dart';
import '../services/face_api.dart';
import '../services/voice_agent_api.dart';

/// E.D.I.T.H グラスクライアントのメイン画面。
/// 左に「グラス越しの映像(GlassView)」、右に操作パネル。実機到着前は GlassView が
/// プレビューになり、到着後は HaloGlassTransport に差し替えるだけで同じ UI が使える。
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.transport, this.config = ApiConfig.defaults});

  final GlassTransport transport;
  final ApiConfig config;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final VoiceAgentApi _agent = VoiceAgentApi(widget.config.agentBaseUrl);
  late final FaceApi _face = FaceApi(widget.config.faceBaseUrl);
  final _input = TextEditingController();
  final List<String> _log = [];

  // グラスカメラのフレーム代替（実機では RxPhoto）。デモ用の同梱顔画像。
  static const _sampleAsset = 'assets/sample_face.jpg';
  ImageProvider? _background;
  bool _busy = false;

  void _addLog(String s) => setState(() => _log.insert(0, s));

  Future<List<int>> _sampleFrame() async =>
      (await rootBundle.load(_sampleAsset)).buffer.asUint8List();

  /// 「カメラで今見ている顔を識別」。グラスのカメラ入力を模擬（同梱画像を Face API へ）。
  Future<void> _identify() async {
    setState(() => _busy = true);
    await widget.transport.render(const HudState(status: 'IDENTIFYING'));
    setState(() => _background = const AssetImage(_sampleAsset));
    try {
      final bytes = await _sampleFrame();
      final r = await _face.identify(bytes);
      if (r == null) {
        await widget.transport.render(const HudState(status: 'NO MATCH'));
        _addLog('識別: 一致なし');
      } else {
        final dept = r.info?['department'] as String?;
        await widget.transport.render(HudState(
          status: 'TARGET LOCKED',
          name: r.name,
          subInfo: dept != null ? '$dept ・ ${(r.similarity * 100).toStringAsFixed(0)}%' : null,
          locked: true,
        ));
        _addLog('識別: ${r.name} (${(r.similarity * 100).toStringAsFixed(0)}%)');
      }
    } catch (e) {
      _addLog('識別エラー: $e');
      await widget.transport.render(const HudState(status: 'ERROR'));
    } finally {
      setState(() => _busy = false);
    }
  }

  /// テキスト指示を Agent に送る。capture_face アクションが来たらカメラ撮影→登録を模擬。
  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    _addLog('🗣 $text');
    setState(() => _busy = true);
    try {
      final reply = await _agent.sendText(text);
      _addLog('🤖 ${reply.message}');
      for (final action in reply.actions) {
        if (action.type == 'capture_face') {
          final name = (action.payload['name'] as String?) ?? '';
          _addLog('📷 capture_face → $name を登録中…');
          setState(() => _background = const AssetImage(_sampleAsset));
          final bytes = await _sampleFrame();
          final personId = await _face.register(bytes, name);
          await _agent.reportActionResult(action.id, {'success': true, 'personId': personId});
          await widget.transport.render(HudState(status: 'REGISTERED', name: name, locked: true));
          _addLog('✅ 登録完了: $name ($personId)');
        }
      }
    } catch (e) {
      _addLog('エラー: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F12),
        foregroundColor: const Color(0xFF00E5FF),
        title: const Text('E.D.I.T.H · Halo Glass Client'),
      ),
      body: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth > 720;
        final glass = Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420, maxHeight: 420),
              child: ValueListenableBuilder<HudState>(
                valueListenable: widget.transport.hud,
                builder: (_, state, __) => GlassView(state: state, background: _background),
              ),
            ),
          ),
        );
        final panel = _buildPanel();
        return wide
            ? Row(children: [Expanded(child: glass), SizedBox(width: 340, child: panel)])
            : ListView(children: [SizedBox(height: 360, child: glass), panel]);
      }),
    );
  }

  Widget _buildPanel() {
    const cyan = Color(0xFF00E5FF);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: _busy ? null : _identify,
            icon: const Icon(Icons.center_focus_strong),
            label: const Text('カメラの顔を識別'),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _input,
                onSubmitted: (_) => _send(),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: '指示（例: 田中さんを覚えて）',
                  hintStyle: TextStyle(color: Colors.white38),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: cyan)),
                ),
              ),
            ),
            IconButton(onPressed: _busy ? null : _send, icon: const Icon(Icons.send, color: cyan)),
          ]),
          const SizedBox(height: 12),
          const Text('LOG', style: TextStyle(color: cyan, fontSize: 12, letterSpacing: 2)),
          const Divider(color: Colors.white12),
          Expanded(
            child: ListView.builder(
              itemCount: _log.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(_log[i], style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
