import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_config.dart';

const _kAgentKey = 'edith_agent_base_url';
const _kFaceKey = 'edith_face_base_url';

/// 保存済みのホストURLがあればそれを、無ければビルド時既定（dart-define/localhost）を返す。
Future<ApiConfig> loadApiConfig() async {
  final prefs = await SharedPreferences.getInstance();
  const base = ApiConfig.defaults;
  return base.copyWith(
    agentBaseUrl: prefs.getString(_kAgentKey),
    faceBaseUrl: prefs.getString(_kFaceKey),
  );
}

/// 接続先を端末に保存する。
Future<void> saveApiConfig(ApiConfig config) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kAgentKey, config.agentBaseUrl);
  await prefs.setString(_kFaceKey, config.faceBaseUrl);
}

/// バックエンド接続先を編集するボトムシート。保存すると新しい [ApiConfig] を返す
/// （キャンセル時は null）。実機から叩く場合はホストのLAN IPを入れる。
Future<ApiConfig?> showSettingsSheet(BuildContext context, ApiConfig current) {
  final agentCtrl = TextEditingController(text: current.agentBaseUrl);
  final faceCtrl = TextEditingController(text: current.faceBaseUrl);
  const cyan = Color(0xFF00E5FF);

  InputDecoration deco(String label, String hint) => InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: const TextStyle(color: Colors.white30),
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: cyan)),
      );

  return showModalBottomSheet<ApiConfig>(
    context: context,
    backgroundColor: const Color(0xFF14202A),
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('バックエンド接続先',
              style: TextStyle(color: cyan, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 4),
          const Text('実機からは localhost は届きません。同一Wi-FiのホストIP（例: http://192.168.0.5:8010）を入力してください。',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 16),
          TextField(
            controller: agentCtrl,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: deco('Voice Agent URL', 'http://192.168.0.5:8010'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: faceCtrl,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: deco('Face API URL (任意)', 'http://192.168.0.5:8000'),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: const Icon(Icons.save_outlined),
            label: const Text('保存して適用'),
            onPressed: () async {
              final next = ApiConfig(
                agentBaseUrl: agentCtrl.text.trim().isEmpty
                    ? current.agentBaseUrl
                    : agentCtrl.text.trim(),
                faceBaseUrl: faceCtrl.text.trim().isEmpty
                    ? current.faceBaseUrl
                    : faceCtrl.text.trim(),
              );
              await saveApiConfig(next);
              if (ctx.mounted) Navigator.of(ctx).pop(next);
            },
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('キャンセル', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    ),
  );
}
