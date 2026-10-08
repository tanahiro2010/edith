import 'package:flutter/material.dart';

import 'app/home_page.dart';
import 'app/settings_sheet.dart';
import 'glass/glass_transport.dart';
import 'services/api_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // HUD 描画先。iOS ドッグフーディングでは PreviewGlassTransport（Flutter描画）を
  // そのままフルスクリーンARに使う。Halo 到着後は HaloGlassTransport に差し替えるだけ。
  final transport = PreviewGlassTransport();

  // 保存済みのバックエンド接続先（無ければ dart-define/localhost 既定）を読み込む。
  final config = await loadApiConfig();

  runApp(EdithGlassApp(transport: transport, config: config));
}

class EdithGlassApp extends StatelessWidget {
  const EdithGlassApp({super.key, required this.transport, required this.config});

  final GlassTransport transport;
  final ApiConfig config;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'E.D.I.T.H Glass',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0F12),
        colorScheme: const ColorScheme.dark(primary: Color(0xFF00E5FF)),
      ),
      home: HomePage(transport: transport, config: config),
    );
  }
}
