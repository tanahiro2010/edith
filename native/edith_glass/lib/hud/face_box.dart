/// 顔の枠。座標は入力画像に対する正規化値 [0,1]（x,y=左上, w,h=幅高）。
/// [name] は識別できた人物名（null なら未識別）。[marker] は未識別の人に付ける
/// 簡易識別子（例: A, B）。ユーザーが「Aの人は〇〇だよ」と Agent に指示するのに使う。
class FaceBox {
  const FaceBox(this.x, this.y, this.w, this.h, this.score, {this.name, this.marker});

  final double x;
  final double y;
  final double w;
  final double h;
  final double score;
  final String? name;
  final String? marker;

  double get cx => x + w / 2;
  double get cy => y + h / 2;

  FaceBox labeled({String? name, String? marker}) =>
      FaceBox(x, y, w, h, score, name: name, marker: marker);

  factory FaceBox.fromJson(Map<String, dynamic> j) => FaceBox(
        (j['x'] as num).toDouble(),
        (j['y'] as num).toDouble(),
        (j['w'] as num).toDouble(),
        (j['h'] as num).toDouble(),
        (j['score'] as num?)?.toDouble() ?? 0,
      );

  /// 追従を滑らかにするための線形補間（ラベルは b を引き継ぐ）。
  static FaceBox lerp(FaceBox a, FaceBox b, double t) => FaceBox(
        a.x + (b.x - a.x) * t,
        a.y + (b.y - a.y) * t,
        a.w + (b.w - a.w) * t,
        a.h + (b.h - a.h) * t,
        b.score,
        name: b.name,
        marker: b.marker,
      );
}

/// /faces/detect（proxy: /v1/vision/detect）のレスポンス。
class DetectResult {
  const DetectResult(this.width, this.height, this.faces);
  final int width;
  final int height;
  final List<FaceBox> faces;

  /// 入力画像のアスペクト比（幅/高）。プレビューと枠のマッピングを一致させるのに使う。
  double get aspect => height == 0 ? 1 : width / height;

  static const empty = DetectResult(0, 0, []);
}
