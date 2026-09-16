import 'package:flutter/foundation.dart';

/// グラスHUDに表示する状態。Recognize→Remember→Assist の段階（PRD の HUD 表示レベル）
/// を素朴に表現する。Preview（Flutter描画）と実機（Halo Lua）で共有する単一の状態。
@immutable
class HudState {
  const HudState({
    this.status = 'SCANNING',
    this.name,
    this.subInfo,
    this.locked = false,
  });

  /// 上部に出すシステム状態（例: SCANNING / IDENTIFYING / TARGET LOCKED）。
  final String status;

  /// 認識できた人物名（Level 1: 名前のみ）。null なら未認識。
  final String? name;

  /// 補足情報（例: 所属や「前回：Honoについて話した」）。Level 2 相当。
  final String? subInfo;

  /// 人物をロック（認識確定）したか。レティクルの色・演出が変わる。
  final bool locked;

  HudState copyWith({
    String? status,
    String? name,
    String? subInfo,
    bool? locked,
    bool clearName = false,
    bool clearSub = false,
  }) {
    return HudState(
      status: status ?? this.status,
      name: clearName ? null : (name ?? this.name),
      subInfo: clearSub ? null : (subInfo ?? this.subInfo),
      locked: locked ?? this.locked,
    );
  }

  static const idle = HudState();
}
