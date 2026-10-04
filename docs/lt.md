---
marp: true
size: 16:9
paginate: true
theme: default
math: false
style: |
  @import url('https://fonts.googleapis.com/css2?family=Roboto:wght@300;400;500;700&family=Noto+Sans+JP:wght@400;500;700&display=swap');
  :root {
    --blue:#4285F4; --red:#EA4335; --yellow:#FBBC04; --green:#34A853;
    --ink:#202124; --sub:#5f6368; --line:#dadce0; --bg:#ffffff;
  }
  section {
    /* 上部に Google 4色のライン（背景グラデーションで確実に描画） */
    background:
      linear-gradient(90deg,var(--blue) 0 25%,var(--red) 25% 50%,var(--yellow) 50% 75%,var(--green) 75% 100%) top/100% 8px no-repeat,
      var(--bg);
    color: var(--ink);
    font-family: 'Roboto','Noto Sans JP',sans-serif;
    font-size: 25px;
    line-height: 1.6;
    padding: 60px 72px 72px;
  }
  h1 { font-size: 50px; font-weight:500; letter-spacing:-.5px; margin:0 0 .25em; }
  h2 {
    font-size: 34px; font-weight:500; margin:0 0 .6em; padding:0 0 .25em;
    border:0; border-left:6px solid var(--blue); padding-left:.4em;
  }
  h3 { font-size: 24px; font-weight:500; color:var(--sub); margin:.2em 0 .4em; }
  strong { color: var(--blue); font-weight:700; }
  a { color: var(--blue); text-decoration:none; }
  ul,ol { margin:.2em 0; }
  li { margin:.28em 0; }
  code { background:#f1f3f4; color:#c5221f; padding:.05em .35em; border-radius:5px; font-size:.85em; }
  table { border-collapse:collapse; font-size:.8em; }
  th { background:#f8f9fa; color:var(--sub); font-weight:500; text-align:left; }
  th,td { border:1px solid var(--line); padding:.4em .7em; }
  section::after { color:var(--sub); font-size:.6em; }
  /* 部品 */
  .sub { color:var(--sub); }
  .chips span{ display:inline-block; border:1px solid var(--line); border-radius:999px; padding:.15em .8em; margin:.15em .2em; font-size:.8em; color:var(--sub); }
  .cards{ display:grid; grid-template-columns:repeat(2,1fr); gap:16px; margin-top:.3em; }
  .card{ border:1px solid var(--line); border-radius:14px; padding:16px 18px; box-shadow:0 1px 3px rgba(60,64,67,.15); }
  .card b{ font-size:1.02em; }
  .card small{ color:var(--sub); }
  .flow{ display:flex; align-items:center; flex-wrap:wrap; gap:.4em; font-size:.78em; }
  .flow .step{ border:1px solid var(--line); border-radius:10px; padding:.4em .7em; background:#f8f9fa; }
  .flow .ar{ color:var(--blue); font-weight:700; }
  .ok{ color:var(--green); font-weight:700; }
  .red{ color:var(--red); font-weight:700; }

  .muted{ color:var(--sub); }
  /* タイトル */
  section.lead{ display:flex; flex-direction:column; justify-content:center; }
  section.lead h1{ font-size:76px; }
  section.lead .tag{ font-size:30px; color:var(--sub); font-weight:400; }
  .g-b{color:var(--blue)} .g-r{color:var(--red)} .g-y{color:var(--yellow)} .g-g{color:var(--green)}
  /* セクション見出し */
  section.divider{ display:flex; flex-direction:column; justify-content:center; }
  section.divider h1{ font-size:60px; }
  span.gray { color:gray }
---

<!-- _class: lead -->
<!-- _paginate: false -->

# ARグラスによる
# コミュニケーション補助システム

## <span class="g-b">E</span>.<span class="g-r">D</span>.<span class="g-y">I</span>.<span class="g-g">T</span>.<span class="g-b">H</span> (自称)

### <span class="gray">マーベル丸パクリタイトル</span>

### <span class="tag"></span>


<br>

<span class="sub">Lightning Talk ・ 5 min / Alpha+ Project</span>

---

## 課題：人の顔は覚えていても…（覚えていなかったとしても）

- **顔は覚えている** のに、**名前・所属が出てこない**
- **前回何を話したか** 思い出せない（続きから話せない）
- 名刺やメモは **結局続かない**
  - そもそも僕の悩みの種たる学校じゃ名刺交換なんてできない
  - ある程度顔を合わせた人の前でメモとるのはなんか申し訳ない

<br>

### → 対面コミュニケーションそのものが心理的負荷に
### → ちなみに私はクラスメートの名前を片手で数えられるほども覚えていない(本当にきまずい)

<br>

<span class="sub">カンファレンス・コミュニティ・学校…「一度会った人」が多い場ほど頻発</span>

---

<!-- _class: divider -->

# E.D.I.T.H とは

<span class="sub">
(あくまでこじつけだけど) Enhanced Data · Identity · Timeline Helper — 記憶を AI が拡張する <br>
<br>

<span class="red">※注意</span>
元ネタはマーベルのアイアンマンが作ったスマートグラスこと〝Even Dead, I'm The Hero〟
流石にこの名前でPRD出すのは危ないから勝手に僕が呼んでます
</span>


---

## コンセプト：Recognize → Remember → Assist

<div class="cards">
<div class="card"><b>Recognize</b><br><small>目の前の人が誰か分かる<br>（顔認識 → 名前を HUD 表示）</small></div>
<div class="card"><b>Remember</b><br><small>前回何を話したか思い出す<br>（会話ログ → 要約・記憶）</small></div>
<div class="card"><b>Assist</b><br><small>いまの会話を助ける<br>（自然言語で問い合わせ）</small></div>
<div class="card"><b>薄い端末</b><br><small>グラスは表示/センサに徹し<br>知能はバックエンドに</small></div>
</div>

<br>

**当面の目標 = Lv.1：顔認識 → 名前を視界に出す**


---

## アーキテクチャ：4つの疎結合サービス

<div class="cards">
<div class="card"><b>Native Client</b> <small>Flutter / Halo</small><br><small>HUD描画・カメラ・音声</small></div>
<div class="card"><b>Voice Agent</b> <small>TypeScript / Hono</small><br><small>指示理解・Tool Calling・記憶</small></div>
<div class="card"><b>STT Service</b> <small>faster-whisper</small><br><small>文字起こし（ローカル）</small></div>
<div class="card"><b>Face API</b> <small>FastAPI / insightface</small><br><small>顔の登録・識別（pgvector）</small></div>
</div>

<br>

<div class="flow">
<span class="step">Client</span><span class="ar">→</span>
<span class="step">STT</span><span class="ar">＋</span>
<span class="step">Voice Agent</span><span class="ar">→</span>
<span class="step">LLM (deniai / gpt-5.2)</span>
<span class="ar">＋</span><span class="step">Face API</span>
</div>

<span class="sub">すべて HTTP/JSON。クライアントを Mac→スマホ→Halo と替えても中身は不変。</span>

---

## 処理フロー：例）「この人を田中さんとして覚えて」

<div class="flow">
<span class="step">音声</span><span class="ar">→</span>
<span class="step">STT(ローカル)</span><span class="ar">→</span>
<span class="step">LLM が意図理解</span><span class="ar">→</span>
<span class="step">register_person</span><span class="ar">→</span>
<span class="step">capture_face をClientへ</span>
</div>
<div class="flow">
<span class="ar">→</span><span class="step">端末カメラで撮影</span><span class="ar">→</span>
<span class="step">Face API に登録</span><span class="ar">→</span>
<span class="step">HUD「登録しました」</span>
</div>

<br>

- 「記録開始/終了」等の明確な指示は **LLMを介さず即実行**（低レイテンシ・低コスト）
- それ以外は **LLM の Tool Calling ループ** へ

---

## 技術スタック

| レイヤ | 採用技術 |
| --- | --- |
| Client | **Flutter**（Halo: brilliant_sdk / Lua で HUD 描画） |
| Agent | **TypeScript + Hono + Drizzle + PostgreSQL** |
| LLM |  `openai/gpt-5.2` （Tool Calling） |
| STT | **faster-whisper**（CPU・ローカル・日本語） |
| Face | **FastAPI + insightface(buffalo_l) + pgvector** |

<span class="chips"><span>疎結合</span><span>Provider抽象(LLM/STT/Camera/HUD)</span><span>Docker/Podman</span></span>

---

## 現状：どこまで動く？

- <span class="ok">済</span> **Face API** … 顔の登録・識別（検出の不具合も修正済）
- <span class="ok">済</span> **Voice Agent** … テキスト＋**音声入力**、Tool Calling、会話ログ・要約・検索
- <span class="red">不明</span> **STT** … ローカル日本語文字起こし
- <span class="ok">済</span> **Native** … **SFレティクルHUD**・実カメラ・バックエンド連携

<br>
SSTに関しては作ったけどまだデバッグしてないので不明

<br>

### まだhaloが届いていないので、Macにて <span class="ok">エンドツーエンド動作を確認済み</span>


---

## 今後（ロードマップ）

- HUD 表示レベル **Lv.2 / Lv.3**（前回の話題・会話のきっかけ）
- **VAD + 話者分離** による会話ログ自動化
- **TTS**（音声応答）・WebSocket リアルタイム化
- **Halo 実機統合**（BLE / RxPhoto / RxAudio）

---

<!-- _class: lead -->
<!-- _paginate: false -->

# ありがとうございました

### <span class="tag">記憶は、AI が拡張できる。</span>

<span class="sub"><span class="g-b">E</span><span class="g-r">.</span><span class="g-y">D</span><span class="g-g">.</span><span class="g-b">I</span>.<span class="g-r">T</span>.<span class="g-y">H</span> — Recognize → Remember → Assist</span>
