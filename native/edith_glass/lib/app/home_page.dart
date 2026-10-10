import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../camera/frame_source.dart';
import '../glass/glass_transport.dart';
import '../hud/ar_view.dart';
import '../hud/face_box.dart';
import '../hud/hud_state.dart';
import '../services/api_config.dart';
import '../services/face_api.dart';
import '../services/voice_agent_api.dart';
import '../vision/client_face_detector.dart';
import 'settings_sheet.dart';

/// 追跡中の1つの顔（トラック）。同一トラックである限り人物を固定（sticky）し、
/// 見失うまで「不明」に落とさない。複数の顔はそれぞれ別トラック＝別人として扱う。
class _Track {
  _Track(this.id, FaceBox box)
      : box = box,
        shown = box,
        lastSeen = DateTime.now();
  final int id;
  FaceBox box; // 最新の検出（生ターゲット）
  FaceBox shown; // 補間後の表示
  String? name; // 確定した人物名（sticky）
  String? marker; // 未識別の人に付ける簡易識別子（A, B, ...）
  DateTime lastSeen;
  DateTime? lastId; // 最後に識別を試みた時刻
  bool identifying = false;
}

/// E.D.I.T.H グラスクライアントのメイン画面。
/// ライブカメラ時は、検出した各顔を個別に追従・識別する（多人数対応）。
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.transport, this.config = ApiConfig.defaults});

  final GlassTransport transport;
  final ApiConfig config;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late ApiConfig _config = widget.config;
  // Face API は `/faces/*` を直接叩くため faceBaseUrl を使う（例: https://face.unischool.jp）。
  late VoiceAgentApi _agent = VoiceAgentApi(_config.agentBaseUrl);
  late FaceApi _face = FaceApi(_config.faceBaseUrl);
  final _input = TextEditingController();
  final List<String> _log = [];

  // オンデバイス音声認識（iOS ネイティブ STT）。結果テキストを既存 _send に流す。
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvail = false;
  bool _listening = false;

  static const _sampleAsset = 'assets/sample_face.jpg';
  static const _tickInterval = Duration(milliseconds: 700); // サーバ検出モードのポーリング
  static const _lostGraceMs = 1200; // これ以上見失ったらトラック終了
  static const _relearnMs = 4000; // 確定済みトラックの再識別/学習の間隔
  static const _matchDist = 0.2; // トラック対応付けの中心距離しきい値（正規化）

  FrameSource? _frame;
  ImageProvider? _background;
  bool _busy = false;
  bool _auto = true;
  bool _autoLearn = true; // 角度が変わったら自動学習
  bool _mirror = true;
  double _previewAspect = 1;
  bool _capturing = false;
  bool _identifying = false;
  int _tick = 0;

  // クライアント側検出（web=MediaPipe）。使えれば往復なしで滑らかに追従。
  ClientFaceDetector? _client;
  bool get _clientMode => _client != null;

  // PC(Web)のカメラ選択（内蔵/外部USB/フロント・バック）。
  List<CameraOption> _cameras = const [];
  String? _selectedCamera;

  // 顔トラック（多人数）と、描画用の枠（名前付き）
  final List<_Track> _tracks = [];
  int _nextId = 1;
  final ValueNotifier<List<FaceBox>> _tracksVN = ValueNotifier<List<FaceBox>>(const []);
  Ticker? _ticker;

  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _initVision();
    _initSpeech();
  }

  /// 端末の音声認識を初期化。使えない環境（シミュレータ等）では静かに無効化する。
  Future<void> _initSpeech() async {
    try {
      final ok = await _speech.initialize(
        onStatus: (s) {
          if (!mounted) return;
          if (s == 'done' || s == 'notListening') setState(() => _listening = false);
        },
        onError: (_) {
          if (mounted) setState(() => _listening = false);
        },
      );
      if (mounted) setState(() => _speechAvail = ok);
    } catch (_) {
      if (mounted) setState(() => _speechAvail = false);
    }
  }

  /// マイクのオン/オフ。最終結果が出たら入力欄へ入れて既存の送信パイプラインに流す。
  Future<void> _toggleMic() async {
    if (!_speechAvail) {
      _addLog('⚠️ 音声認識が使えません（権限/対応状況を確認）');
      return;
    }
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    setState(() => _listening = true);
    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(localeId: 'ja_JP', partialResults: false),
      onResult: (r) {
        if (r.finalResult && r.recognizedWords.trim().isNotEmpty) {
          _input.text = r.recognizedWords.trim();
          _send();
        }
      },
    );
  }

  /// 接続先設定シートを開き、保存されたら API クライアントを作り直す。
  Future<void> _openSettings() async {
    final next = await showSettingsSheet(context, _config);
    if (next == null || !mounted) return;
    setState(() {
      _config = next;
      _agent = VoiceAgentApi(_config.agentBaseUrl);
      _face = FaceApi(_config.faceBaseUrl);
    });
    _addLog('🔧 接続先を更新: agent=${_config.agentBaseUrl} face=${_config.faceBaseUrl}');
  }

  Future<void> _initVision() async {
    final client = createClientFaceDetector();
    if (client != null && await client.start()) {
      if (!mounted) {
        client.dispose();
        return;
      }
      client.boxes.addListener(_onClientBoxes);
      setState(() {
        _client = client;
        _previewAspect = client.aspect;
        _mirror = client.mirror;
      });
      _addLog('🎯 端末内検出(MediaPipe)で追従（往復なし）');
      _startAuto();
      _loadCameras();
      return;
    }
    await _initCamera();
  }

  /// 利用可能なカメラ一覧を取得してドロップダウンに反映する（Web）。
  Future<void> _loadCameras() async {
    final client = _client;
    if (client == null) return;
    final cams = await client.listCameras();
    if (!mounted) return;
    setState(() => _cameras = cams);
  }

  /// 選択したカメラ（外部USB/フロント/バック）に切替えて追跡を再開する。
  Future<void> _switchCamera(String deviceId) async {
    final client = _client;
    if (client == null || deviceId == _selectedCamera) return;
    _stopAuto(); // トラッククリア込み
    final ok = await client.switchCamera(deviceId);
    if (!mounted) return;
    if (!ok) {
      _addLog('⚠️ カメラの切替に失敗しました');
    } else {
      setState(() {
        _selectedCamera = deviceId;
        _previewAspect = client.aspect;
        _mirror = client.mirror;
      });
      _addLog('📷 カメラを切替えました');
      // ラベルは許可直後に埋まることがあるので再取得。
      _loadCameras();
    }
    if (_auto) _startAuto();
  }

  Future<void> _initCamera() async {
    final fs = await createFrameSource(fallbackAsset: _sampleAsset);
    if (!mounted) return;
    setState(() {
      _frame = fs;
      _previewAspect = fs.aspectRatio;
      _mirror = fs.isFront;
    });
    if (fs.isLive) {
      _addLog('📷 カメラ起動（自動追跡・識別 ON）');
      _startAuto();
    } else {
      _addLog('🖼 カメラ非対応→サンプル画像（手動識別のみ）');
    }
  }

  void _startAuto() {
    _autoTimer?.cancel();
    if (_clientMode) {
      // 枠はクライアント検出がリアルタイム更新。名前だけ定期的にサーバへ。
      _autoTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) => _clientIdentifyTick());
    } else {
      _autoTimer = Timer.periodic(_tickInterval, (_) => _autoTick());
    }
  }

  void _stopAuto() {
    _autoTimer?.cancel();
    _autoTimer = null;
    _tracks.clear();
    _tracksVN.value = const [];
  }

  void _onClientBoxes() {
    if (!mounted) return;
    if (_client!.aspect > 0 && (_client!.aspect - _previewAspect).abs() > 0.01) {
      setState(() => _previewAspect = _client!.aspect);
    }
    _ingestBoxes(_client!.boxes.value);
  }

  /// 検出した生の枠を既存トラックへ対応付け（最近傍）、新規/消失を反映する。
  void _ingestBoxes(List<FaceBox> raw) {
    final now = DateTime.now();
    final usedRaw = <int>{};
    for (final t in _tracks) {
      int best = -1;
      double bestD = _matchDist;
      for (var i = 0; i < raw.length; i++) {
        if (usedRaw.contains(i)) continue;
        final d = (t.box.cx - raw[i].cx).abs() + (t.box.cy - raw[i].cy).abs();
        if (d < bestD) {
          bestD = d;
          best = i;
        }
      }
      if (best >= 0) {
        t.box = raw[best];
        t.lastSeen = now;
        usedRaw.add(best);
      }
    }
    for (var i = 0; i < raw.length; i++) {
      if (!usedRaw.contains(i)) {
        _tracks.add(_Track(_nextId++, raw[i])..marker = _assignMarker());
      }
    }
    _tracks.removeWhere((t) => now.difference(t.lastSeen).inMilliseconds > _lostGraceMs);
  }

  /// 現在使われていない最小の英字を識別子として割り当てる（A, B, ...）。
  String _assignMarker() {
    final used = _tracks.map((t) => t.marker).whereType<String>().toSet();
    for (var i = 0; i < 26; i++) {
      final c = String.fromCharCode(65 + i);
      if (!used.contains(c)) return c;
    }
    return '#$_nextId';
  }

  /// 毎フレーム：各トラックの表示枠を補間し、HUD の要約状態を更新する。
  void _onTick(Duration _) {
    if (_tracks.isEmpty) {
      if (_tracksVN.value.isNotEmpty) _tracksVN.value = const [];
      _syncHud();
      return;
    }
    final out = <FaceBox>[];
    for (final t in _tracks) {
      t.shown = FaceBox.lerp(t.shown, t.box, 0.3);
      // 識別済みは名前、未識別は識別子(A,B..)を表示
      out.add(t.shown.labeled(name: t.name, marker: t.name == null ? t.marker : null));
    }
    _tracksVN.value = out;
    _syncHud();
  }

  /// 名前は枠ごとに表示するので、HUD中央はステータス要約のみ（等価比較で無駄描画は起きない）。
  void _syncHud() {
    final total = _tracks.length;
    final named = _tracks.where((t) => t.name != null).length;
    HudState s;
    if (total == 0) {
      s = const HudState(status: 'SCANNING');
    } else if (named == 0) {
      s = const HudState(status: 'DETECTED');
    } else if (total == 1) {
      s = const HudState(status: 'TARGET LOCKED', locked: true);
    } else {
      s = HudState(status: '$named / $total 人 認識', locked: true);
    }
    widget.transport.render(s);
  }

  // --- 識別（顔ごと） ---

  Future<void> _autoTick() async {
    if (!_auto || !mounted || _busy || _capturing) return;
    if (_frame?.isLive != true) return;
    _capturing = true;
    try {
      final bytes = await _captureFrame();
      final det = await _face.detect(bytes);
      if (!mounted) return;
      if (det.aspect > 0) _previewAspect = det.aspect;
      _ingestBoxes(det.faces);
      _tick++;
      if (_tick % 3 == 0) await _identifyPass(bytes);
    } catch (_) {
      // 追跡ループは止めない
    } finally {
      _capturing = false;
    }
  }

  Future<void> _clientIdentifyTick() async {
    if (!_auto || !mounted) return;
    final bytes = await _client?.capture();
    if (bytes != null) await _identifyPass(bytes);
  }

  /// 1枚のフレームから、名前が必要な各トラックの顔を切り出して個別に識別する。
  Future<void> _identifyPass(Uint8List fullBytes) async {
    if (_identifying || _tracks.isEmpty) return;
    _identifying = true;
    try {
      final decoded = img.decodeImage(fullBytes);
      if (decoded == null) return;
      final now = DateTime.now();
      for (final t in List<_Track>.of(_tracks)) {
        if (t.identifying) continue;
        // 確定済みは再学習間隔まで待つ。未確定は毎回試す。
        if (t.name != null &&
            t.lastId != null &&
            now.difference(t.lastId!).inMilliseconds < _relearnMs) {
          continue;
        }
        final crop = _cropFace(decoded, t.box);
        if (crop == null) continue;
        t.identifying = true;
        t.lastId = now;
        try {
          final jpg = Uint8List.fromList(img.encodeJpg(crop, quality: 85));
          final r = await _face.identify(jpg, autoEnroll: _autoLearn);
          if (!mounted) return;
          if (r == null) {
            // 未一致。トラック中で人物確定済みなら「苦手な角度」として学習（他人にしない）。
            if (t.name != null && _autoLearn) {
              try {
                await _face.register(jpg, t.name!);
                _addLog('📚 苦手な角度を学習: ${t.name}');
              } catch (_) {}
            }
          } else {
            if (r.sampleAdded) _addLog('📚 角度サンプルを自動学習: ${r.name}');
            // 名前はトラック開始時のみ確定。以降は sticky（切替えない）。
            if (t.name == null) {
              t.name = r.name;
              _addLog('識別: ${r.name} (${(r.similarity * 100).toStringAsFixed(0)}%)');
            }
          }
        } finally {
          t.identifying = false;
        }
      }
    } finally {
      _identifying = false;
    }
  }

  /// トラックの枠（正規化）から、余白付きで顔領域を切り出す。座標は生フレーム基準。
  img.Image? _cropFace(img.Image src, FaceBox b, {double margin = 0.4}) {
    // insightface は MediaPipe より検出が厳しく、タイトな切り出しだと落ちやすい。
    // 頭部が入るよう余白を広めにとる。
    final w = src.width, h = src.height;
    final mx = b.w * w * margin, my = b.h * h * margin;
    final int x = ((b.x * w) - mx).round().clamp(0, w - 1).toInt();
    final int y = ((b.y * h) - my).round().clamp(0, h - 1).toInt();
    int cw = ((b.w * w) + mx * 2).round();
    int ch = ((b.h * h) + my * 2).round();
    if (x + cw > w) cw = w - x;
    if (y + ch > h) ch = h - y;
    if (cw < 8 || ch < 8) return null;
    return img.copyCrop(src, x: x, y: y, width: cw, height: ch);
  }

  Future<Uint8List> _captureFrame() async {
    final fs = _frame;
    if (fs != null) return fs.capture();
    return (await rootBundle.load(_sampleAsset)).buffer.asUint8List();
  }

  Future<Uint8List?> _captureBytes() async {
    if (_clientMode) return _client!.capture();
    return _captureFrame();
  }

  /// 手動の「今すぐ識別」。
  Future<void> _identify() async {
    setState(() => _busy = true);
    try {
      final bytes = await _captureBytes();
      if (bytes == null) {
        _addLog('フレームを取得できませんでした');
        return;
      }
      if (!_clientMode && _frame?.isLive != true) {
        setState(() => _background = MemoryImage(bytes));
      }
      if (_tracks.isEmpty) {
        // トラックがまだ無ければ全画面を1件識別（起動直後など）
        final r = await _face.identify(bytes, autoEnroll: _autoLearn);
        _addLog(r == null ? '識別: 一致なし' : '識別: ${r.name}');
      } else {
        await _identifyPass(bytes);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// テキスト指示を Agent に送る。capture_face アクションが来たら撮影→登録。
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
          final bytes = await _captureBytes();
          if (bytes == null) {
            _addLog('フレームを取得できませんでした');
            continue;
          }
          final personId = await _face.register(bytes, name);
          await _agent.reportActionResult(action.id, {'success': true, 'personId': personId});
          await widget.transport.render(HudState(status: 'REGISTERED: $name', locked: true));
          _addLog('✅ 登録完了: $name ($personId)');
        } else if (action.type == 'capture_labeled_face') {
          // 「Aの人は〇〇だよ」→ その識別子のトラックの顔を切り出して名前に紐付ける
          final marker = (action.payload['marker'] as String?) ?? '';
          final name = (action.payload['name'] as String?) ?? '';
          try {
            final ok = await _registerLabeled(marker, name);
            await _agent.reportActionResult(action.id, {'success': ok, 'marker': marker, 'name': name});
            _addLog(ok ? '✅ 「$marker」→ $name として登録' : '⚠️ 識別子「$marker」の顔が見つかりません（画面に出ていますか）');
          } catch (e) {
            // Face API 未到達(例: face.unischool.jp=502)や登録失敗の実エラーを表示
            await _agent.reportActionResult(action.id, {'success': false, 'marker': marker});
            _addLog('⚠️ 登録に失敗: $e');
          }
        }
      }
    } catch (e) {
      _addLog('エラー: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 識別子(A,B..)のトラックの顔を切り出し、指定名で登録して以後 identified にする。
  Future<bool> _registerLabeled(String marker, String name) async {
    if (name.isEmpty) return false;
    final m = marker.trim().toUpperCase();
    _Track? track;
    for (final t in _tracks) {
      if ((t.marker ?? '').toUpperCase() == m) {
        track = t;
        break;
      }
    }
    // 識別子が一致しなくても、未識別の顔が1つだけならそれを対象にする（単独ならほぼ確実）。
    if (track == null) {
      final unnamed = _tracks.where((t) => t.name == null).toList();
      if (unnamed.length == 1) {
        track = unnamed.first;
        _addLog('（識別子「$marker」は未検出だが未識別の顔が1つなのでそれを使用）');
      }
    }
    final bytes = await _captureBytes();
    if (bytes == null) throw Exception('フレームを取得できませんでした');

    // 顔が1つだけ / 対象トラック不明なら、切り出さず「全画面」で登録するのが最も確実
    // （insightface は全画面＝コンテキストが多い方が検出しやすい）。
    if (track == null || _tracks.length <= 1) {
      await _face.register(bytes, name); // 全画面の最大顔を登録
      track?.name = name;
      return true;
    }

    // 複数人のときだけ、対象の顔を切り出して登録（他人の混入を避ける）。
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw Exception('画像をデコードできませんでした');
    final crop = _cropFace(decoded, track.box);
    if (crop == null) throw Exception('顔の切り出しに失敗しました');
    try {
      await _face.register(Uint8List.fromList(img.encodeJpg(crop, quality: 90)), name);
    } catch (_) {
      // 切り出しで検出できない場合は全画面で再試行（複数人だと最大顔になる点に注意）
      await _face.register(bytes, name);
    }
    track.name = name;
    return true;
  }

  /// カメラ選択ドロップダウン（Web・外部USB/フロント/バック切替）。
  Widget _buildCameraPicker(Color cyan) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.videocam_outlined, color: Colors.white54, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButton<String>(
              isExpanded: true,
              isDense: true,
              dropdownColor: const Color(0xFF14202A),
              iconEnabledColor: cyan,
              value: _selectedCamera,
              hint: const Text('カメラを選択',
                  style: TextStyle(color: Colors.white38, fontSize: 14)),
              underline: Container(height: 1, color: Colors.white24),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              items: [
                for (var i = 0; i < _cameras.length; i++)
                  DropdownMenuItem<String>(
                    value: _cameras[i].deviceId,
                    child: Text(
                      _cameras[i].label.isNotEmpty ? _cameras[i].label : 'カメラ ${i + 1}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _busy ? null : (v) {
                if (v != null) _switchCamera(v);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _addLog(String s) => setState(() => _log.insert(0, s));

  @override
  void dispose() {
    _speech.cancel();
    _stopAuto();
    _ticker?.dispose();
    _tracksVN.dispose();
    _client?.boxes.removeListener(_onClientBoxes);
    _client?.dispose();
    _frame?.dispose();
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final live = _clientMode
        ? _client!.preview()
        : (_frame?.isLive == true ? _frame!.livePreview() : null);
    return Scaffold(
      backgroundColor: const Color(0xFF06080A),
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // フルスクリーンAR（カメラ映像＋追従枠＋中央レティクル）
          ValueListenableBuilder<HudState>(
            valueListenable: widget.transport.hud,
            builder: (_, state, __) => ArView(
              state: state,
              background: _background,
              liveBackground: live,
              previewAspect: _previewAspect,
              mirror: _mirror,
              faces: _tracksVN,
            ),
          ),
          // 上部バー（ブランド＋設定）
          SafeArea(child: _buildTopBar()),
          // 下部バー（ログ＋入力＋マイク）
          SafeArea(
            child: Align(alignment: Alignment.bottomCenter, child: _buildBottomBar()),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    const cyan = Color(0xFF00E5FF);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          const Text('E.D.I.T.H',
              style: TextStyle(color: cyan, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 3)),
          const Spacer(),
          IconButton(
            tooltip: '設定',
            icon: const Icon(Icons.tune, color: Colors.white70),
            onPressed: _showControls,
          ),
          IconButton(
            tooltip: '接続先',
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            onPressed: _openSettings,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    const cyan = Color(0xFF00E5FF);
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xCC0B0F12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_log.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
              child: Text(
                _log.take(3).join('\n'),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.3),
              ),
            ),
          Row(
            children: [
              IconButton(
                tooltip: '今すぐ識別',
                onPressed: _busy ? null : _identify,
                icon: const Icon(Icons.center_focus_strong, color: cyan),
              ),
              Expanded(
                child: TextField(
                  controller: _input,
                  onSubmitted: (_) => _send(),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: '指示（例: 田中さんを覚えて）',
                    hintStyle: TextStyle(color: Colors.white38),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: cyan)),
                  ),
                ),
              ),
              IconButton(
                tooltip: '音声入力',
                onPressed: _speechAvail && !_busy ? _toggleMic : null,
                icon: Icon(
                  _listening ? Icons.mic : Icons.mic_none,
                  color: _listening ? const Color(0xFF7CFF6B) : (_speechAvail ? cyan : Colors.white24),
                ),
              ),
              IconButton(
                onPressed: _busy ? null : _send,
                icon: const Icon(Icons.send, color: cyan),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 追跡・学習・ミラー等のトグルとカメラ選択・ログをまとめたシート。
  void _showControls() {
    const cyan = Color(0xFF00E5FF);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF14202A),
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          void mutate(VoidCallback fn) {
            setState(fn);
            setSheet(() {});
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_clientMode && _cameras.length > 1) _buildCameraPicker(cyan),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('自動追跡・識別（顔ごとに枠＋名前）',
                        style: TextStyle(color: Colors.white70, fontSize: 14)),
                    value: _auto,
                    activeThumbColor: cyan,
                    onChanged: (v) {
                      mutate(() => _auto = v);
                      if (v && (_clientMode || _frame?.isLive == true)) {
                        _startAuto();
                      } else {
                        _stopAuto();
                      }
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('角度サンプルを自動学習',
                        style: TextStyle(color: Colors.white70, fontSize: 14)),
                    value: _autoLearn,
                    activeThumbColor: cyan,
                    onChanged: (v) => mutate(() => _autoLearn = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('ミラー（枠が顔とズレたら切替）',
                        style: TextStyle(color: Colors.white70, fontSize: 14)),
                    value: _mirror,
                    activeThumbColor: cyan,
                    onChanged: (v) => mutate(() => _mirror = v),
                  ),
                  const SizedBox(height: 8),
                  const Text('LOG', style: TextStyle(color: cyan, fontSize: 12, letterSpacing: 2)),
                  const Divider(color: Colors.white12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _log.length,
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(_log[i], style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
