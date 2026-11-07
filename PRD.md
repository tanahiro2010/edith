# E.D.I.T.H — PRD インデックス

E.D.I.T.H は複数サービスから成るため、PRD もサービスごとに分かれています。目的別に参照してください。

| ドキュメント | スコープ |
| --- | --- |
| [`smart_glasses_social_memory.md`](./smart_glasses_social_memory.md) | **プロダクト全体 PRD**。課題定義 / Goals・Non-Goals / User Stories / HUD表示レベル / Open Questions。当面の目標は Lv.1（顔認識→名前 HUD 表示）。 |
| [`backend/voice_assistant_agent/PRD.md`](./backend/voice_assistant_agent/PRD.md) | **Voice Agent PRD**。Agent API / Tool 定義 / データモデル / 音声処理 / フェーズ計画（Phase 1〜5）。 |
| [`backend/face_api/README.md`](./backend/face_api/README.md) | **Face API** の仕様（顔登録・識別エンドポイント、向き補正・小さい顔検出の設計）。 |
| [`../edith_mobile/README.md`](../edith_mobile/README.md) | **Mobile Client**（最優先）。スマホ背面カメラ＝グラスのカメラとするモバイルWebクライアント。 |
| [`../edith_rokid/README.md`](../edith_rokid/README.md) | **Rokid Client** の設計メモ。CXR SDK / AIUI Studio / Lumen の調査結果と方針。 |

> 対象デバイスは当初 Halo だったが、詐欺商品で実機入手不可能と判明したため
> モバイルWeb優先・Rokidグラス対応へ方針転換した（[`README.md`](./README.md)参照）。
> [`native/edith_glass`](./native/edith_glass)（Flutter, Halo向け）はアーカイブ。

全体像・各サービスの起動方法は [`README.md`](./README.md) を参照。
