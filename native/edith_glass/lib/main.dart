import 'package:flutter/material.dart';

import 'app/home_page.dart';
import 'glass/glass_transport.dart';

void main() {
  // 実機到着前は PreviewGlassTransport（Flutter描画）。
  // Halo 到着後は HaloGlassTransport(sendLua: device.sendString...) に差し替えるだけ。
  final transport = PreviewGlassTransport();
  runApp(EdithGlassApp(transport: transport));
}

class EdithGlassApp extends StatelessWidget {
  const EdithGlassApp({super.key, required this.transport});

  final GlassTransport transport;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'E.D.I.T.H Glass',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0F12),
        colorScheme: const ColorScheme.dark(primary: Color(0xFF00E5FF)),
      ),
      home: HomePage(transport: transport),
    );
  }
}
